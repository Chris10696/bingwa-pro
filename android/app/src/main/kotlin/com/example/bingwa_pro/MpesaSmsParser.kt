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

    // ── W4: Till extractor (Hybrid TillMessageExtractor, verbatim) ─────────────────────
    private val RE_TILL_PHONE = Regex("""(\d{12})""")
    private val RE_TILL_NAME = Regex("""from \d{12} (.+?)\. New""", RegexOption.IGNORE_CASE)

    /** Parse a Till/Buy-Goods confirmation, or null if not dialable (no code / no 12-digit phone). */
    fun parseTill(body: String): ParsedMpesa? {
        val code = RE_CODE.find(body)?.groupValues?.getOrNull(1)
        if (code.isNullOrBlank()) { Log.w(TAG, "parseTill: no code (^\\S+) — skipping"); return null }
        val phone = RE_TILL_PHONE.find(body)?.groupValues?.getOrNull(0) ?: ""
        if (phone.isBlank()) { Log.w(TAG, "parseTill: no \\d{12} phone — skipping"); return null }
        val name = RE_TILL_NAME.find(body)?.groupValues?.getOrNull(1) ?: "Unknown"
        val amount = extractAmount(body)
        Log.d(TAG, "Parsed Till — code=$code amount=$amount phone=$phone name=$name")
        return ParsedMpesa(code, phone, name, amount, body)
    }

    // ── W4: SiteLink extractor (Hybrid SiteLinkMessageExtractor, verbatim) ─────────────
    // "BHSL <code> Confirmed … from <buyer> … for <beneficiary> … Ksh<amount>". The bundle is
    // delivered to the "for" number, so that is the customer we dial (fall back to "from").
    private val RE_SL_CODE = Regex("""BHSL\s+([A-Z0-9]+)\s+Confirmed""", RegexOption.IGNORE_CASE)
    private val RE_SL_FOR = Regex("""for\s+(\d+)""", RegexOption.IGNORE_CASE)
    private val RE_SL_FROM = Regex("""from\s+(\d+)""", RegexOption.IGNORE_CASE)

    /** Parse a SiteLink (BHSL) confirmation, or null if not dialable. Inert until W5 (D-W4-1). */
    fun parseSiteLink(body: String): ParsedMpesa? {
        val code = RE_SL_CODE.find(body)?.groupValues?.getOrNull(1)
        if (code.isNullOrBlank()) { Log.w(TAG, "parseSiteLink: no BHSL code — skipping"); return null }
        val customer = RE_SL_FOR.find(body)?.groupValues?.getOrNull(1)
            ?: RE_SL_FROM.find(body)?.groupValues?.getOrNull(1) ?: ""
        if (customer.isBlank()) { Log.w(TAG, "parseSiteLink: no customer number — skipping"); return null }
        val amount = extractAmount(body)
        Log.d(TAG, "Parsed SiteLink — code=$code amount=$amount customer=$customer")
        return ParsedMpesa(code, customer, "Unknown", amount, body)
    }

    /** Dispatch to the right extractor for a classified [type] (M-Pesa path unchanged). */
    fun parseFor(type: SmsType, body: String): ParsedMpesa? = when (type) {
        SmsType.MPESA -> parse(body)
        SmsType.TILL -> parseTill(body)
        SmsType.SITE_LINK -> parseSiteLink(body)
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

/**
 * W4 — SMS payment classification (Hybrid `SmsType`, verbatim patterns + order). Only the three
 * payment-trigger types feed the auto-sale pipeline; classification iterates in this exact
 * ordinal order and returns the FIRST match, so the specific patterns (SiteLink `^BHSL`, Till
 * "received from <n>") win before the generic M-Pesa "received Ksh". Hybrid's non-payment types
 * (recommendation timeout/expired, airtime balance, commission) match none of these → null →
 * the receiver ignores them (each handled in its own wave). `matches` = `Regex(pattern,
 * IGNORE_CASE).containsMatchIn(body)`, exactly as Hybrid's `SmsType.matches`.
 */
enum class SmsType(private val pattern: Regex) {
    SITE_LINK(Regex("""^BHSL""", RegexOption.IGNORE_CASE)),
    TILL(Regex("""received from \d{9,12}""", RegexOption.IGNORE_CASE)),
    MPESA(Regex("""received Ksh\d+(\.\d{2})?""", RegexOption.IGNORE_CASE));

    fun matches(body: String): Boolean = pattern.containsMatchIn(body)

    companion object {
        /** First matching type in ordinal order, or null. Mirrors Hybrid's classify. */
        fun classify(body: String): SmsType? = entries.firstOrNull { it.matches(body) }
    }
}