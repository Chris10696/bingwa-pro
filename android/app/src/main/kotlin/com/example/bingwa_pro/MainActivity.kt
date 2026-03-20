// android/app/src/main/kotlin/com/example/bingwa_pro/MainActivity.kt
package com.example.bingwa_pro

import android.os.Bundle
import android.telephony.TelephonyManager
import android.telephony.UssdResponseCallback
import android.telephony.PhoneStateListener
import android.telephony.ServiceState
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "bingwa_pro/ussd"
    private var currentUssdSession: UssdSession? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "executeUssd" -> {
                        val ussdCode = call.argument<String>("ussdCode") ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        executeUssd(ussdCode, phoneNumber, result)
                    }
                    "executeAdvancedUssd" -> {
                        val ussdCode = call.argument<String>("ussdCode") ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        executeAdvancedUssd(ussdCode, phoneNumber, result)
                    }
                    "cancelUssd" -> {
                        cancelUssd(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun executeUssd(ussdCode: String, phoneNumber: String, result: Result) {
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            
            // Check if we have permission
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                if (checkSelfPermission(android.Manifest.permission.CALL_PHONE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    result.error("PERMISSION_DENIED", "CALL_PHONE permission required", null)
                    return
                }
            }
            
            // Create callback for USSD response
            val callback = object : UssdResponseCallback() {
                override fun onReceiveUssdResponse(
                    telephonyManager: TelephonyManager?,
                    request: String?,
                    response: CharSequence?
                ) {
                    Handler(Looper.getMainLooper()).post {
                        result.success(mapOf(
                            "success" to true,
                            "response" to response?.toString()
                        ))
                    }
                }
                
                override fun onReceiveUssdResponseFailed(
                    telephonyManager: TelephonyManager?,
                    request: String?,
                    failureCode: Int
                ) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("USSD_FAILED", "USSD failed with code: $failureCode", null)
                    }
                }
            }
            
            // Execute USSD
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                telephonyManager.sendUssdRequest(ussdCode, callback, Executors.newSingleThreadExecutor())
            } else {
                // Fallback for older Android versions
                result.error("UNSUPPORTED", "Android version too old", null)
            }
            
        } catch (e: Exception) {
            result.error("USSD_ERROR", e.message, null)
        }
    }
    
    private fun executeAdvancedUssd(ussdCode: String, phoneNumber: String, result: Result) {
        // For advanced mode, we need to handle multi-step USSD
        // This would maintain session state across multiple requests
        currentUssdSession = UssdSession(ussdCode, phoneNumber)
        currentUssdSession?.executeNextStep(object : UssdCallback {
            override fun onSuccess(response: String) {
                result.success(mapOf(
                    "success" to true,
                    "response" to response
                ))
            }
            
            override fun onFailure(error: String) {
                result.error("USSD_FAILED", error, null)
            }
        })
    }
    
    private fun cancelUssd(result: Result) {
        currentUssdSession?.cancel()
        currentUssdSession = null
        result.success(mapOf("success" to true))
    }
}

// Helper class for advanced USSD sessions
class UssdSession(private val initialCode: String, private val phoneNumber: String) {
    private var currentStep = 0
    private val steps = mutableListOf<String>()
    private var callback: UssdCallback? = null
    
    fun executeNextStep(callback: UssdCallback) {
        this.callback = callback
        // Implementation would handle multi-step USSD flow
        // This is simplified - actual implementation would maintain session
        callback.onSuccess("USSD executed")
    }
    
    fun cancel() {
        // Cancel ongoing USSD session
    }
}

interface UssdCallback {
    fun onSuccess(response: String)
    fun onFailure(error: String)
}