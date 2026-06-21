// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdEngine.kt
package com.example.bingwa_pro
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean
// ─── dryRun parameter ────────────────────────────────────────────────────────
// dryRun = true  → every executeXxxUssd() logs what it would dial but never
//                  opens the dialler. Safe when airtime is zero.
// dryRun = false → real execution (default for production).
//
// MainActivity always passes dryRun = true when the call originates from the
// Flutter test-injection button so engineers can watch the full pipeline in
// Logcat without touching the dialler or needing airtime.
// ─────────────────────────────────────────────────────────────────────────────
class UssdEngine(
    private val context: Context,
    private val dryRun: Boolean = false
) {
    private val TAG = "UssdEngine"
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── W3.B: data-driven offer formatting (Hybrid FormatUssdUseCase parity) ──
    // Scheduled/quick-dial offers store a template using the "BH"/"BN" placeholder for
    // the customer phone and "AMT" for the amount (Safaricom codes are digits/*/#
    // only, so these letter tokens are unambiguous). This mirrors the Dart
    // ussd_template_formatter so device-side dials (scheduled renewals) format the
    // same way the in-app Quick Dial path already does.
    fun normalizeKenyanPhone(raw: String): String {
        val digits = raw.filter { it.isDigit() }
        val last9 = if (digits.length >= 9) digits.takeLast(9) else digits
        return "0$last9"
    }
    fun formatUssdCode(template: String, customerPhone: String, amount: Int? = null): String {
        val phone = normalizeKenyanPhone(customerPhone)
        // Accept BOTH the legacy "BH" and the rebranded "BN" placeholder so existing
        // (BH) templates keep dialing during/after the rebrand migration. Both are
        // digit-free letter tokens and the customer phone is digits-only, so replacing
        // one can never disturb the other.
        var code = template.replace("BH", phone).replace("BN", phone)
        if (amount != null) code = code.replace("AMT", amount.toString())
        if (!code.endsWith("#")) code += "#"
        return code
    }

    // ── EXPRESS execution — W3.B: captures the response via sendUssdRequest ───
    // Kept returning Boolean so existing callers (MainActivity.executeUssd) compile
    // unchanged. Callers that need the response text
    // (UssdExecutionService, AirtimeChecker) call dialExpressCapturing directly.
    suspend fun executeExpressUssd(ussdCode: String, phoneNumber: String): Boolean =
        dialExpressCapturing(ussdCode, phoneNumber).success

    /**
     * W3.B — the real Express dial. Uses TelephonyManager.sendUssdRequest (API 26+),
     * which actually captures Safaricom's response text (D-W3-2). ACTION_CALL is kept
     * ONLY as a labeled fallback for sub-26 devices and OEM/SIM combos where
     * sendUssdRequest throws. The fallback cannot capture a response.
     *
     * MONEY-SAFETY: this fires the USSD session AT MOST ONCE. The ACTION_CALL fallback
     * is only reached when sendUssdRequest did NOT start a session (threw) or on sub-26,
     * so there is never a double-charge.
     */
    suspend fun dialExpressCapturing(
        ussdCode: String,
        phoneNumber: String,
        timeoutMillis: Long = 40_000L
    ): UssdDialResult {
        val finalCode = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
        if (dryRun) {
            Log.d(TAG, "🧪 DRY RUN — would sendUssdRequest: $finalCode for $phoneNumber")
            return UssdDialResult(success = true, response = "DRY_RUN")
        }
        // sendUssdRequest is API 26+. Below that → labeled ACTION_CALL fallback.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            val fired = fireActionCallFallback(finalCode)
            return UssdDialResult(success = fired, response = null)
        }
        val tmDefault = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            ?: return UssdDialResult(fireActionCallFallback(finalCode), null)
        // W3.F: pin to the configured dial SIM when resolvable; else use the default manager
        // (single-SIM or unresolved slot → identical to pre-W3.F behavior, never hard-fails).
        val dialSubId = SimSubscriptionResolver.dialSubId(context)
        val tm = if (dialSubId != null) {
            try {
                tmDefault.createForSubscriptionId(dialSubId)
            } catch (e: Exception) {
                Log.w(TAG, "createForSubscriptionId($dialSubId) failed (${e.message}) — default TM")
                tmDefault
            }
        } else {
            tmDefault
        }
        return try {
            val captured = withTimeoutOrNull(timeoutMillis) {
                suspendCancellableCoroutine<UssdDialResult> { cont ->
                    val resumed = AtomicBoolean(false)
                    val callback = object : TelephonyManager.UssdResponseCallback() {
                        override fun onReceiveUssdResponse(
                            telephonyManager: TelephonyManager,
                            request: String,
                            response: CharSequence
                        ) {
                            if (resumed.compareAndSet(false, true)) {
                                cont.resume(UssdDialResult(true, response.toString()), null)
                            }
                        }
                        override fun onReceiveUssdResponseFailed(
                            telephonyManager: TelephonyManager,
                            request: String,
                            failureCode: Int
                        ) {
                            if (resumed.compareAndSet(false, true)) {
                                cont.resume(UssdDialResult(false, "USSD request failed (code=$failureCode)"), null)
                            }
                        }
                    }
                    try {
                        tm.sendUssdRequest(finalCode, callback, Handler(Looper.getMainLooper()))
                    } catch (e: Exception) {
                        Log.w(TAG, "sendUssdRequest threw (${e.message}) — OEM fallback to ACTION_CALL")
                        val fired = fireActionCallFallback(finalCode)
                        if (resumed.compareAndSet(false, true)) {
                            cont.resume(UssdDialResult(fired, null), null)
                        }
                    }
                }
            }
            captured ?: run {
                Log.w(TAG, "sendUssdRequest timed out after ${timeoutMillis}ms for $finalCode")
                UssdDialResult(false, "Transaction timed out", isTimeout = true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "dialExpressCapturing error: ${e.message}", e)
            UssdDialResult(false, e.message)
        }
    }

    // Labeled OEM/sub-26 fallback. Fire-and-forget; no response capture.
    private fun fireActionCallFallback(finalCode: String): Boolean {
        return try {
            val encodedCode = finalCode.replace("#", Uri.encode("#"))
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$encodedCode")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                // W3.F: pin to the configured dial SIM when resolvable (else platform default).
                SimSubscriptionResolver.dialPhoneAccountHandle(context)?.let {
                    putExtra(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it)
                }
            }
            context.startActivity(intent)
            Log.d(TAG, "EXPRESS fallback (ACTION_CALL) fired: $finalCode")
            true
        } catch (e: Exception) {
            Log.e(TAG, "ACTION_CALL fallback failed: ${e.message}", e)
            false
        }
    }

    // ── ADVANCED execution — W3.C: engine-driven multi-step navigation + capture ──
    // Thin Boolean wrapper kept so existing callers (MainActivity.executeAdvancedUssd)
    // compile unchanged. Callers that need the response text call
    // dialAdvancedCapturing directly (UssdExecutionService).
    suspend fun executeAdvancedUssd(ussdCode: String, phoneNumber: String): Boolean =
        dialAdvancedCapturing(ussdCode, phoneNumber).success

    /**
     * W3.C — the real Advanced dial (Hybrid multiStepUssd + handleAdvancedMode parity).
     *
     * Unlike Express (a single sendUssdRequest), Advanced navigates the Safaricom USSD menu
     * tree through the dialer UI driven by UssdAccessibilityService:
     *   1. extractSteps splits the (already BH/AMT-formatted) code into [*BASE#, reply, reply…].
     *   2. The reply steps go into UssdStepsRepository; the session is reset.
     *   3. *BASE# is dialled via ACTION_CALL (optionally pinned to a SIM via PhoneAccountHandle,
     *      which stays null until W3.F wires dual-SIM).
     *   4. We await UssdSessionManager, which the accessibility service completes once it has
     *      typed every step and read the final dialog.
     * Success(text) → (success=true, text); Failure(text) → (false, text); timeout → isTimeout.
     *
     * MONEY-SAFETY: like Express, this opens the USSD session AT MOST ONCE (a single ACTION_CALL).
     * No retry happens here; the pipeline owns retries and only re-dials on a FAILED outcome.
     */
    suspend fun dialAdvancedCapturing(
        ussdCode: String,
        phoneNumber: String,
        phoneAccountHandle: PhoneAccountHandle? = null,
        timeoutMillis: Long = 60_000L
    ): UssdDialResult {
        if (dryRun) {
            Log.d(TAG, "🧪 DRY RUN — ADVANCED would navigate: $ussdCode for $phoneNumber")
            return UssdDialResult(success = true, response = "DRY_RUN")
        }
        return try {
            val steps = UssdUtils.extractSteps(ussdCode)
            if (steps.isEmpty()) {
                return UssdDialResult(false, "USSD code is missing")
            }
            // W3.F: pin to the configured dial SIM. Use the explicit param if given, else resolve
            // from settings (null when single-SIM/unresolved → platform default, pre-W3.F behavior).
            val handle = phoneAccountHandle ?: SimSubscriptionResolver.dialPhoneAccountHandle(context)
            // Queue the menu-reply steps (everything after the dialled base) and arm the session.
            UssdStepsRepository.addSteps(steps.drop(1))
            val first = UssdUtils.formatFirstStep(steps.first())
            UssdSessionManager.resetSession()

            val encoded = Uri.encode(first)
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$encoded")
                handle?.let { putExtra(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, it) }
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            withContext(Dispatchers.Main) { context.startActivity(intent) }
            Log.d(TAG, "ADVANCED dial started: $first (${steps.size - 1} step(s) queued)")

            val state = withTimeoutOrNull(timeoutMillis) {
                UssdSessionManager.waitForCompletion().await()
            }
            // Recycle session/steps for next time (Hybrid clears + resets after the await).
            UssdStepsRepository.clearSteps()
            UssdSessionManager.resetSession()

            when (state) {
                is UssdSessionState.Success -> UssdDialResult(true, state.response)
                is UssdSessionState.Failure -> UssdDialResult(false, state.reason)
                else -> {
                    Log.w(TAG, "ADVANCED dial timed out after ${timeoutMillis}ms for $first")
                    UssdDialResult(false, "Transaction timed out", isTimeout = true)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "dialAdvancedCapturing error: ${e.message}", e)
            UssdStepsRepository.clearSteps()
            UssdSessionManager.resetSession()
            UssdDialResult(false, e.message)
        }
    }
    fun cancelCurrentUssd() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}
// ── Data classes ───────────────────────────────────────────────────────────
// W3.B — result of a capturing Express dial.
// W3.A — isTimeout distinguishes a withTimeoutOrNull miss (no callback fired in time →
// route to TimeoutChain) from a genuine onReceiveUssdResponseFailed callback (→ FAILED branch).
data class UssdDialResult(
    val success: Boolean,
    val response: String?,
    val isTimeout: Boolean = false
)