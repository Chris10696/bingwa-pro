// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\MpesaMessageListener.kt
package com.example.bingwa_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import kotlinx.coroutines.*

// ─── MpesaMessageListener ─────────────────────────────────────────────────────
//
// This BroadcastReceiver is declared in AndroidManifest.xml and is woken by
// Android every time an SMS arrives on the device's SIM card. It filters for
// messages that look like M-PESA buy-goods payment confirmations and hands them
// to UssdEngine.processPaymentSms() for parsing and USSD execution.
//
// IMPORTANT — No-arg constructor:
// Android instantiates BroadcastReceivers via reflection using an empty
// constructor. Never add constructor parameters here.
//
// PRODUCTION NOTE:
// In production, dryRun is always false so USSD calls are placed for real.
// During local development the test-injection button in Flutter passes
// dryRun = true to UssdEngine directly (via MainActivity), so this receiver
// is NOT involved in debug-mode testing at all.
// ─────────────────────────────────────────────────────────────────────────────
class MpesaMessageListener : BroadcastReceiver() {

    private val TAG = "MpesaListener"

    // Known Safaricom M-PESA sender IDs
    private val mpesaSenders = setOf("MPESA", "40400", "40401")

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return

        for (message in messages) {
            val body   = message.messageBody         ?: continue
            val sender = message.originatingAddress  ?: ""

            Log.d(TAG, "SMS from: $sender")

            if (!isMpesaPaymentMessage(sender, body)) {
                Log.d(TAG, "Skipping — not an M-PESA payment confirmation")
                continue
            }

            Log.d(TAG, "✅ M-PESA payment SMS detected — handing to UssdEngine")

            // Use applicationContext to avoid memory leaks in async work.
            val appContext = context.applicationContext

            CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                // dryRun = false → real USSD execution (production behaviour)
                val engine = UssdEngine(appContext, dryRun = false)
                engine.processPaymentSms(body)
            }
        }
    }

    // ── Helper: only process actual till payment receipts ─────────────────────
    // Rules:
    //   1. Sender must be MPESA / 40400 / 40401
    //   2. Body must contain "Confirmed" + "received" + "KES"
    //      → this excludes withdrawals, balance alerts, and transfers
    private fun isMpesaPaymentMessage(sender: String, body: String): Boolean {
        val fromMpesa = mpesaSenders.any { sender.contains(it, ignoreCase = true) }
        val isPaymentReceipt =
            body.contains("Confirmed",  ignoreCase = true) &&
            body.contains("received",   ignoreCase = true) &&
            body.contains("KES",        ignoreCase = true)
        return fromMpesa && isPaymentReceipt
    }
}

// ── Shared data class (referenced by UssdEngine and tests) ───────────────────
data class MpesaPaymentInfo(
    val amount:        Int,     // In cents — matches priceCents in UssdEngine
    val customerPhone: String,
    val reference:     String,
    val rawMessage:    String
)