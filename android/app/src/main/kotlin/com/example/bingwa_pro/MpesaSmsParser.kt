// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\MpesaSmsParser.kt
package com.example.bingwa_pro

import android.util.Log

/**
 * W3.K — the single, authoritative M-Pesa SMS parser. Verbatim behavioral port of
 * Hybrid's detection (SmsType.MPESA) + field extraction (DefaultMessageExtractor),
 * converging Pro's two previously-divergent parsers (the old UssdEngine cents-based
 * regex and MpesaMessageListener's keyword heuristic) into one.
 *
 * Detection: SmsType.MPESA matches `received Ksh\d+(\.\d{2})?` (case-insensitive,
 * containsMatchIn). This is what qualifies a body as an M-Pesa payment.
 *
 * Extraction (each Regex(IGNORE_CASE).find(body), exactly as Hybrid):
 *   - mpesaCode     `^(\S+)`                          group 1 (first token; null if absent)
 *   - senderName    `from (.+?) (\d{10})`             group 1 (default "Unknown")
 *   - customerPhone `(\d{10})`                        group 0 (first 10-digit run; default "")
 *   - amount        `Ksh([\d,]+\.\d{2})`              group 1 → strip commas → toDouble → toInt
 *                                                      (WHOLE shillings; Hybrid truncates)
 *   - time          `on (\d{1,2}/\d{1,2}/\d{2,4} at \d{1,2}:\d{2} [AP]M)` (parsed but unused here)
 *
 * Hybrid throws "Invalid M-Pesa Code" if mpesaCode is absent and rejects when senderPhone
 * is empty (SmsProcessor: "Cannot process message: sender phone is empty"). We mirror both
 * by returning null (caller skips) rather than throwing, since this runs in a fire-and-forget
 * BroadcastReceiver coroutine where a thrown exception would just be swallowed.
 */
object MpesaSmsParser {
    private const val TAG = "MpesaSmsParser"

    // SmsType.MPESA.pattern (verbatim).
    private val MPESA_DETECT = Regex("""received Ksh\d+(\.\d{2})?""", RegexOption.IGNORE_CASE)

    // DefaultMessageExtractor regexes (verbatim).
    private val RE_CODE = Regex("""^(\S+)""", RegexOption.IGNORE_CASE)
    private val RE_SENDER_NAME = Regex("""from (.+?) (\d{10})""", RegexOption.IGNORE_CASE)
    private val RE_PHONE = Regex("""(\d{10})""", RegexOption.IGNORE_CASE)
    private val RE_AMOUNT = Regex("""Ksh([\d,]+\.\d{2})""", RegexOption.IGNORE_CASE)

    /** True if [body] is an M-Pesa payment confirmation (Hybrid SmsType.MPESA match). */
    fun isMpesaPayment(body: String): Boolean = MPESA_DETECT.containsMatchIn(body)

    /**
     * Parse a confirmed M-Pesa payment body into [ParsedMpesa], or null if it can't be
     * parsed into a dialable payment (no code, or no 10-digit customer phone).
     */
    fun parse(body: String): ParsedMpesa? {
        val mpesaCode = RE_CODE.find(body)?.groupValues?.getOrNull(1)
        if (mpesaCode.isNullOrBlank()) {
            Log.w(TAG, "parse: no M-Pesa code (^\\S+) — skipping")
            return null
        }
        val customerPhone = RE_PHONE.find(body)?.groupValues?.getOrNull(0) ?: ""
        if (customerPhone.isBlank()) {
            // Mirrors Hybrid's "Cannot process message: sender phone is empty".
            Log.w(TAG, "parse: sender phone empty — skipping")
            return null
        }
        val senderName = RE_SENDER_NAME.find(body)?.groupValues?.getOrNull(1) ?: "Unknown"
        val amount = extractAmount(body)
        Log.d(TAG, "Parsed M-Pesa — code=$mpesaCode amount=$amount phone=$customerPhone sender=$senderName")
        return ParsedMpesa(
            mpesaCode = mpesaCode,
            customerPhone = customerPhone,
            senderName = senderName,
            amount = amount,
            rawMessage = body,
        )
    }

    /** Ksh([\d,]+\.\d{2}) → strip commas → toDouble → toInt (whole shillings). 0 if absent. */
    private fun extractAmount(body: String): Int {
        val raw = RE_AMOUNT.find(body)?.groupValues?.getOrNull(1) ?: return 0
        val cleaned = raw.replace(",", "")
        return cleaned.toDoubleOrNull()?.toInt() ?: 0
    }
}

/**
 * W3.K — parsed M-Pesa payment. `amount` is whole KES (Hybrid truncates the cents);
 * `mpesaCode` becomes the backend's `mpesaTransactionId` (idempotency key); `rawMessage`
 * is sent as `mpesaMessage` so the persisted transaction keeps the original text.
 */
data class ParsedMpesa(
    val mpesaCode: String,
    val customerPhone: String,
    val senderName: String,
    val amount: Int,
    val rawMessage: String,
)