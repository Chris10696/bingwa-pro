// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\MpesaMessageListener.kt
package com.example.bingwa_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SubscriptionManager
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * W3.K — M-Pesa SMS auto-processing trigger (REWRITTEN, backend-first).
 *
 * Woken by Android on every incoming SMS. The new flow inverts the old
 * dial-then-record path into Hybrid's create-then-dial (D-W3-13):
 *
 *   1. GATES (both must pass, AND-ed exactly like Hybrid):
 *        a. AppState == "running"  — the master switch (W3.N writes it; default "stopped",
 *           so a fresh install does NOT auto-dial until the agent presses play). Hybrid's
 *           SmsBroadcastReceiver ignores SMS unless AppState != STOPPED and only dials when
 *           RUNNING; we collapse to the dial-gate (RUNNING) here.
 *        b. Process-M-Pesa toggle == true — the settings switch (default true, Hybrid parity).
 *   2. SENDER allowlist: MPESA / 40400 / 40401 (hardcoded safety fence; the agent-managed
 *      Authorized-Senders list is W4). A look-alike from a random number can't trigger a dial.
 *   3. DETECT + PARSE via MpesaSmsParser (Hybrid's SmsType.MPESA + DefaultMessageExtractor).
 *   4. POST /transactions/sms-create (SmsCreatePoster). The backend matches amount→offer,
 *      persists SCHEDULED (match) / UNMATCHED (no-match), debits at dial-time on match, and
 *      dedupes on mpesaTransactionId.
 *   5. On 201+shouldDial → enqueue into UssdExecutionService (the W3.D foreground queue), which
 *      formats BH→phone and runs the mode-aware dial→classify→retry pipeline (Advanced fires
 *      the W3.C accessibility engine). 402 / 409 / UNMATCHED → do NOT dial.
 *
 * MONEY-SAFETY: the device performs the irreversible dial ONLY on an explicit
 * 201 + shouldDial=true. Idempotency lives on the backend (mpesaTransactionId unique), so a
 * redelivered SMS broadcast can be seen twice but dials once. Nothing here dials directly —
 * the dial is owned by UssdExecutionService's single-fire queue.
 *
 * No-arg constructor only (Android instantiates BroadcastReceivers via reflection).
 *
 * PAUSED semantics (record-but-don't-dial + APP_PAUSED auto-reply) are deferred to W3.N+W3.M,
 * which own AppState's full lifecycle and auto-reply sending. Here, only RUNNING acts.
 */
class MpesaMessageListener : BroadcastReceiver() {
    private val TAG = "MpesaListener"

    // Known Safaricom M-PESA sender IDs (hardcoded fence; mgmt UI is W4).
    private val mpesaSenders = setOf("MPESA", "40400", "40401")

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val appContext = context.applicationContext

        // GATE 1a — master switch. Only RUNNING dials (Hybrid). STOPPED/PAUSED → ignore here.
        val appState = SessionBridge.getAppState(appContext)
        if (appState != "running") {
            Log.d(TAG, "AppState=$appState (not running) — ignoring SMS")
            return
        }
        // GATE 1b — Process-M-Pesa settings toggle.
        if (!SessionBridge.getProcessMpesa(appContext)) {
            Log.d(TAG, "Process-M-Pesa toggle off — ignoring SMS")
            return
        }
        // GATE 1c — receive-SIM gate (Hybrid validateEnabledSimCards). Only process SMS that
        // arrived on a SIM the agent enabled for receiving payments. The receiving slot comes
        // from the broadcast's "subscription" extra (OEM-variable); if we can't determine it,
        // FAIL OPEN (allow) — missing a real payment is worse than processing one extra SMS.
        val allowedSlots = SimSubscriptionResolver.receivePaymentsAllowedSlots(appContext)
        val smsSlot = receivingSlot(appContext, intent)
        if (smsSlot != null && allowedSlots.isNotEmpty() && smsSlot !in allowedSlots) {
            Log.d(TAG, "SMS arrived on SIM $smsSlot, not in allowed receive set $allowedSlots — ignoring")
            return
        }
        if (smsSlot == null) {
            Log.d(TAG, "Receiving SIM slot unknown — failing open (processing anyway)")
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        for (message in messages) {
            val body = message.messageBody ?: continue
            val sender = message.originatingAddress ?: ""

            // GATE 2 — sender allowlist.
            val fromMpesa = mpesaSenders.any { sender.contains(it, ignoreCase = true) }
            if (!fromMpesa) {
                Log.d(TAG, "Sender '$sender' not in M-Pesa allowlist — skipping")
                continue
            }
            // GATE 3 — detection (Hybrid SmsType.MPESA).
            if (!MpesaSmsParser.isMpesaPayment(body)) {
                Log.d(TAG, "Body not an M-Pesa payment confirmation — skipping")
                continue
            }
            val parsed = MpesaSmsParser.parse(body)
            if (parsed == null) {
                Log.w(TAG, "M-Pesa body matched but parse failed (missing code/phone) — skipping")
                continue
            }

            Log.d(TAG, "✅ M-Pesa payment — code=${parsed.mpesaCode} amount=${parsed.amount} → /sms-create")
            // Step 4+5 off the main thread. Backend create decides dial-or-not.
            CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                when (val outcome = SmsCreatePoster.createAndDecide(appContext, parsed)) {
                    is SmsCreatePoster.SmsCreateOutcome.Dial -> {
                        UssdExecutionService.enqueue(appContext, outcome.request)
                        Log.d(TAG, "Enqueued ${outcome.request.transactionId} for dialing")
                    }
                    is SmsCreatePoster.SmsCreateOutcome.DoNotDial -> {
                        Log.d(TAG, "Not dialing: ${outcome.reason}")
                        // W3.M: UNMATCHED carries an auto-reply hint (e.g. OFFER_UNAVAILABLE).
                        // Fire the customer reply so a no-match payment isn't silent. 402/409
                        // carry no hint → no reply.
                        val hint = outcome.autoReplyType
                        val p = outcome.parsed
                        if (hint != null && p != null) {
                            val type = AutoReplySender.autoReplyTypeForStatus(
                                if (hint.equals("OFFER_UNAVAILABLE", ignoreCase = true)) "UNMATCHED" else hint,
                            )
                            if (type != null) {
                                AutoReplySender.sendForType(
                                    context = appContext,
                                    type = type,
                                    customerPhone = p.customerPhone,
                                    customerName = p.senderName,
                                    mpesaCode = p.mpesaCode,
                                    amount = p.amount,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * The 1-based SIM slot an incoming SMS arrived on, or null if it can't be determined.
     * The receiving subscription id is carried in the broadcast's "subscription" extra (this
     * key is OEM/version-variable and may be absent → null → caller fails open). We map subId
     * → simSlotIndex via SubscriptionManager, returning slot = simSlotIndex + 1.
     */
    private fun receivingSlot(context: Context, intent: Intent): Int? {
        return try {
            val subId = intent.getIntExtra("subscription", -1)
            if (subId < 0) return null
            val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                ?: return null
            @Suppress("MissingPermission")
            val info = sm.getActiveSubscriptionInfo(subId) ?: return null
            info.simSlotIndex + 1
        } catch (e: SecurityException) {
            Log.w(TAG, "receivingSlot: missing READ_PHONE_STATE: ${e.message}")
            null
        } catch (e: Exception) {
            Log.w(TAG, "receivingSlot error: ${e.message}")
            null
        }
    }
}