// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdEngine.kt
package com.example.bingwa_pro

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class UssdEngine(private val context: Context) {
    private val TAG = "UssdEngine"
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // USSD Routes from CSV
    private val ussdRoutes = listOf(
        // SMS Bundles
        UssdRoute("20sms_valid_24hrs", "*188*10*1*1*@*1*2#", 500, "SMS", "ADVANCED"),
        UssdRoute("200sms_valid_24hrs", "*188*10*1*2*@*1*2#", 1000, "SMS", "ADVANCED"),
        UssdRoute("1000sms_valid_7days", "*188*10*2*2*@*1*2#", 3000, "SMS", "ADVANCED"),
        
        // DATA Bundles - EXPRESS
        UssdRoute("1gb_1hr", "*180*5*2*@*5*1#", 1900, "DATA", "EXPRESS"),
        UssdRoute("250mb_24hrs", "*180*5*2*@*6*1#", 2000, "DATA", "EXPRESS"),
        UssdRoute("350mb_7days", "*180*5*2*@*2*1#", 4700, "DATA", "EXPRESS"),
        UssdRoute("1_5gb_3hrs", "*180*5*2*@*1*1#", 4900, "DATA", "EXPRESS"),
        UssdRoute("1_5gb_3hrs_v2", "*180*5*2*@*1*1#", 5000, "DATA", "EXPRESS"),
        UssdRoute("1_25gb_midnight", "*180*5*2*@*8*1#", 5500, "DATA", "EXPRESS"),
        UssdRoute("1gb_24hrs", "*180*5*2*@*7*1#", 9900, "DATA", "EXPRESS"),
        
        // DATA Bundles - ADVANCED
        UssdRoute("1gb_1hr_many", "*544*98*13*3*2*@*1*1#", 2300, "DATA", "ADVANCED"),
        UssdRoute("1_5gb_3hrs_many", "*544*98*13*3*3*@*1*1#", 5300, "DATA", "ADVANCED"),
        UssdRoute("2gb_24hrs_many", "*544*98*13*3*1*@*1*1#", 11000, "DATA", "ADVANCED"),
        
        // MINUTES Bundles
        UssdRoute("350_flex", "*444*5*5*1*3*@*2*1#", 2100, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v2", "*444*5*5*1*3*@*2*1#", 2200, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v3", "*444*5*5*1*3*@*2*1#", 2400, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v4", "*444*5*5*1*3*@*2*1#", 2500, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v5", "*444*5*5*1*3*@*2*1#", 2600, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_midnight", "*444*5*7*7*3*@*2*1*1#", 5100, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_v1", "*444*5*7*7*3*@*2*1*1#", 5200, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_v3", "*444*5*7*7*3*@*2*1*1#", 5400, "MINUTES", "ADVANCED"),
    )
    
    fun findUssdRouteByPrice(priceCents: Int): UssdRoute? {
        return ussdRoutes.find { it.priceCents == priceCents }
    }
    
    fun buildUssdCode(route: UssdRoute, customerPhone: String): String {
        // Replace @ symbol with customer phone number
        var ussdCode = route.template
        ussdCode = ussdCode.replace("@", customerPhone)
        // Ensure it ends with #
        if (!ussdCode.endsWith("#")) {
            ussdCode += "#"
        }
        return ussdCode
    }
    
    suspend fun executeExpressUssd(ussdCode: String, phoneNumber: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Executing EXPRESS USSD: $ussdCode for $phoneNumber")
                
                // Format and encode the USSD code
                val finalCode = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
                val encodedCode = finalCode.replace("#", Uri.encode("#"))
                
                // Create intent to dial USSD code
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$encodedCode")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                
                // Start the USSD call
                withContext(Dispatchers.Main) {
                    context.startActivity(intent)
                }
                
                Log.d(TAG, "EXPRESS USSD executed: $finalCode")
                true
                
            } catch (e: Exception) {
                Log.e(TAG, "EXPRESS USSD failed: ${e.message}", e)
                false
            }
        }
    }
    
    suspend fun executeAdvancedUssd(ussdCode: String, phoneNumber: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Executing ADVANCED USSD: $ussdCode for $phoneNumber")
                
                // For advanced USSD, we need to handle multi-step menu navigation
                // This is more complex and will be handled by UssdAccessibilityService
                // For now, we'll use the same approach but with a flag
                val finalCode = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
                val encodedCode = finalCode.replace("#", Uri.encode("#"))
                
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$encodedCode")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                
                withContext(Dispatchers.Main) {
                    context.startActivity(intent)
                }
                
                Log.d(TAG, "ADVANCED USSD initiated: $finalCode")
                true
                
            } catch (e: Exception) {
                Log.e(TAG, "ADVANCED USSD failed: ${e.message}", e)
                false
            }
        }
    }
    
    fun cancelCurrentUssd() {
        // Cancel by sending home intent
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}

data class UssdRoute(
    val name: String,
    val template: String,
    val priceCents: Int,
    val category: String,
    val delivery: String
)