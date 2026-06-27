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
import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.content.Context
import android.content.ComponentName
import android.text.TextUtils
class MainActivity : FlutterActivity() {
    private val CHANNEL         = "bingwa_pro/ussd"
    private val AIRTIME_CHANNEL = "bingwa_pro/airtime"
    private val SERVICE_CHANNEL = "bingwa_pro/service"
    // ─── Scheduling + session channels (W3.E) ─────────────────────────────────
    // scheduler: Dart arms/cancels a WorkManager one-shot when an auto-renewal is
    //            scheduled/cancelled. session: Dart mirrors {token, baseUrl, agentId}
    //            into the native store so the background worker can authenticate
    //            (D-W3-19 Option B).
    private val SCHEDULER_CHANNEL = "bingwa_pro/scheduler"
    private val SESSION_CHANNEL   = "bingwa_pro/session"
    // ─── W5.F.2: HybridConnect/Portal socket control ──────────────────────────
    // Dart (W5.F.3's "Hybrid Portal" toggle) starts/stops the socket foreground
    // service, passing the Connect ID it fetched from POST /hybrid-connect/generate.
    private val SOCKET_CHANNEL    = "bingwa_pro/socket"
    // ─── W5.H: in-app updater (download + install the APK) ────────────────────
    private val UPDATE_CHANNEL    = "bingwa_pro/update"
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
        AutoReplyTemplates.seedIfNeeded(applicationContext) // W3.M: seed default auto-replies
        requestAllPermissions()
        requestBatteryOptimizationExemption()
        requestOverlayPermission()
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

