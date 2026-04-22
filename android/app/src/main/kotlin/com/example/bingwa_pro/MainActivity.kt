// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\MainActivity.kt
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

    private val CHANNEL         = "bingwa_pro/ussd"
    private val AIRTIME_CHANNEL = "bingwa_pro/airtime"
    private val SERVICE_CHANNEL = "bingwa_pro/service"

    // ─── Test injection channel ──────────────────────────────────────────────
    // Used only during development. Flutter calls "injectTestPayment" with a
    // fake M-PESA message body so the entire SMS → parse → route-match → USSD
    // chain can be exercised without a real till number, real money, or real
    // airtime.
    //
    // REMOVE THIS ENTIRE BLOCK BEFORE PUBLISHING TO GOOGLE PLAY.
    private val TEST_CHANNEL    = "bingwa_pro/test"
    // ─────────────────────────────────────────────────────────────────────────

    private val TAG = "BingwaPro"
    private val PERMISSION_REQUEST_CODE = 1001

    // UssdEngine and AirtimeChecker are plain helper classes, not Android
    // components, so they are instantiated here. MpesaMessageListener is a
    // BroadcastReceiver managed entirely by Android via the manifest.
    private lateinit var ussdEngine:     UssdEngine
    private lateinit var airtimeChecker: AirtimeChecker

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ussdEngine     = UssdEngine(this)
        airtimeChecker = AirtimeChecker(this)
        requestAllPermissions()
        startUssdService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── USSD Execution Channel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "executeUssd" -> {
                        val ussdCode    = call.argument<String>("ussdCode")    ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        executeUssd(ussdCode, phoneNumber, result)
                    }
                    "executeAdvancedUssd" -> {
                        val ussdCode    = call.argument<String>("ussdCode")    ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        executeAdvancedUssd(ussdCode, phoneNumber, result)
                    }
                    "cancelUssd" -> cancelUssd(result)
                    else -> result.notImplemented()
                }
            }

        // ── Airtime Balance Channel ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AIRTIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAirtimeBalance" -> checkAirtimeBalance(result)
                    else -> result.notImplemented()
                }
            }

        // ── Service Control Channel ─────────────────────────────────────────
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

        // ── TEST INJECTION CHANNEL (debug builds only) ──────────────────────
        // Remove this entire block before publishing to Google Play.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TEST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "injectTestPayment" -> {
                        val amount   = call.argument<String>("amount")        ?: "20"
                        val customer = call.argument<String>("customerPhone") ?: "0712345678"
                        val till     = call.argument<String>("tillNumber")    ?: "600584"
                        val txId     = call.argument<String>("transactionId") ?: "TESTAA0001"
                        val dryRun   = call.argument<Boolean>("dryRun")       ?: true
                        injectTestPayment(amount, customer, till, txId, dryRun, result)
                    }
                    else -> result.notImplemented()
                }
            }
        // ────────────────────────────────────────────────────────────────────
    }

    // ── Test injection implementation ────────────────────────────────────────
    //
    // Builds an SMS body that exactly matches the regex in UssdEngine, then
    // hands it directly to UssdEngine.processPaymentSms().
    //
    // dryRun = true  → logs the USSD code that would be dialled but does NOT
    //                  open the dialler. Safe with zero airtime.
    // dryRun = false → actually dials. Requires CALL_PHONE permission + airtime.
    //
    private fun injectTestPayment(
        amount:          String,
        customerPhone:   String,
        tillNumber:      String,
        transactionId:   String,
        dryRun:          Boolean,
        result:          MethodChannel.Result
    ) {
        Log.d(TAG, "=== TEST INJECTION STARTED ===")
        Log.d(TAG, "Amount: KES $amount | Customer: $customerPhone | Till: $tillNumber | DryRun: $dryRun")

        // Build a fake SMS body that mirrors a real Safaricom till payment confirmation.
        val fakeBody = "$transactionId Confirmed.\n" +
                "KES$amount.00 received from TEST USER $customerPhone on " +
                "21/4/26 at 12:00 PM.\n" +
                "New till number balance KES500.00.\n" +
                "Buy goods till $tillNumber."

        Log.d(TAG, "Injected SMS body:\n$fakeBody")

        CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
            try {
                val engine = UssdEngine(applicationContext, dryRun = dryRun)
                engine.processPaymentSms(fakeBody)

                withContext(Dispatchers.Main) {
                    result.success(
                        mapOf(
                            "success"  to true,
                            "message"  to "Test payment injected (dryRun=$dryRun). Check Logcat for details.",
                            "fakeBody" to fakeBody
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Test injection failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("INJECTION_FAILED", e.message, null)
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    private fun requestAllPermissions() {
        val permissions = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED)
            permissions.add(Manifest.permission.CALL_PHONE)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED)
            permissions.add(Manifest.permission.READ_SMS)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS)
            != PackageManager.PERMISSION_GRANTED)
            permissions.add(Manifest.permission.RECEIVE_SMS)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED)
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun executeUssd(ussdCode: String, phoneNumber: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val success = ussdEngine.executeExpressUssd(ussdCode, phoneNumber)
            withContext(Dispatchers.Main) {
                if (success)
                    result.success(mapOf("success" to true, "message" to "USSD executed successfully"))
                else
                    result.error("USSD_FAILED", "Failed to execute USSD", null)
            }
        }
    }

    private fun executeAdvancedUssd(ussdCode: String, phoneNumber: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            val success = ussdEngine.executeAdvancedUssd(ussdCode, phoneNumber)
            withContext(Dispatchers.Main) {
                if (success)
                    result.success(mapOf("success" to true, "message" to "Advanced USSD executed successfully"))
                else
                    result.error("USSD_FAILED", "Failed to execute advanced USSD", null)
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            startForegroundService(serviceIntent)
        else
            startService(serviceIntent)
    }

    private fun stopUssdService() {
        stopService(Intent(this, UssdExecutionService::class.java))
    }

    override fun onRequestPermissionsResult(
        requestCode:  Int,
        permissions:  Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = permissions.zip(grantResults.toTypedArray())
                .filter  { it.second == PackageManager.PERMISSION_GRANTED }
                .map     { it.first }
            Log.d(TAG, "Granted permissions: ${granted.joinToString()}")
            Toast.makeText(this, "Permissions granted. Bingwa Pro is ready.", Toast.LENGTH_LONG).show()
        }
    }
}