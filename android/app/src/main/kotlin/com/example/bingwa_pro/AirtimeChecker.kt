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
 * NOTE: the exact Safaricom *144# response wording isn't in the spec, so the parse
 * below is deliberately tolerant. It is one of the explicitly-deferred live tests —
 * tune `balancePattern` against a real device response (watch adb logcat for the
 * "Airtime *144# response" line).
 */
class AirtimeChecker(private val context: Context) {
    private val TAG = "AirtimeChecker"
    private var currentBalance: Double? = null
    private var isChecking = false

    // Tolerant: matches "...Ksh 123.45..." / "...KES 123..." / "balance is 123.45".
    private val balancePattern = Regex(
        """(?:Ksh|KES|balance(?:\s+is)?)[^\d-]*([\d,]+(?:\.\d+)?)""",
        RegexOption.IGNORE_CASE
    )

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