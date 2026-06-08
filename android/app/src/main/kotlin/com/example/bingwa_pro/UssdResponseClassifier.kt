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
}