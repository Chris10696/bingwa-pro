// android/app/src/main/kotlin/com/example/bingwa_pro/MainActivity.kt
package com.example.bingwa_pro

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.telephony.TelephonyManager
import android.content.Context
import android.Manifest
import android.content.pm.PackageManager
import android.provider.Settings
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "bingwa_pro/ussd"
    private val TAG = "USSD"
    private val PERMISSION_REQUEST_CODE = 1001
    private var pendingResult: Result? = null
    private var pendingUssdCode: String? = null

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
            Log.d(TAG, "Executing USSD: $ussdCode for phone: $phoneNumber")
            
            // Check if we have CALL_PHONE permission
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.CALL_PHONE
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                // Store for later use
                pendingResult = result
                pendingUssdCode = ussdCode
                
                // Request permission
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.CALL_PHONE),
                    PERMISSION_REQUEST_CODE
                )
                return
            }
            
            // Execute USSD
            performUssdCall(ussdCode, result)
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception: ${e.message}", e)
            result.error("SECURITY_ERROR", "CALL_PHONE permission not granted", null)
        } catch (e: Exception) {
            Log.e(TAG, "USSD execution failed: ${e.message}", e)
            result.error("USSD_ERROR", "Failed to execute USSD: ${e.message}", null)
        }
    }
    
    private fun performUssdCall(ussdCode: String, result: Result) {
        try {
            // Format USSD code properly
            var formattedCode = ussdCode.trim()
            
            // Remove any existing # at the end if present (we'll add it)
            if (formattedCode.endsWith("#")) {
                formattedCode = formattedCode.dropLast(1)
            }
            
            // Construct the full USSD code
            val finalCode = "$formattedCode#"
            
            // Encode the # symbol for URI
            val encodedCode = finalCode.replace("#", Uri.encode("#"))
            
            // Create intent to dial USSD code
            val intent = Intent(Intent.ACTION_CALL)
            intent.data = Uri.parse("tel:$encodedCode")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            // Start the USSD call
            startActivity(intent)
            
            Log.d(TAG, "USSD intent started for: $finalCode")
            
            // Show a toast to inform user
            Toast.makeText(
                this,
                "Dialing USSD code: $finalCode",
                Toast.LENGTH_SHORT
            ).show()
            
            result.success(mapOf(
                "success" to true,
                "message" to "USSD code dialed successfully",
                "ussdCode" to finalCode,
                "encodedCode" to encodedCode
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to perform USSD call: ${e.message}", e)
            result.error("CALL_FAILED", "Failed to dial USSD code: ${e.message}", null)
        }
    }
    
    private fun executeAdvancedUssd(ussdCode: String, phoneNumber: String, result: Result) {
        // For advanced mode, use the same approach
        // Multi-step USSD would require session management which is complex
        // The user can manually continue the USSD flow after the initial call
        executeUssd(ussdCode, phoneNumber, result)
    }
    
    private fun cancelUssd(result: Result) {
        // USSD cancellation - open phone app to end call
        try {
            val intent = Intent(Intent.ACTION_MAIN)
            intent.addCategory(Intent.CATEGORY_HOME)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            
            result.success(mapOf(
                "success" to true,
                "message" to "Returned to home screen. Press the end call button to cancel USSD."
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel USSD: ${e.message}", e)
            result.error("CANCEL_FAILED", "Could not cancel USSD", null)
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "CALL_PHONE permission granted")
                Toast.makeText(this, "Phone permission granted", Toast.LENGTH_SHORT).show()
                
                // Retry the pending USSD execution
                pendingResult?.let { result ->
                    pendingUssdCode?.let { code ->
                        performUssdCall(code, result)
                    }
                }
                pendingResult = null
                pendingUssdCode = null
            } else {
                Log.w(TAG, "CALL_PHONE permission denied")
                Toast.makeText(
                    this,
                    "Phone permission is required to dial USSD codes",
                    Toast.LENGTH_LONG
                ).show()
                
                pendingResult?.error("PERMISSION_DENIED", "CALL_PHONE permission required", null)
                pendingResult = null
                pendingUssdCode = null
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Check if permission was granted while app was in background
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.CALL_PHONE
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            // Permission granted, handle any pending request
            pendingResult?.let { result ->
                pendingUssdCode?.let { code ->
                    performUssdCall(code, result)
                }
            }
            pendingResult = null
            pendingUssdCode = null
        }
    }
}