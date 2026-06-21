// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\AutoReplyTemplates.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log

/**
 * W3.M — on-device auto-reply templates (Hybrid parity, decision A).
 *
 * Hybrid stores auto-replies in a Room table (EnhancedAutoReplyEntity), seeded once by
 * DatabaseInitializer.initializeDefaultEnhancedAutoReplies with six verbatim defaults
 * (id, title, message, isActive=true, type, amount=null). The agent edits them later via
 * the AutoReply screen (Pro: W4). Since Pro has no Room yet and the edit-UI is W4, we seed
 * the identical six defaults into SharedPreferences keyed by AutoReplyType — the native
 * sender reads them at send time. When W4 adds the edit-UI, it writes the same keys.
 *
 * The SUCCESS template is the ONLY change from Hybrid's literals: "Bingwa Hybrid" →
 * "Bingwa Nexus" (client rebrand). Everything else is byte-for-byte. KEY_SEEDED is
 * bumped (v2) to re-seed the new brand over an install that already seeded the old text.
 *
 * Placeholder substitution mirrors AutoReplyPlaceHolder.replacePlaceholders exactly:
 *   <firstName>  first token of the customer name (split on " "), else ""
 *   <surname>    last token of the customer name, else ""
 *   <mpesaCode>  the M-Pesa transaction code
 *   <amount>     amount paid (whole KES)
 *   <offerName>  matched offer name, else "null"
 *   <offerPrice> matched offer price, else "null"
 * On the device the customer's full name often isn't known (the SMS only yields senderName);
 * callers pass what they have and the rest resolve to "" / "null", exactly as Hybrid would
 * for a sparse customer record.
 */
object AutoReplyTemplates {
    private const val TAG = "AutoReplyTemplates"
    private const val PREFS = "bingwa_auto_replies"
    private const val KEY_SEEDED = "seeded_v2"

    // AutoReplyType (Hybrid verbatim ordinals): SUCCESS=0, FAILED=1, OFFER_UNAVAILABLE=2,
    // ALREADY_RECOMMENDED=3, APP_PAUSED=4, CUSTOMER_BLOCKED=5.
    enum class AutoReplyType { SUCCESS, FAILED, OFFER_UNAVAILABLE, ALREADY_RECOMMENDED, APP_PAUSED, CUSTOMER_BLOCKED }

    // The six verbatim Hybrid seed messages (SUCCESS rebranded Hybrid→Pro).
    private val DEFAULTS: Map<AutoReplyType, String> = mapOf(
        AutoReplyType.SUCCESS to
            "Hi <firstName>, Thank you for purchasing from Bingwa Nexus",
        AutoReplyType.ALREADY_RECOMMENDED to
            "Hello <firstName>, you have already purchased this offer today. Please try again tomorrow",
        AutoReplyType.FAILED to
            "Hello <firstName>, Your request failed. Please hold as we look into the issue",
        AutoReplyType.OFFER_UNAVAILABLE to
            "Hi <firstName>, there is no offer matching the amount you have paid. Please pay the correct amount then try again",
        AutoReplyType.APP_PAUSED to
            "Hi <firstName>, there is an issue affecting our systems. You will however get your offer as soon as they become operational. Thank you",
        AutoReplyType.CUSTOMER_BLOCKED to
            "Hi <firstName>, there is an issue affecting your account. Please reach out to us for assistance",
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Seed the six defaults once (idempotent). Safe to call on every app start. */
    fun seedIfNeeded(context: Context) {
        val p = prefs(context)
        if (p.getBoolean(KEY_SEEDED, false)) return
        val e = p.edit()
        for ((type, msg) in DEFAULTS) {
            e.putString(keyMessage(type), msg)
            e.putBoolean(keyActive(type), true) // Hybrid seeds all six isActive=true
        }
        e.putBoolean(KEY_SEEDED, true)
        e.apply()
        Log.d(TAG, "Seeded ${DEFAULTS.size} default auto-reply templates")
    }

    /** The (possibly agent-edited in W4) template for [type], or the seed default. */
    fun template(context: Context, type: AutoReplyType): String =
        prefs(context).getString(keyMessage(type), DEFAULTS[type]) ?: (DEFAULTS[type] ?: "")

    /** Whether this type's auto-reply is active. Defaults true (Hybrid seed). */
    fun isActive(context: Context, type: AutoReplyType): Boolean =
        prefs(context).getBoolean(keyActive(type), true)

    /**
     * Resolve a template for [type] with placeholder substitution, or null if the type's
     * reply is inactive or has no template. Mirrors Hybrid's replacePlaceholders.
     *
     * @param customerName full name if known (split on " "); blank → <firstName>/<surname> = ""
     * @param offerName    matched offer name, or null → "null" (Hybrid's literal fallback)
     * @param offerPrice   matched offer price, or null → "null"
     */
    fun resolve(
        context: Context,
        type: AutoReplyType,
        customerName: String?,
        mpesaCode: String?,
        amount: Int?,
        offerName: String?,
        offerPrice: Int?,
    ): String? {
        if (!isActive(context, type)) return null
        val raw = template(context, type)
        if (raw.isBlank()) return null

        val parts = (customerName ?: "").split(" ").filter { it.isNotEmpty() }
        val firstName = parts.firstOrNull() ?: ""
        val surname = parts.lastOrNull() ?: ""

        return raw
            .replace("<firstName>", firstName)
            .replace("<surname>", surname)
            .replace("<mpesaCode>", mpesaCode ?: "")
            .replace("<amount>", amount?.toString() ?: "")
            .replace("<offerName>", offerName ?: "null")
            .replace("<offerPrice>", offerPrice?.toString() ?: "null")
    }

    private fun keyMessage(type: AutoReplyType) = "msg_${type.name}"
    private fun keyActive(type: AutoReplyType) = "active_${type.name}"
}