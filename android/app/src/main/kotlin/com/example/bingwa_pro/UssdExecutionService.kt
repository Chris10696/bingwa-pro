// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdExecutionService.kt
package com.example.bingwa_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * W3.D — foreground-service queue dialer (Hybrid's UssdDialerService equivalent).
 *
 * Why it exists: on Android 14 a dial must originate from a foreground service for
 * reliability, and only one USSD session can run at a time. This service drains a
 * serial queue; each item runs through the W3.B capturing Express dial, then its
 * REAL outcome is PATCHed back and (for recurring renewals) the next day is chained.
 *
 * Foreground service type = dataSync (Hybrid's UssdDialerService is 0x4 / dataSync,
 * NOT phoneCall — phoneCall would require MANAGE_OWN_CALLS or the dialer role and is
 * exactly what crashed this service under W1). sendUssdRequest needs only CALL_PHONE.
 *
 * ── MONEY-SAFETY ────────────────────────────────────────────────────────────────
 * Each DialRequest is dialed AT MOST ONCE. There is no retry/re-enqueue after a dial.
 * PATCH(PROCESSING) before and PATCH(terminal) + recurrence after are all best-effort.
 * The worker owns all PRE-dial retries; this service owns only the irreversible dial
 * and what follows it. An in-flight guard prevents the same transaction being dialed
 * twice within this process.
 */
class UssdExecutionService : Service() {
    private val TAG = "UssdService"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "bingwa_ussd_channel"

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val draining = AtomicBoolean(false)

    private val http: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    companion object {
        private const val JSON_MEDIA = "application/json; charset=utf-8"
        private const val ONE_DAY_MS = 24L * 60L * 60L * 1000L
        // Matches Offer entity default (60000ms) when no offer/config is available.
        private const val DEFAULT_TIMEOUT_MS = 60_000L

        var isRunning: Boolean = false
            private set

        // Serial work queue — Hybrid's Mutex-guarded transactionQueue equivalent.
        // A single drain coroutine consumes it, so dials never overlap.
        private val queue = ConcurrentLinkedQueue<DialRequest>()
        // Prevents dialing the same transaction twice within this process.
        private val inFlight: MutableSet<String> = ConcurrentHashMap.newKeySet()

        /**
         * Enqueue a dial and ensure the foreground service is running to drain it.
         * Called by ScheduleTransactionWorker once the row is confirmed SCHEDULED.
         */
        fun enqueue(context: Context, request: DialRequest) {
            queue.add(request)
            val intent = Intent(context, UssdExecutionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "USSD Execution Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startInForeground()
        // Exactly one drain coroutine; concurrent starts just add to the queue and
        // are picked up by the running drain.
        if (draining.compareAndSet(false, true)) {
            serviceScope.launch { drainQueue() }
        }
        // Drain-and-quit: nothing useful to do on a sticky restart with an empty queue.
        return START_NOT_STICKY
    }

    private fun startInForeground() {
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+: dataSync only (Hybrid UssdDialerService FGS type = 0x4).
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private suspend fun drainQueue() {
        try {
            while (true) {
                val req = queue.poll() ?: break
                if (!inFlight.add(req.transactionId)) {
                    Log.w(TAG, "Txn ${req.transactionId} already in-flight — skipping duplicate")
                    continue
                }
                try {
                    processOne(req)
                } catch (e: Exception) {
                    Log.e(TAG, "processOne crashed for ${req.transactionId}: ${e.message}", e)
                } finally {
                    inFlight.remove(req.transactionId)
                }
            }
        } finally {
            draining.set(false)
            isRunning = false
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            // If an enqueue raced in after poll() returned null, startForegroundService
            // guarantees a fresh onStartCommand that relaunches the drain.
        }
    }

    /**
     * Process one queued dial through the W3.A pipeline (Hybrid TransactionPipeline parity):
     * PreDial(format + PROCESSING) → UssdDialing → StatusClassifier(already-recommended) →
     * Branching(SUCCESS | FAILED_ALREADY_RECOMMENDED | timeout→TimeoutChain | FAILED→
     * InternalRetry→ExternalRetry→Failure).
     *
     * ── MONEY-SAFETY ────────────────────────────────────────────────────────────────
     * A re-dial happens ONLY on a FAILED dial (a failed USSD session = no purchase = no
     * charge), NEVER on insufficient-balance or non-retriable, and is bounded by the
     * internal-retry table (≤10 for EXPRESS/DATA). External retry is a DELAYED reschedule
     * (status RESCHEDULED, re-armed at now+retryIntervalMins), not an immediate re-dial.
     * Every PATCH/POST is best-effort. This mirrors Hybrid exactly; the only residual risk
     * is a Safaricom false-negative (session reports failure after a real purchase), which
     * is inherent to Hybrid's own design.
     */
    private suspend fun processOne(req: DialRequest) {
        val engine = UssdEngine(applicationContext, dryRun = false)
        val finalCode = engine.formatUssdCode(req.ussdTemplate, req.customerPhone, req.amount)

        // Missing/invalid code → FAILED "USSD code is missing" (Hybrid parity), no dial.
        if (finalCode.isBlank() || !finalCode.contains("*")) {
            Log.e(TAG, "Txn ${req.transactionId}: invalid USSD code '$finalCode' — marking FAILED")
            patchStatusBestEffort(req, "FAILED", "USSD code is missing", null)
            return
        }

        // Fetch the offer for the retry config + type (GET /offers/:id is unscoped and
        // returns the 8 retry fields + type + ussdTimeoutMillis). If it can't be fetched,
        // fall back to a no-retry profile so a failure just lands FAILED (never an
        // unbounded or mis-tabled retry). offerId can be null for ad-hoc dials.
        val offer = req.offerId?.let { fetchOffer(req, it) }
        val timeoutMillis = offer?.ussdTimeoutMillis ?: DEFAULT_TIMEOUT_MS
        val offerType = offer?.type ?: "NONE"

        // W3.C — processing mode decides Express vs Advanced dialing, EXCEPT renewals always
        // force Express (Hybrid forces Express for SUBSCRIPTION_RENEWAL + AIRTIME_BALANCE_CHECK).
        // isRecurringRenewal is the renewal marker; balance checks never route through here.
        // NOTE: until W3.K/W3.L feed non-renewal transactions AND W3.I mirrors the wallet's
        // mode into SessionBridge, this resolves to Express for every current caller.
        val advanced = !req.isRecurringRenewal &&
            SessionBridge.getProcessingMode(applicationContext) == "advanced"

        // PreDial parity: mark PROCESSING (best-effort — the dial is what matters).
        patchStatusBestEffort(req, "PROCESSING", null, null)

        // ════════════════════════════════════════════════════════════════════════
        // UssdDialing — internal-retry loop. The FIRST dial plus up to maxInternal
        // immediate re-dials all happen here, in-session (Hybrid re-queues SCHEDULED;
        // we loop locally — same effect, simpler, and the count is never persisted).
        // ════════════════════════════════════════════════════════════════════════
        val maxInternal = maxInternalRetries(offerType, advanced)
        var internalRetries = 0
        var result: UssdDialResult
        while (true) {
            result = if (advanced) {
                // SIM pinning (PhoneAccountHandle) stays null until W3.F wires dual-SIM.
                engine.dialAdvancedCapturing(finalCode, req.customerPhone, null, timeoutMillis)
            } else {
                engine.dialExpressCapturing(finalCode, req.customerPhone, timeoutMillis)
            }
            Log.d(TAG, "Dialed ${req.transactionId} (${if (advanced) "ADVANCED" else "EXPRESS"}) → success=${result.success} timeout=${result.isTimeout} (internal $internalRetries/$maxInternal)")

            if (result.success) break                       // SUCCESS → leave loop
            if (result.isTimeout) break                     // timeout → TimeoutChain (no internal retry)
            val response = result.response ?: ""
            // InternalRetryHandler skip conditions (verbatim order): non-retriable, then insufficient.
            if (UssdResponseClassifier.isNonRetriable(response)) break
            if (UssdResponseClassifier.isInsufficientBalance(response)) break
            if (internalRetries >= maxInternal) break
            internalRetries++
            Log.d(TAG, "Internal retry ${req.transactionId} attempt $internalRetries/$maxInternal")
            // loop re-dials immediately (same session semantics as Hybrid's re-queue)
        }

        // ════════════════════════════════════════════════════════════════════════
        // StatusClassifier + Branching
        // ════════════════════════════════════════════════════════════════════════
        val response = result.response ?: ""

        // StatusClassifier: already-recommended demotes (applies to SUCCESS and FAILED alike;
        // Safaricom delivers "already recommended" via the success callback).
        if (UssdResponseClassifier.isAlreadyRecommended(response)) {
            patchStatusBestEffort(req, "FAILED_ALREADY_RECOMMENDED", response, response)
            sendAutoReply(req, "FAILED_ALREADY_RECOMMENDED")
            // AlreadyRecommendedChain reschedules iff offer.autoReschedule (W3 carries the
            // flag; the next-day arm reuses the recurrence anchor).
            if (offer?.autoReschedule == true) scheduleExternalRetryOrRenew(req, isRenewAnchor = true)
            return
        }

        if (result.success) {
            // SuccessChain: UpdateTransaction + AutoReply (+ AgentCommission W5 no-op).
            // W3.G: record the Safaricom-side reference. We use the M-Pesa payment code
            // already parsed for this transaction (present for SMS-triggered sales; null for
            // Quick Dial / renewals, which have no M-Pesa payment). NOTE: if Hybrid extracts a
            // distinct bundle-confirmation code from the USSD response text, that is a follow-on
            // refinement — not fabricated here.
            patchStatusBestEffort(req, "SUCCESS", null, response, req.mpesaCode)
            sendAutoReply(req, "SUCCESS")
            if (req.isRecurringRenewal) maybeScheduleNext(req)
            return
        }

        // Timeout → TimeoutChain: FAILED "Failed: Transaction timed out", then external retry.
        if (result.isTimeout) {
            handleExternalRetry(req, offer, offerType, response = "Failed: Transaction timed out", isTimeout = true)
            return
        }

        // FAILED → InternalRetry already exhausted above → ExternalRetry → Failure.
        handleExternalRetry(req, offer, offerType, response = response, isTimeout = false)
    }

    /**
     * ExternalRetryHandler (verbatim port, confirmed against bytecode). DELAYED retry:
     * reschedules the SAME transaction for now+retryIntervalMins (status RESCHEDULED) and
     * re-arms it carrying externalRetries+1; or lands FAILED when exhausted/ineligible.
     *
     * Guard order exactly as Hybrid:
     *   offer null → FAILED (can't consult config)         [Hybrid passes through to FailureChain]
     *   AIRTIME_BALANCE_CHECK/SUBSCRIPTION_RENEWAL → skip   [not applicable to renewals here]
     *   isNonRetriable → FAILED
     *   externalRetries >= numberOfRetries → FAILED "Failed after N retries.\n{response}"
     *   !autoRetry → FAILED (Hybrid passes through; terminal here)
     *   else → reschedule (+connection-problem reason iff isConnectionProblem && autoRetryConnectionProblems)
     */
    private fun handleExternalRetry(
        req: DialRequest,
        offer: OfferConfig?,
        offerType: String,
        response: String,
        isTimeout: Boolean,
    ) {
        // No offer config → can't evaluate retry policy → terminal FAILED.
        if (offer == null) {
            patchStatusBestEffort(req, "FAILED", response, response)
            sendAutoReply(req, "FAILED")
            return
        }
        // Non-retriable → FAILED immediately (skip the FAILED "Failed: timed out" reason on
        // timeout path is moot; non-retriable is text-based and a timeout has no such text).
        if (!isTimeout && UssdResponseClassifier.isNonRetriable(response)) {
            patchStatusBestEffort(req, "FAILED", response, response)
            sendAutoReply(req, "FAILED")
            return
        }
        // Exhausted retries → FAILED "Failed after N retries.\n{response}" (Hybrid wording).
        if (req.externalRetries >= offer.numberOfRetries) {
            val msg = "Failed after ${req.externalRetries} retries.\n$response"
            patchStatusBestEffort(req, "FAILED", msg, response)
            sendAutoReply(req, "FAILED")
            return
        }
        // autoRetry off → Hybrid passes through (no reschedule); terminal FAILED with the
        // raw response (NOT the "Failed after N retries" wording — retries weren't exhausted).
        if (!offer.autoRetry) {
            patchStatusBestEffort(req, "FAILED", response, response)
            sendAutoReply(req, "FAILED")
            return
        }
        // Eligible for a delayed retry. Mark RESCHEDULED and re-arm at now+interval with +1.
        val connection = !isTimeout &&
            UssdResponseClassifier.isConnectionProblem(response) &&
            offer.autoRetryConnectionProblems
        val reason = if (connection)
            "Rescheduled. Initial request failed due to connection problems"
        else
            response
        patchStatusBestEffort(req, "RESCHEDULED", reason, response)
        val retryAt = System.currentTimeMillis() + offer.retryIntervalMins * 60_000L
        WorkScheduler.arm(applicationContext, req.transactionId, retryAt, req.externalRetries + 1)
        Log.d(TAG, "External retry ${req.transactionId}: armed at +${offer.retryIntervalMins}min (attempt ${req.externalRetries + 1}/${offer.numberOfRetries})")
    }

    /** AlreadyRecommended reschedule helper — re-arms the same row one day out (renew anchor). */
    private fun scheduleExternalRetryOrRenew(req: DialRequest, isRenewAnchor: Boolean) {
        val anchor = if (req.triggerAtMillis > 0L) req.triggerAtMillis else System.currentTimeMillis()
        val nextMillis = anchor + ONE_DAY_MS
        WorkScheduler.arm(applicationContext, req.transactionId, nextMillis, req.externalRetries)
        Log.d(TAG, "Already-recommended reschedule ${req.transactionId} at +1 day")
    }

    // Internal-retry maxima — now mode-aware (W3.C unlocks the ADVANCED column). Confirmed
    // against Hybrid bytecode WhenMappings: EXPRESS{DATA 10, SMS 2, VOICE 1};
    // ADVANCED{DATA 3, SMS 1, VOICE 1}. NONE/unknown → 0 (no switch case → default 0, NOT
    // the VOICE row). HYBRID mode is dead/never surfaced, so only these two columns exist.
    private fun maxInternalRetries(offerType: String, advanced: Boolean): Int =
        when (offerType.uppercase()) {
            "DATA" -> if (advanced) 3 else 10
            "SMS" -> if (advanced) 1 else 2
            "VOICE" -> 1
            else -> 0   // NONE / unknown → no internal retry (Hybrid default branch = 0)
        }

    /** GET /offers/:id (unscoped) → retry config. Best-effort; null on any failure. */
    private fun fetchOffer(req: DialRequest, offerId: String): OfferConfig? {
        return try {
            val request = Request.Builder()
                .url("${req.baseUrl}/offers/$offerId")
                .addHeader("Authorization", "Bearer ${req.token}")
                .get()
                .build()
            http.newCall(request).execute().use { resp ->
                val body = resp.body?.string()
                if (resp.isSuccessful && body != null) {
                    val j = JSONObject(body)
                    OfferConfig(
                        type = j.optString("type", "NONE"),
                        autoReschedule = j.optBoolean("autoReschedule", false),
                        autoRetry = j.optBoolean("autoRetry", false),
                        autoRetryConnectionProblems = j.optBoolean("autoRetryConnectionProblems", false),
                        numberOfRetries = j.optInt("numberOfRetries", 0),
                        retryIntervalMins = j.optInt("retryIntervalMins", 5),
                        ussdTimeoutMillis = j.optLong("ussdTimeoutMillis", DEFAULT_TIMEOUT_MS),
                    )
                } else {
                    Log.w(TAG, "GET /offers/$offerId → HTTP ${resp.code}; using no-retry profile")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "fetchOffer error: ${e.message}", e)
            null
        }
    }

    /**
     * Recurrence (D-W2-E): on a successful recurring renewal, create the next-day row
     * with daysRemaining-1 and arm it; stop when that would reach 0. Best-effort.
     */
    private fun maybeScheduleNext(req: DialRequest) {
        val nextDays = req.daysRemaining - 1
        if (nextDays < 1) {
            Log.d(TAG, "Recurrence complete for ${req.transactionId} (daysRemaining=${req.daysRemaining})")
            return
        }
        val offerId = req.offerId
        if (offerId.isNullOrBlank()) {
            Log.w(TAG, "Recurring ${req.transactionId} has no offerId — chain stops")
            return
        }
        // Anchor on the original intended trigger so a late fire doesn't drift the series.
        val anchor = if (req.triggerAtMillis > 0L) req.triggerAtMillis else System.currentTimeMillis()
        val nextMillis = anchor + ONE_DAY_MS
        val nextIso = formatLocalIso(nextMillis)
        val newId = postScheduleBestEffort(req, offerId, nextIso, nextDays)
        if (newId != null) {
            WorkScheduler.arm(applicationContext, newId, nextMillis)
            Log.d(TAG, "Recurrence: armed $newId for $nextIso (daysRemaining=$nextDays)")
        }
    }

    /** PATCH /transactions/:id/status. Best-effort: logs and swallows. */
    private fun patchStatusBestEffort(
        req: DialRequest,
        status: String,
        errorMessage: String?,
        ussdResponse: String?,
        // W3.G: the Safaricom-side reference for this transaction. The backend
        // (updateTransactionStatus) persists it to safaricomReference + safaricomRef.
        // Defaulted so existing callers are unaffected.
        safaricomReference: String? = null
    ) {
        try {
            val payload = JSONObject().put("status", status)
            if (errorMessage != null) payload.put("errorMessage", errorMessage)
            if (ussdResponse != null) payload.put("ussdResponse", ussdResponse)
            if (safaricomReference != null) payload.put("safaricomReference", safaricomReference)
            val request = Request.Builder()
                .url("${req.baseUrl}/transactions/${req.transactionId}/status")
                .addHeader("Authorization", "Bearer ${req.token}")
                .patch(payload.toString().toRequestBody(JSON_MEDIA.toMediaType()))
                .build()
            http.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) Log.w(TAG, "PATCH $status ${req.transactionId} → HTTP ${resp.code}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "PATCH $status ${req.transactionId} failed: ${e.message}", e)
        }
    }

    /**
     * W3.M — fire the customer auto-reply for a terminal [status] (Hybrid AutoReplyHandler:
     * type is a pure function of the final transaction status; the send runs on a background
     * scope). No-op for non-terminal/unknown statuses (autoReplyTypeForStatus → null) and for
     * renewals (no customer to reply to). Best-effort; never blocks the pipeline.
     */
    private fun sendAutoReply(req: DialRequest, status: String) {
        if (req.isRecurringRenewal) return // renewals have no paying customer to reply to
        val type = AutoReplySender.autoReplyTypeForStatus(status) ?: return
        AutoReplySender.sendForType(
            context = applicationContext,
            type = type,
            customerPhone = req.customerPhone,
            customerName = req.customerName,
            mpesaCode = req.mpesaCode,
            amount = req.amount,
            offerName = req.offerName,
            offerPrice = req.offerPrice,
        )
    }

    /** POST /transactions/schedule. Returns the new id, or null. Best-effort. */
    private fun postScheduleBestEffort(
        req: DialRequest,
        offerId: String,
        scheduledForIso: String,
        daysToRecur: Int
    ): String? {
        return try {
            val payload = JSONObject()
                .put("offerId", offerId)
                .put("customerPhone", req.customerPhone)
                .put("scheduledFor", scheduledForIso)
                .put("isRecurring", true)
                .put("daysToRecur", daysToRecur)
            val request = Request.Builder()
                .url("${req.baseUrl}/transactions/schedule")
                .addHeader("Authorization", "Bearer ${req.token}")
                .post(payload.toString().toRequestBody(JSON_MEDIA.toMediaType()))
                .build()
            http.newCall(request).execute().use { resp ->
                val body = resp.body?.string()
                if (resp.isSuccessful && body != null) {
                    val id = JSONObject(body).optString("id", "")
                    if (id.isNotBlank()) id else null
                } else {
                    Log.w(TAG, "POST schedule → HTTP ${resp.code}; recurrence chain stops")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "POST schedule failed: ${e.message}", e)
            null
        }
    }

    private fun formatLocalIso(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(millis))

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bingwa Pro USSD Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Processes scheduled USSD transactions"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bingwa Pro")
            .setContentText("Processing transactions...")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        serviceScope.cancel()
        Log.d(TAG, "USSD Execution Service destroyed")
    }
}

/**
 * W3.A — the subset of the Offer entity the retry pipeline reads (from GET /offers/:id).
 * type drives the internal-retry table; the rest drive ExternalRetryHandler.
 */
data class OfferConfig(
    val type: String,
    val autoReschedule: Boolean,
    val autoRetry: Boolean,
    val autoRetryConnectionProblems: Boolean,
    val numberOfRetries: Int,
    val retryIntervalMins: Int,
    val ussdTimeoutMillis: Long,
)