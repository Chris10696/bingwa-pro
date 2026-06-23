// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdResponseClassifier.kt
package com.example.bingwa_pro

/**
 * W3.A — verbatim port of Hybrid's response classifiers (SmsUtilsKt + TransactionUtilsKt).
 *
 * Every check is a case-insensitive substring match (Kotlin StringsKt.contains(..., true)),
 * exactly as in Hybrid. The strings below were confirmed against the decompiled bytecode —
 * do NOT "improve", regex-ify, or reword them; the retry/branch decisions (and therefore how
 * many times real airtime is spent) depend on these matching Safaricom's wording precisely.
 *
 * These run ONLY on an already-FAILED transaction's responseMessage to decide retry behavior
 * (plus already-recommended, which can demote a SUCCESS). They never decide the initial
 * SUCCESS/FAILED — that is set by which sendUssdRequest callback fired (see UssdEngine).
 */
object UssdResponseClassifier {
    fun isAlreadyRecommended(response: String): Boolean =
        response.contains("already been recommended", ignoreCase = true)

    fun isConnectionProblem(response: String): Boolean =
        response.contains("Connection problem", ignoreCase = true)

    fun isInsufficientBalance(response: String): Boolean =
        response.contains("insufficient airtime", ignoreCase = true) ||
        response.contains("insufficient account balance", ignoreCase = true) ||
        response.contains("insufficient balance", ignoreCase = true) ||
        response.contains("not enough airtime", ignoreCase = true)

    fun isOkoaJahaziFailure(response: String): Boolean =
        response.contains("has Okoa Jahazi and cannot receive bundles", ignoreCase = true)

    fun isSqlError(response: String): Boolean =
        response.contains("Excessive SQLs", ignoreCase = true)

    fun isTryAgainLater(response: String): Boolean =
        response.contains(
            "Sorry we are not able to process your request right now. Please try again later",
            ignoreCase = true,
        )

    /** Hybrid TransactionUtilsKt.isNonRetriableResponse = Okoa-Jahazi OR Excessive-SQLs. */
    fun isNonRetriable(response: String): Boolean =
        isOkoaJahaziFailure(response) || isSqlError(response)

    // ── Pay-with-airtime money-safety (NOT a Hybrid retry classifier) ───────────────────
    /**
     * True when a captured USSD response is a Sambaza/airtime-transfer FAILURE that Safaricom
     * nonetheless delivers through the sendUssdRequest SUCCESS callback (so UssdEngine reports
     * success=true). [UssdExecutionService.processOne] uses this to DEMOTE such a "success" to
     * FAILED *before* any plan grant, so the app owner is never charged a free subscription for
     * a transfer that did not actually move airtime.
     *
     * Kept SEPARATE from the verbatim Hybrid classifiers above (which must not change). It reuses
     * [isInsufficientBalance] (covers "insufficient account balance …", observed live) and adds the
     * second wording Safaricom uses on low balance ("… balance is too low … recharge your account").
     *
     * Deliberately specific to failure: a genuine transfer confirmation
     * ("You have transferred 30.00 KSH … Your account balance is : 6.42 KSH …") contains none of
     * "insufficient", "too low", or "recharge your account", so it is never demoted.
     */
    fun isSambazaFailure(response: String): Boolean =
        isInsufficientBalance(response) ||
        response.contains("too low", ignoreCase = true) ||
        response.contains("recharge your account", ignoreCase = true)
}