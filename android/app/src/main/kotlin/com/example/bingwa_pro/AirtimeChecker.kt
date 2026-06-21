// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\AirtimeChecker.kt
package com.example.bingwa_pro
import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * W3.B rider — real airtime balance via *144#.
 *
 * Hybrid's BalanceRepositoryImpl dials *144# through the SAME sendUssdRequest +
 * response-callback mechanism as Express, then parses the balance out of the
 * response. So this is now a thin parser over UssdEngine.dialExpressCapturing
 * (the W3.B capturing dial), replacing the old hardcoded 100.0.
 *
 * The balance is extracted with Hybrid's exact regex ("Airtime Bal: <n>KSH"), ported
 * verbatim from BalanceRepositoryImpl. If a value still looks wrong on a given line,
 * capture the raw reply (this logs "Airtime *144# response: ..." to logcat) — any
 * remaining gap is then in Safaricom's wording, not the parse.
 */
class AirtimeChecker(private val context: Context) {
    private val TAG = "AirtimeChecker"
    private var currentBalance: Double? = null
    private var isChecking = false

    // Verbatim port of Hybrid's BalanceRepositoryImpl.extractAirtimeBalance:
    //     Regex("Airtime Bal:\\s*([0-9]+\\.?[0-9]*)KSH")
    // Anchored on Safaricom's exact "Airtime Bal: <n>KSH" line, so a multi-line *144#
    // reply (Okoa Jahazi advance, Bonga points, promos) can't make the parse grab the
    // wrong figure. The previous loose pattern matched the FIRST money-number anywhere,
    // which surfaced the Okoa/promo amount (e.g. 23.00) or, on a layout it didn't match,
    // nothing → 0.00. Case-sensitive, to match Hybrid exactly.
    private val balancePattern = Regex("""Airtime Bal:\s*([0-9]+\.?[0-9]*)KSH""")

    suspend fun getAirtimeBalance(): Double = withContext(Dispatchers.IO) {
        if (isChecking) {
            return@withContext currentBalance ?: 0.0
        }
        isChecking = true
        try {
            val result = UssdEngine(context, dryRun = false).dialExpressCapturing("*144#", "")
            Log.d(TAG, "Airtime *144# response: ${result.response}")
            val parsed = result.response?.let { parseBalance(it) }
            if (parsed != null) {
                currentBalance = parsed
                Log.d(TAG, "Airtime balance: KES $parsed")
                parsed
            } else {
                Log.w(TAG, "Could not parse airtime balance — keeping last known")
                currentBalance ?: 0.0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get airtime balance: ${e.message}", e)
            0.0
        } finally {
            isChecking = false
        }
    }

    private fun parseBalance(response: String): Double? {
        val match = balancePattern.find(response) ?: return null
        return match.groupValues[1].replace(",", "").toDoubleOrNull()
    }
}