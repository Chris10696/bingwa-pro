package com.example.bingwa_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import kotlinx.coroutines.*

class MpesaMessageListener : BroadcastReceiver() {
    // No constructor parameters. Android instantiates BroadcastReceivers
    // registered in the manifest using a no-argument constructor only.
    // Passing context via constructor would cause a crash on every SMS received.

    private val TAG = "MpesaListener"

    // Known Safaricom M-PESA sender IDs in Kenya
    private val mpesaSenders = setOf("MPESA", "40400", "40401")

    // Matches real Safaricom till/paybill payment confirmation messages.
    // Example: "AB12CD34EF Confirmed. KES19.00 received from JOHN DOE
    //           0712345678 on 14/4/26 at 10:30 AM. New M-PESA balance..."
    private val confirmationPattern = Regex(
        """Confirmed\.\s+KES\s*([\d,]+\.?\d*)\s+received\s+from\s+[\w\s]+\s+(07\d{8}|2547\d{8}|01\d{8}|2541\d{8})""",
        RegexOption.IGNORE_CASE
    )

    // Fallback pattern for slightly different message formats
    private val fallbackPattern = Regex(
        """KES\s*([\d,]+\.?\d*)\s+(?:received\s+from|paid\s+by)\s+[\w\s]*?(07\d{8}|2547\d{8}|01\d{8}|2541\d{8})""",
        RegexOption.IGNORE_CASE
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return

        for (message in messages) {
            val body = message.messageBody ?: continue
            val sender = message.originatingAddress ?: ""

            Log.d(TAG, "SMS from: $sender")

            // Only process messages from known M-PESA sender IDs.
            // This prevents processing personal transfers, withdrawal
            // confirmations, or any non-payment SMS.
            if (!isMpesaPaymentMessage(sender, body)) {
                Log.d(TAG, "Skipping non-M-PESA or non-payment SMS")
                continue
            }

            Log.d(TAG, "M-PESA payment SMS detected. Processing...")

            // Use application context to avoid memory leaks in async work
            val appContext = context.applicationContext
            CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
                processMpesaPayment(appContext, body)
            }
        }
    }

    private fun isMpesaPaymentMessage(sender: String, body: String): Boolean {
        val fromMpesa = mpesaSenders.any { sender.contains(it, ignoreCase = true) }
        // Must be from M-PESA AND must contain "Confirmed" and "received"
        // to confirm it is specifically a payment receipt, not a withdrawal
        // or balance alert
        val isPaymentReceipt = body.contains("Confirmed", ignoreCase = true) &&
                body.contains("received", ignoreCase = true) &&
                body.contains("KES", ignoreCase = true)

        return fromMpesa && isPaymentReceipt
    }

    private suspend fun processMpesaPayment(context: Context, body: String) {
        val paymentInfo = parseMpesaMessage(body)

        if (paymentInfo == null) {
            Log.w(TAG, "Could not parse payment details from M-PESA message")
            Log.w(TAG, "Raw message: $body")
            return
        }

        Log.d(TAG, "Payment parsed — Amount: ${paymentInfo.amount} cents, " +
                "Customer: ${paymentInfo.customerPhone}, Ref: ${paymentInfo.reference}")

        val ussdEngine = UssdEngine(context)
        val route = ussdEngine.findUssdRouteByPrice(paymentInfo.amount)

        if (route == null) {
            Log.w(TAG, "No USSD route matched amount: ${paymentInfo.amount} cents")
            Log.w(TAG, "Check that this amount matches a product price in UssdEngine")
            return
        }

        Log.d(TAG, "Matched route: ${route.name} | Delivery: ${route.delivery}")

        val ussdCode = ussdEngine.buildUssdCode(route, paymentInfo.customerPhone)
        Log.d(TAG, "Final USSD code: $ussdCode")

        val success = if (route.delivery == "EXPRESS") {
            ussdEngine.executeExpressUssd(ussdCode, paymentInfo.customerPhone)
        } else {
            ussdEngine.executeAdvancedUssd(ussdCode, paymentInfo.customerPhone)
        }

        if (success) {
            Log.d(TAG, "USSD executed successfully for ${paymentInfo.customerPhone}")
        } else {
            Log.e(TAG, "USSD execution failed for ${paymentInfo.customerPhone}")
        }
    }

    private fun parseMpesaMessage(body: String): MpesaPaymentInfo? {
        // Try primary pattern first, then fallback
        val match = confirmationPattern.find(body) ?: fallbackPattern.find(body)

        if (match == null) {
            Log.w(TAG, "No regex match found in message")
            return null
        }

        val amountStr = match.groupValues[1].replace(",", "")
        val rawPhone = match.groupValues[2]

        val amount = amountStr.toDoubleOrNull()
        if (amount == null) {
            Log.w(TAG, "Could not parse amount from: $amountStr")
            return null
        }

        // Normalize phone to 07XXXXXXXX format for USSD substitution
        val normalizedPhone = normalizePhone(rawPhone)

        // Extract transaction reference (e.g. "AB12CD34EF" at start of message)
        val refMatch = Regex("""^([A-Z0-9]{10})""").find(body.trim())
        val reference = refMatch?.groupValues?.get(1) ?: "N/A"

        // Convert KES amount to cents to match priceCents in UssdEngine
        val amountInCents = (amount * 100).toInt()

        return MpesaPaymentInfo(
            amount = amountInCents,
            customerPhone = normalizedPhone,
            reference = reference,
            rawMessage = body
        )
    }

    private fun normalizePhone(phone: String): String {
        return when {
            phone.startsWith("2547") -> "0" + phone.substring(3) // 2547XXXXXXXX → 07XXXXXXXX
            phone.startsWith("2541") -> "0" + phone.substring(3) // 2541XXXXXXXX → 01XXXXXXXX
            phone.startsWith("07") -> phone
            phone.startsWith("01") -> phone
            else -> phone
        }
    }
}

data class MpesaPaymentInfo(
    val amount: Int,         // In cents — matches priceCents in UssdEngine
    val customerPhone: String,
    val reference: String,
    val rawMessage: String
)