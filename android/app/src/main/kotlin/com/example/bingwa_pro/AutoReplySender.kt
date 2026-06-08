// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\AutoReplySender.kt
package com.example.bingwa_pro

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * W3.M — sends customer auto-replies. Verbatim behavioral port of Hybrid's
 * SendSmsUseCase (the actual SmsManager send) + SendAutoReplyMessageUseCase
 * (template resolve + send) + AutoReplyHandler.determineAutoReplyType (status→type).
 *
 * SendSmsUseCase parity:
 *   - hasSmsPermissions: SEND_SMS && READ_PHONE_STATE (logs + no-ops if missing).
 *   - getSmsManager(subId): API≥31 getSmsManagerForSubscriptionId; ≥28 default.createForSubscriptionId;
 *     else getDefault(). On error logs "Error getting SmsManager" and returns null.
 *   - send: ≤160 chars → sendTextMessage; else divideMessage + sendMultipartTextMessage.
 *
 * SendAutoReplyMessageUseCase parity:
 *   - resolve template by type (active only), substitute placeholders, send to customer phone.
 *   - Hybrid skips SUBSCRIPTION_RENEWAL / AIRTIME_BALANCE_CHECK transactions; callers here only
 *     invoke for real customer-facing outcomes, and renewals never carry a customer to reply to.
 *
 * SIM: uses the default SMS subscription id for now (single-SIM). Hybrid picks the
 * auto-reply SIM via SubscriptionIdFetcherUseCase.getSmsSimSubscriptionId — dual-SIM
 * autoReplySim selection is W3.F. getDefaultSmsSubId() returns the system default, which
 * on a single-SIM device is the only SIM (correct), and on dual-SIM is the user's default
 * SMS SIM (a sensible default until W3.F lets the agent choose).
 */
object AutoReplySender {
    private const val TAG = "AutoReplySender"

    /**
     * Map a terminal transaction status to its AutoReplyType (Hybrid
     * AutoReplyHandler.determineAutoReplyType — a when() over status). Unknown/non-terminal
     * statuses → null (no reply). Status strings match Pro's backend TransactionStatus.
     */
    fun autoReplyTypeForStatus(status: String): AutoReplyTemplates.AutoReplyType? =
        when (status.uppercase()) {
            "SUCCESS" -> AutoReplyTemplates.AutoReplyType.SUCCESS
            "FAILED_ALREADY_RECOMMENDED" -> AutoReplyTemplates.AutoReplyType.ALREADY_RECOMMENDED
            "FAILED" -> AutoReplyTemplates.AutoReplyType.FAILED
            "PAUSED" -> AutoReplyTemplates.AutoReplyType.APP_PAUSED
            "BLOCKED" -> AutoReplyTemplates.AutoReplyType.CUSTOMER_BLOCKED
            "UNMATCHED" -> AutoReplyTemplates.AutoReplyType.OFFER_UNAVAILABLE
            else -> null // RESCHEDULED / PROCESSING / SCHEDULED → no auto-reply
        }

    /**
     * Resolve [type]'s template with the given substitution inputs and send it to
     * [customerPhone]. No-op (with log) if the type is inactive, the phone is blank, the
     * resolved message is empty, or SMS permissions are missing. Safe to call from any
     * background coroutine; never throws (matches Hybrid's try/catch-wrapped send).
     */
    fun sendForType(
        context: Context,
        type: AutoReplyTemplates.AutoReplyType,
        customerPhone: String,
        customerName: String? = null,
        mpesaCode: String? = null,
        amount: Int? = null,
        offerName: String? = null,
        offerPrice: Int? = null,
    ) {
        if (customerPhone.isBlank()) {
            Log.w(TAG, "sendForType($type): blank customer phone — skipping")
            return
        }
        AutoReplyTemplates.seedIfNeeded(context)
        val message = AutoReplyTemplates.resolve(
            context, type, customerName, mpesaCode, amount, offerName, offerPrice,
        )
        if (message.isNullOrBlank()) {
            Log.d(TAG, "sendForType($type): inactive or empty template — not sending")
            return
        }
        send(context, customerPhone, message)
    }

    /** The raw send (SendSmsUseCase.invoke parity). */
    private fun send(context: Context, phone: String, message: String) {
        if (!hasSmsPermissions(context)) {
            Log.e(TAG, "Missing SMS permissions. Cannot send message.")
            return
        }
        val subId = getDefaultSmsSubId(context)
        val sms = getSmsManager(context, subId)
        if (sms == null) {
            Log.e(TAG, "Could not get SMS Manger instance")
            return
        }
        try {
            if (message.length <= 160) {
                sms.sendTextMessage(phone, null, message, null, null)
                Log.d(TAG, "Sent message to $phone")
            } else {
                val parts = sms.divideMessage(message)
                sms.sendMultipartTextMessage(phone, null, parts, null, null)
                Log.d(TAG, "Sent multipart message to $phone")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS: ${e.message}", e)
        }
    }

    private fun hasSmsPermissions(context: Context): Boolean {
        val send = ContextCompat.checkSelfPermission(context, android.Manifest.permission.SEND_SMS)
        val phone = ContextCompat.checkSelfPermission(context, android.Manifest.permission.READ_PHONE_STATE)
        return send == PackageManager.PERMISSION_GRANTED && phone == PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun getSmsManager(context: Context, subId: Int): SmsManager? {
        return try {
            when {
                Build.VERSION.SDK_INT >= 31 -> {
                    val mgr = context.getSystemService(SmsManager::class.java)
                    if (subId != SubscriptionManager.DEFAULT_SUBSCRIPTION_ID) {
                        mgr.createForSubscriptionId(subId)
                    } else {
                        mgr
                    }
                }
                Build.VERSION.SDK_INT >= 28 -> {
                    if (subId != SubscriptionManager.DEFAULT_SUBSCRIPTION_ID) {
                        SmsManager.getDefault().createForSubscriptionId(subId)
                    } else {
                        SmsManager.getDefault()
                    }
                }
                else -> SmsManager.getDefault()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting SmsManager: ${e.message}")
            null
        }
    }

    /**
     * The auto-reply SMS subscription id. W3.F: the configured auto-reply SIM
     * (SEND_SMS_VIA_SIM_2 → slot), falling back to DEFAULT_SUBSCRIPTION_ID when unresolved
     * (single-SIM, or the chosen slot has no active SIM). getSmsManager treats
     * DEFAULT_SUBSCRIPTION_ID as "use the default manager."
     */
    private fun getDefaultSmsSubId(context: Context): Int =
        SimSubscriptionResolver.smsSubId(context) ?: SubscriptionManager.DEFAULT_SUBSCRIPTION_ID
}