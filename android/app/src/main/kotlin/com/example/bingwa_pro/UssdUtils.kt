// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdUtils.kt
package com.example.bingwa_pro

/**
 * W3.C — verbatim port of Hybrid's UssdUtils companion. Turns a fully-formatted USSD code
 * (BH/AMT already substituted by the caller, exactly as Hybrid's PreDialHandler does before
 * UssdDialingHandler) into the Advanced-mode step list, and classifies the final dialog text.
 *
 * extractSteps:
 *   - Bracketed form  "[*X*Y#]rest"  → first step "*<inside-brackets>#", then `rest` split on '*'.
 *   - Normal form     "*A*B*C#"      → first step "*A#", then ["B","C", ...] as bare menu replies.
 *   The first element is what gets DIALED; every later element is typed into a menu dialog,
 *   one per step, by the accessibility service.
 *
 * SUCCESS_REGEX is Hybrid's exact pattern (do NOT edit the alternatives or wording — the
 * Advanced SUCCESS/FAILED decision rides entirely on isSuccessfulResponse against the final
 * dialog text). Bilingual (English + Swahili) and covers airtime/data/SMS/Bonga/recommend.
 */
object UssdUtils {

    private val SUCCESS_REGEX = Regex(
        "(?i)\\b(Kindly wait as we process your request|Kindly wait while we process your request|" +
            "You have successfully purchased|" +
            "You have transferred \\d+\\.\\d{2} KSH from your account to|" +
            "You have transferred \\d+ Bonga Points to|" +
            "Airtime Bal|" +
            "Tafadhali subiri tunaposhughulikia ombi lako|" +
            "Message Sent|Message has been sent successfully|" +
            "Umetuma shilingi \\d+\\.\\d{2}|" +
            "Recommendation for \\d{10,13} submitted successfully).*"
    )

    fun extractSteps(ussdCode: String): List<String> {
        val result = mutableListOf<String>()
        val match = Regex("^\\[\\*?([^]]+)](.*)").matchEntire(ussdCode)
        if (match == null) {
            // Normal form: split the trimmed code on '*', first token is the dialled base.
            val parts = ussdCode.trimEnd('#').split("*").filter { it.isNotEmpty() }
            if (parts.isNotEmpty()) {
                result.add("*${parts.first()}#")
                result.addAll(parts.drop(1))
            }
        } else {
            // Bracketed form: the bracket content is the dialled base; the tail are menu steps.
            val firstGroup = match.groups[1]?.value ?: ""
            val rest = match.groups[2]?.value ?: ""
            result.add("*$firstGroup#")
            if (rest.isNotEmpty()) {
                result.addAll(rest.trimEnd('#').split("*").filter { it.isNotEmpty() })
            }
        }
        return result
    }

    fun formatFirstStep(step: String): String = when {
        step.startsWith("*") && step.endsWith("#") -> step
        step.startsWith("*") -> "$step#"
        step.endsWith("#") -> "*$step"
        else -> "*$step#"
    }

    fun isSuccessfulResponse(response: String): Boolean = SUCCESS_REGEX.containsMatchIn(response)

    fun isInsufficientAirtimeResponse(responseMessage: String): Boolean =
        responseMessage.contains("do not have sufficient airtime", ignoreCase = true)
}