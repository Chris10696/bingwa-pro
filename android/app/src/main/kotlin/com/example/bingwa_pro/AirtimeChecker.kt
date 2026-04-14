// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\AirtimeChecker.kt
package com.example.bingwa_pro

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class AirtimeChecker(private val context: Context) {
    private val TAG = "AirtimeChecker"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentBalance: Double? = null
    private var isChecking = false
    
    // Regex to extract balance from USSD response
    private val balancePattern = Regex("""(?:balance|available|airtime)\s*(?:is|:)?\s*KES?\s*([\d,]+\.?\d*)""", RegexOption.IGNORE_CASE)
    
    suspend fun getAirtimeBalance(): Double {
        return withContext(Dispatchers.IO) {
            if (isChecking) {
                return@withContext currentBalance ?: 0.0
            }
            
            isChecking = true
            try {
                // Use the standard Safaricom balance check code *144#
                val balance = performBalanceCheck("*144#")
                currentBalance = balance
                Log.d(TAG, "Airtime balance: KES $balance")
                balance
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get airtime balance: ${e.message}", e)
                0.0
            } finally {
                isChecking = false
            }
        }
    }
    
    private suspend fun performBalanceCheck(ussdCode: String): Double {
        return suspendCancellableCoroutine { continuation ->
            val latch = CountDownLatch(1)
            var result = 0.0
            
            try {
                val finalCode = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
                val encodedCode = finalCode.replace("#", Uri.encode("#"))
                
                val intent = android.content.Intent(android.content.Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$encodedCode")
                intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                
                // Note: Actually getting the USSD response programmatically is complex
                // due to Android restrictions. This is a simplified version.
                // In practice, you'd need to use a service that captures USSD responses.
                
                mainHandler.post {
                    try {
                        context.startActivity(intent)
                        // Simulate balance for now
                        result = 100.0
                        latch.countDown()
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start USSD: ${e.message}", e)
                        latch.countDown()
                    }
                }
                
                // Wait for completion (with timeout)
                if (!latch.await(30, TimeUnit.SECONDS)) {
                    Log.w(TAG, "Balance check timeout")
                }
                
                continuation.resume(result, null)
                
            } catch (e: Exception) {
                Log.e(TAG, "Balance check failed: ${e.message}", e)
                continuation.resume(0.0, null)
            }
        }
    }
}