        // ── Scheduler Channel (W3.E) ────────────────────────────────────────
        // Dart arms a WorkManager one-shot when an auto-renewal is scheduled, and
        // cancels it when the schedule is cancelled. Keyed by transactionId.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCHEDULER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "armScheduled" -> {
                        val transactionId = call.argument<String>("transactionId")
                        // Dart sends epoch millis as an int; it may arrive as Int or Long.
                        val triggerAtMillis = (call.argument<Any>("triggerAtMillis") as? Number)?.toLong()
                        if (transactionId.isNullOrBlank() || triggerAtMillis == null) {
                            result.error("BAD_ARGS", "transactionId and triggerAtMillis are required", null)
                        } else {
                            WorkScheduler.arm(applicationContext, transactionId, triggerAtMillis)
                            result.success(true)
                        }
                    }
                    "cancelScheduled" -> {
                        val transactionId = call.argument<String>("transactionId")
                        if (transactionId.isNullOrBlank()) {
                            result.error("BAD_ARGS", "transactionId is required", null)
                        } else {
                            WorkScheduler.cancel(applicationContext, transactionId)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Session Bridge Channel (W3.E / D-W3-19 Option B) ────────────────
        // Dart mirrors the current session here on login + on every token refresh,
        // so the background worker can authenticate without a Flutter engine.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSession" -> {
                        val accessToken = call.argument<String>("accessToken")
                        val baseUrl     = call.argument<String>("baseUrl")
                        val agentId     = call.argument<String>("agentId")
                        if (accessToken.isNullOrBlank() || baseUrl.isNullOrBlank() || agentId == null) {
                            result.error("BAD_ARGS", "accessToken, baseUrl, agentId are required", null)
                        } else {
                            SessionBridge.save(applicationContext, accessToken, baseUrl, agentId)
                            // W3.J: begin the 24/7 session-validity heartbeat now that a
                            // session is mirrored (idempotent KEEP — safe on every login/launch).
                            WorkScheduler.scheduleSessionHeartbeat(applicationContext)
                            result.success(true)
                        }
                    }
                    "clearSession" -> {
                        SessionBridge.clear(applicationContext)
                        // W3.J: stop the heartbeat on logout.
                        WorkScheduler.cancelSessionHeartbeat(applicationContext)
                        result.success(true)
                    }
                    "saveProcessingMode" -> {
                        val mode = call.argument<String>("mode")
                        if (mode.isNullOrBlank()) {
                            result.error("BAD_ARGS", "mode is required", null)
                        } else {
                            SessionBridge.saveProcessingMode(applicationContext, mode)
                            result.success(true)
                        }
                    }
                    // ── W3.I: accessibility gate for Advanced mode ──────────────
                    // isAccessibilityEnabled lets Dart reconcile the wallet's mode
                    // (revert Advanced→Express if our service is off, matching
                    // Hybrid's postAccessibilityServiceStatus(false) behaviour).
                    // openAccessibilitySettings fires the system Accessibility
                    // settings intent (the "Open Accessibility Settings" button).
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_ACTIVITY", "Accessibility settings not available", null)
                        }
                    }
                    "saveProcessMpesa" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) {
                            result.error("BAD_ARGS", "enabled is required", null)
                        } else {
                            SessionBridge.saveProcessMpesa(applicationContext, enabled)
                            result.success(true)
                        }
                    }
                    // ── W4: Till / SiteLink processing toggles + getters (Settings load) ──
                    "saveProcessTill" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveProcessTill(applicationContext, enabled); result.success(true) }
                    }
                    "saveProcessSiteLink" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveProcessSiteLink(applicationContext, enabled); result.success(true) }
                    }
                    "getProcessMpesa" -> result.success(SessionBridge.getProcessMpesa(applicationContext))
                    "getProcessTill" -> result.success(SessionBridge.getProcessTill(applicationContext))
                    "getProcessSiteLink" -> result.success(SessionBridge.getProcessSiteLink(applicationContext))
                    // ── W4-batch-4: Auto-Save Contacts toggle ──
                    "saveAutoSaveContacts" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveAutoSaveContacts(applicationContext, enabled); result.success(true) }
                    }
                    "getAutoSaveContacts" -> result.success(SessionBridge.getAutoSaveContacts(applicationContext))
                    // ── W5.C/W5.D/W5.E: account-health mirror + EngageBot toggle + clock check ──
                    "saveAccountHealthy" -> {
                        val healthy = call.argument<Boolean>("healthy")
                        if (healthy == null) result.error("BAD_ARGS", "healthy is required", null)
                        else { SessionBridge.saveAccountHealthy(applicationContext, healthy); result.success(true) }
                    }
                    "saveEngageBot" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveEngageBot(applicationContext, enabled); result.success(true) }
                    }
                    "getEngageBot" -> result.success(SessionBridge.getEngageBot(applicationContext))
                    "isAutoTimeEnabled" -> result.success(DeviceTimeCheck.isAutoTimeEnabled(applicationContext))
                    // ── W4-batch-5: Auto-Reply template edit surface ──
                    "getAutoReplies" -> {
                        val list = AutoReplyTemplates.AutoReplyType.values().map { t ->
                            mapOf(
                                "type" to t.name,
                                "message" to AutoReplyTemplates.template(applicationContext, t),
                                "isActive" to AutoReplyTemplates.isActive(applicationContext, t),
                            )
                        }
                        result.success(list)
                    }
                    "saveAutoReply" -> {
                        val typeName = call.argument<String>("type")
                        val message = call.argument<String>("message")
                        val isActive = call.argument<Boolean>("isActive")
                        val type = typeName?.let {
                            runCatching { AutoReplyTemplates.AutoReplyType.valueOf(it) }.getOrNull()
                        }
                        if (type == null || message == null || isActive == null) {
                            result.error("BAD_ARGS", "type/message/isActive required", null)
                        } else {
                            AutoReplyTemplates.setMessage(applicationContext, type, message)
                            AutoReplyTemplates.setActive(applicationContext, type, isActive)
                            result.success(true)
                        }
                    }
                    // ── W4: Authorized Senders (agent-managed allowlist) ──
                    "getAuthorizedSenders" ->
                        result.success(SessionBridge.getAuthorizedSenders(applicationContext).toList())
                    "addAuthorizedSender" -> {
                        val sender = call.argument<String>("sender")
                        if (sender.isNullOrBlank()) result.error("BAD_ARGS", "sender is required", null)
                        else result.success(SessionBridge.addAuthorizedSender(applicationContext, sender))
                    }
                    "removeAuthorizedSender" -> {
                        val sender = call.argument<String>("sender")
                        if (sender.isNullOrBlank()) result.error("BAD_ARGS", "sender is required", null)
                        else { SessionBridge.removeAuthorizedSender(applicationContext, sender); result.success(true) }
                    }
                    "saveAppState" -> {
                        val state = call.argument<String>("state")
                        if (state.isNullOrBlank()) {
                            result.error("BAD_ARGS", "state is required", null)
                        } else {
                            SessionBridge.saveAppState(applicationContext, state)
                            result.success(true)
                        }
                    }
                    // ── W3.F: SIM routing setters + active-SIM info ─────────────
                    "saveDialUssdViaSim2" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveDialUssdViaSim2(applicationContext, enabled); result.success(true) }
                    }
                    "saveSendSmsViaSim2" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveSendSmsViaSim2(applicationContext, enabled); result.success(true) }
                    }
                    "saveReceivePaymentsViaSim1" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveReceivePaymentsViaSim1(applicationContext, enabled); result.success(true) }
                    }
                    "saveReceivePaymentsViaSim2" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled == null) result.error("BAD_ARGS", "enabled is required", null)
                        else { SessionBridge.saveReceivePaymentsViaSim2(applicationContext, enabled); result.success(true) }
                    }
                    "getSimInfo" -> {
                        val sims = SimSubscriptionResolver.getSimInfo(applicationContext)
                        result.success(sims.map { mapOf("slot" to it.slot, "label" to it.label) })
                    }
                    "getDialUssdViaSim2" -> result.success(SessionBridge.getDialUssdViaSim2(applicationContext))
                    "getSendSmsViaSim2" -> result.success(SessionBridge.getSendSmsViaSim2(applicationContext))
                    "getReceivePaymentsViaSim1" -> result.success(SessionBridge.getReceivePaymentsViaSim1(applicationContext))
                    "getReceivePaymentsViaSim2" -> result.success(SessionBridge.getReceivePaymentsViaSim2(applicationContext))
                    // ── W3.L: enqueue a Quick Dial into the real pipeline ───────
                    // The Dart provider has already created the SCHEDULED txn on the
                    // backend; here we build a DialRequest from its fields (token/baseUrl
                    // from SessionBridge, like SmsCreatePoster) and enqueue it into
                    // UssdExecutionService — identical pipeline to SMS/scheduled dials.
                    "enqueueQuickDial" -> {
                        val transactionId = call.argument<String>("transactionId")
                        val ussdCode = call.argument<String>("ussdCode")
                        // customerPhone is OPTIONAL. A blank value is a valid sentinel meaning
                        // "self-contained dial, no auto-reply" — used by pay-with-airtime, whose
                        // Sambaza code (*140*amount*adminNumber#) already carries its recipient and
                        // must NOT auto-reply. Quick Dial always passes a real, UI-validated number.
                        // Only transactionId + ussdCode are truly required.
                        val customerPhone = call.argument<String>("customerPhone") ?: ""
                        if (transactionId.isNullOrBlank() || ussdCode.isNullOrBlank()) {
                            result.error("BAD_ARGS", "transactionId and ussdCode are required", null)
                        } else {
                            val token = SessionBridge.getToken(applicationContext)
                            val baseUrl = SessionBridge.getBaseUrl(applicationContext)
                            if (token.isNullOrBlank() || baseUrl.isNullOrBlank()) {
                                result.error("NO_SESSION", "No mirrored session (token/baseUrl) for the pipeline", null)
                            } else {
                                val offerId = call.argument<String>("offerId")
                                val offerName = call.argument<String>("offerName")
                                val amount = call.argument<Int>("amount")
                                val offerPrice = call.argument<Int>("offerPrice") ?: amount
                                val request = DialRequest(
                                    transactionId = transactionId,
                                    ussdTemplate = ussdCode,
                                    customerPhone = customerPhone,
                                    amount = amount,
                                    isRecurringRenewal = false,
                                    daysRemaining = 0,
                                    offerId = offerId,
                                    triggerAtMillis = System.currentTimeMillis(),
                                    token = token,
                                    baseUrl = baseUrl,
                                    externalRetries = 0,
                                    // Quick Dial has no M-Pesa sender → no customerName/mpesaCode.
                                    // offerName/offerPrice feed the W3.M SUCCESS auto-reply.
                                    customerName = null,
                                    mpesaCode = null,
                                    offerName = offerName,
                                    offerPrice = offerPrice,
                                )
                                UssdExecutionService.enqueue(applicationContext, request)
                                result.success(true)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Socket Control Channel (W5.F.2) ─────────────────────────────────
        // Starts/stops SocketForegroundService for HybridConnect/Portal. The Connect
        // ID comes from Dart (fetched via the backend); native just owns the socket.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOCKET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSocket" -> {
                        val connectId = call.argument<String>("connectId")
                        if (connectId.isNullOrBlank()) {
                            result.error("BAD_ARGS", "connectId is required", null)
                        } else {
                            SocketForegroundService.start(applicationContext, connectId)
                            result.success(true)
                        }
                    }
                    "stopSocket" -> {
                        SocketForegroundService.stop(applicationContext)
                        result.success(true)
                    }
                    "isSocketConnected" -> result.success(SocketService.isConnected())
                    else -> result.notImplemented()
                }
            }

        // ── App Update Channel (W5.H) ───────────────────────────────────────
        // Dart's CheckForUpdates screen gates on the install permission then asks
        // native to download + install the APK the version endpoint advertises.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallUnknownSources" ->
                        result.success(AppUpdateInstaller.canInstallUnknownSources(applicationContext))
                    "openInstallSettings" -> {
                        AppUpdateInstaller.openInstallSettings(this)
                        result.success(true)
                    }
                    "downloadAndInstall" -> {
                        val apkUrl = call.argument<String>("apkUrl")
                        if (apkUrl.isNullOrBlank()) {
                            result.error("BAD_ARGS", "apkUrl is required", null)
                        } else {
                            AppUpdateInstaller.downloadAndInstall(applicationContext, apkUrl)
                            result.success(true)
                        }
                    }
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
    // ── Test injection implementation (W3.K) ─────────────────────────────────
    //
    // Builds an SMS body matching Hybrid's M-Pesa shape ("received Ksh…"), parses
    // it with the SAME MpesaSmsParser the receiver uses, posts to /sms-create, and
    // — on a matched 201 — enqueues into UssdExecutionService (the real pipeline).
    //
    // This deliberately BYPASSES the AppState + Process-M-Pesa gates (it IS the test
    // trigger), but it goes through the real backend create + dial decision, so it
    // exercises the genuine W3.K path end-to-end. The dryRun flag flows into the
    // dialer via the service the same way a real dial would; here we just drive the
    // create+enqueue and report the outcome.
    //
    // tillNumber is retained in the signature for channel back-compat but is no
    // longer part of the M-Pesa body (M-Pesa "received from <name> <phone>" has no
    // till; Buy-Goods/Till parsing is W4).
    private fun injectTestPayment(
        amount:          String,
        customerPhone:   String,
        tillNumber:      String,
        transactionId:   String,
        dryRun:          Boolean,
        result:          MethodChannel.Result
    ) {
        Log.d(TAG, "=== TEST INJECTION STARTED (W3.K) ===")
        Log.d(TAG, "Amount: KES $amount | Customer: $customerPhone | DryRun: $dryRun")
        // Safaricom-shaped M-Pesa confirmation: leading token = M-Pesa code (^\S+),
        // "received Ksh<amount>" triggers detection, "from <name> <10-digit phone>".
        val fakeBody = "$transactionId Confirmed. Ksh$amount.00 received from TEST USER " +
                "$customerPhone on 21/4/26 at 12:00 PM. New M-PESA balance is Ksh500.00."
        Log.d(TAG, "Injected SMS body:\n$fakeBody")
        CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
            try {
                val parsed = MpesaSmsParser.parse(fakeBody)
                if (parsed == null) {
                    withContext(Dispatchers.Main) {
                        result.success(
                            mapOf(
                                "success" to false,
                                "message" to "Test body did not parse (check format).",
                                "fakeBody" to fakeBody,
                            ),
                        )
                    }
                    return@launch
                }
                val outcome = SmsCreatePoster.createAndDecide(applicationContext, parsed)
                val msg = when (outcome) {
                    is SmsCreatePoster.SmsCreateOutcome.Dial -> {
                        UssdExecutionService.enqueue(applicationContext, outcome.request)
                        "Matched → enqueued txn ${outcome.request.transactionId} for dialing."
                    }
                    is SmsCreatePoster.SmsCreateOutcome.DoNotDial ->
                        "Not dialed: ${outcome.reason}"
                }
                withContext(Dispatchers.Main) {
                    result.success(
                        mapOf(
                            "success" to true,
                            "message" to "Test payment injected (dryRun=$dryRun). $msg",
                            "fakeBody" to fakeBody,
                        ),
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
            Toast.makeText(this, "Permissions granted. Bingwa Nexus is ready.", Toast.LENGTH_LONG).show()
        }
    }
        /**
    * Prompts the user to exempt Bingwa Nexus from battery optimization. Without
    * this, Android's Doze mode will silently kill our foreground service after
    * the screen has been off for an extended period, breaking 24/7 USSD
    * monitoring.
    *
    * The Intent opens system settings; the user has to tap "Allow" themselves.
    * Safe to call repeatedly — system shows nothing if already granted.
    */
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) {
            Log.d(TAG, "Battery optimization already exempted")
            return
        }
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "Battery optimization settings not available on this device", e)
        }
    }

    /**
     * W3.D bring-up: SYSTEM_ALERT_WINDOW ("Display over other apps") is the documented
     * background-activity-start exemption that lets an SMS-triggered dial launch the
     * system dialer (ACTION_CALL) while the app is backgrounded — the same exemption
     * Hybrid declares. The Intent opens system settings; the user taps "Allow". Safe to
     * call repeatedly — returns immediately once granted.
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (Settings.canDrawOverlays(this)) {
            Log.d(TAG, "Overlay (SYSTEM_ALERT_WINDOW) already granted")
            return
        }
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "Overlay permission settings not available on this device", e)
        }
    }

    /**
     * W3.I: returns true iff our UssdAccessibilityService is currently enabled in
     * the system's accessibility settings. Canonical implementation — parse
     * Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES (a ':'-separated list of
     * flattened ComponentNames) and match our component exactly. Reliable across
     * OEM skins (some report ids differently via AccessibilityManager, but the
     * Secure-settings component list is consistent).
     *
     * Dart uses this to reconcile the wallet's processing mode: if the wallet says
     * Advanced but this returns false, the mode is reverted to Express — the same
     * net effect as Hybrid's postAccessibilityServiceStatus(false) → EXPRESS.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, UssdAccessibilityService::class.java)
        val flat = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(flat)
        while (splitter.hasNext()) {
            val component = ComponentName.unflattenFromString(splitter.next())
            if (component != null && component == expected) return true
        }
        return false
    }
}