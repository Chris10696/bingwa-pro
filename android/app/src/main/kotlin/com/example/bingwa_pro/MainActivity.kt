package com.example.bingwa_pro

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "bingwa_pro/ussd"
    private val AIRTIME_CHANNEL = "bingwa_pro/airtime"
    private val SERVICE_CHANNEL = "bingwa_pro/service"
    private val TAG = "BingwaPro"
    private val PERMISSION_REQUEST_CODE = 1001

    // UssdEngine and AirtimeChecker are instantiated here because they are
    // plain helper classes, not Android components. MpesaMessageListener is
    // NOT instantiated here — it is a BroadcastReceiver managed entirely by
    // Android via the manifest declaration.
    private lateinit var ussdEngine: UssdEngine
    private lateinit var airtimeChecker: AirtimeChecker

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ussdEngine = UssdEngine(this)
        airtimeChecker = AirtimeChecker(this)

        requestAllPermissions()
        startUssdService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // USSD Execution Channel
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
                    "cancelUssd" -> cancelUssd(result)
                    else -> result.notImplemented()
                }
            }

        // Airtime Balance Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AIRTIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAirtimeBalance" -> checkAirtimeBalance(result)
                    else -> result.notImplemented()
                }
            }

        // Service Control Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        startUssdService()
                        result.success(true)
                    }
                    "stopService" -> {
                        stopUssdService()
                        result.success(true)
                    }
                    "isServiceRunning" -> result.success(UssdExecutionService.isRunning)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestAllPermissions() {
        val permissions = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.CALL_PHONE)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.READ_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.RECEIVE_SMS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun executeUssd(
        ussdCode: String,
        phoneNumber: String,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val success = ussdEngine.executeExpressUssd(ussdCode, phoneNumber)
            withContext(Dispatchers.Main) {
                if (success) {
                    result.success(mapOf("success" to true, "message" to "USSD executed successfully"))
                } else {
                    result.error("USSD_FAILED", "Failed to execute USSD", null)
                }
            }
        }
    }

    private fun executeAdvancedUssd(
        ussdCode: String,
        phoneNumber: String,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val success = ussdEngine.executeAdvancedUssd(ussdCode, phoneNumber)
            withContext(Dispatchers.Main) {
                if (success) {
                    result.success(mapOf("success" to true, "message" to "Advanced USSD executed successfully"))
                } else {
                    result.error("USSD_FAILED", "Failed to execute advanced USSD", null)
                }
            }
        }
    }

    private fun checkAirtimeBalance(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val balance = airtimeChecker.getAirtimeBalance()
            withContext(Dispatchers.Main) {
                result.success(
                    mapOf(
                        "success" to true,
                        "balance" to balance,
                        "message" to "Airtime balance retrieved"
                    )
                )
            }
        }
    }

    private fun cancelUssd(result: MethodChannel.Result) {
        ussdEngine.cancelCurrentUssd()
        result.success(mapOf("success" to true, "message" to "USSD cancelled"))
    }

    private fun startUssdService() {
        val serviceIntent = Intent(this, UssdExecutionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopUssdService() {
        stopService(Intent(this, UssdExecutionService::class.java))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = permissions.zip(grantResults.toTypedArray())
                .filter { it.second == PackageManager.PERMISSION_GRANTED }
                .map { it.first }
            Log.d(TAG, "Granted permissions: ${granted.joinToString()}")
            Toast.makeText(this, "Permissions granted. Bingwa Pro is ready.", Toast.LENGTH_LONG).show()
        }
    }
}