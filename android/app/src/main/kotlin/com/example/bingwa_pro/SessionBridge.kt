// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SessionBridge.kt
package com.example.bingwa_pro

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * W3.E / D-W3-19 (Option B — native session bridge).
 *
 * The background [ScheduleTransactionWorker] runs in the app process on a
 * background thread with NO Flutter engine attached, so it cannot read the
 * Dart-side token via flutter_secure_storage (that lives behind the Dart VM).
 * Instead, Dart MIRRORS the current session here on login and on every token
 * refresh (via the `bingwa_pro/session` MethodChannel → SessionBridgeService),
 * and the worker reads the *current* token each time it fires. Nothing stale
 * ever gets baked into a scheduled job.
 *
 * This same store is the reliability backbone the 24/7 token-refresh heartbeat
 * (W3.J) will reuse.
 *
 * STORAGE / SECURITY NOTE (flagged for review):
 *   Uses app-private SharedPreferences (MODE_PRIVATE) — sandboxed to this app.
 *   The mirrored value is a short-lived (~7-day) JWT access token. This is a
 *   second at-rest copy alongside the Dart Keystore-backed store. If you want
 *   the native mirror encrypted too, swap to EncryptedSharedPreferences
 *   (androidx.security:security-crypto) — one-line change in [prefs]. Left as
 *   plain MODE_PRIVATE to avoid adding the security-crypto dependency (which
 *   has had deprecation churn) unless you ask for it.
 */
object SessionBridge {
    private const val TAG = "SessionBridge"
    private const val PREFS_NAME = "bingwa_pro_session"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_BASE_URL = "base_url"
    private const val KEY_AGENT_ID = "agent_id"
    private const val KEY_PROCESSING_MODE = "processing_mode"
    private const val KEY_APP_STATE = "app_state"
    private const val KEY_PROCESS_MPESA = "process_mpesa_messages"
    // W4 — per-type message-processing toggles (Hybrid AppSetting PROCESS_TILL/SITE_LINK_MESSAGES).
    private const val KEY_PROCESS_TILL = "process_till_messages"
    private const val KEY_PROCESS_SITE_LINK = "process_site_link_messages"
    // W4 — agent-managed Authorized Senders (Hybrid authorized_senders table → on-device set).
    private const val KEY_AUTHORIZED_SENDERS = "authorized_senders"
    // W4-batch-4 — Auto-Save Contacts toggle (Hybrid AppSetting AUTO_SAVE_CONTACTS). Default OFF
    // (contact-writing is intrusive + needs a runtime permission, so it's opt-in).
    private const val KEY_AUTO_SAVE_CONTACTS = "auto_save_contacts"
    // W3.F — SIM routing (mirror of Hybrid's AppSetting SIM keys). Booleans.
    private const val KEY_DIAL_USSD_VIA_SIM2 = "dial_ussd_via_sim2"
    private const val KEY_SEND_SMS_VIA_SIM2 = "send_sms_via_sim2"
    private const val KEY_RECEIVE_PAYMENTS_VIA_SIM1 = "receive_payments_via_sim1"
    private const val KEY_RECEIVE_PAYMENTS_VIA_SIM2 = "receive_payments_via_sim2"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Called from Dart on login + on every token refresh. */
    fun save(context: Context, accessToken: String, baseUrl: String, agentId: String) {
        prefs(context).edit()
            .putString(KEY_ACCESS_TOKEN, accessToken)
            .putString(KEY_BASE_URL, baseUrl)
            .putString(KEY_AGENT_ID, agentId)
            .apply()
        Log.d(TAG, "Session mirrored to native (agentId=$agentId, baseUrl=$baseUrl, tokenLen=${accessToken.length})")
    }

    fun getToken(context: Context): String? = prefs(context).getString(KEY_ACCESS_TOKEN, null)

    fun getBaseUrl(context: Context): String? = prefs(context).getString(KEY_BASE_URL, null)

    fun getAgentId(context: Context): String? = prefs(context).getString(KEY_AGENT_ID, null)

    // ── W3.C: processing mode (Express vs Advanced) ───────────────────────────────────
    // The agent's processing mode lives on the backend wallet (wallet.processingMode) and in
    // Hybrid is a DataStore-backed StateFlow on SettingsRepository. We mirror it into this
    // same native store (D-W3-19 pattern) so the dial path (UssdExecutionService) and the
    // UssdAccessibilityService can read it WITHOUT a Flutter engine or a network call.
    //
    // Stored lowercase: "express" | "advanced". Defaults to "express" until W3.I wires the
    // processing-mode radio + wallet sync to call saveProcessingMode — so until then every
    // dial stays Express, identical to today's behavior. Dialing is mode-driven; only
    // SUBSCRIPTION_RENEWAL/balance checks force Express regardless (handled at the call site).

    /** Called from Dart (W3.I) when the processing-mode radio changes / wallet syncs. */
    fun saveProcessingMode(context: Context, mode: String) {
        prefs(context).edit().putString(KEY_PROCESSING_MODE, mode.lowercase()).apply()
        Log.d(TAG, "Processing mode mirrored to native: $mode")
    }

    fun getProcessingMode(context: Context): String =
        prefs(context).getString(KEY_PROCESSING_MODE, "express") ?: "express"

    // ── W3.K: AppState (the master on/off) + Process-M-Pesa toggle ────────────────────
    // Two AND-ed gates decide whether an incoming M-Pesa SMS is auto-processed, exactly
    // as in Hybrid:
    //   1. appState == "running"  — the engine's master switch. Hybrid's SmsBroadcastReceiver
    //      ignores everything unless AppState != STOPPED, and only DIALS when RUNNING. A fresh
    //      install starts STOPPED, so nothing auto-dials until the agent presses play. W3.K only
    //      READS this; the dashboard play/pause/stop that WRITES it is W3.N. Default "stopped".
    //   2. processMpesa == true   — the "Process M-Pesa Messages" settings toggle. Hybrid seeds
    //      this ON (acting on M-Pesa texts is the whole point); it's safe to default ON because
    //      gate #1 is STOPPED until play. Default true (Hybrid parity).
    // Stored lowercase for appState: "stopped" | "running" | "paused".

    /** W3.N writes this via the dashboard control; W3.K reads it in the SMS receiver. */
    fun saveAppState(context: Context, state: String) {
        prefs(context).edit().putString(KEY_APP_STATE, state.lowercase()).apply()
        Log.d(TAG, "App state mirrored to native: $state")
    }

    fun getAppState(context: Context): String =
        prefs(context).getString(KEY_APP_STATE, "stopped") ?: "stopped"

    /** Called from Dart when the "Process M-Pesa Messages" toggle changes / settings sync. */
    fun saveProcessMpesa(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_PROCESS_MPESA, enabled).apply()
        Log.d(TAG, "Process-M-Pesa mirrored to native: $enabled")
    }

    fun getProcessMpesa(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PROCESS_MPESA, true)

    // ── W4: Process-Till / Process-SiteLink toggles ───────────────────────────────────
    // Till/Buy-Goods confirmations arrive from the same M-Pesa sender, so Till defaults ON
    // (parity with M-Pesa — till payments are a core sale path). SiteLink (BHSL) SMS only
    // exist once the W5 SiteLink store is live, so SiteLink defaults OFF (D-W4-1: the parser
    // ships now but stays inert until W5). Both are AND-ed with AppState==running like M-Pesa.

    fun saveProcessTill(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_PROCESS_TILL, enabled).apply()
        Log.d(TAG, "Process-Till mirrored to native: $enabled")
    }
    fun getProcessTill(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PROCESS_TILL, true)

    fun saveProcessSiteLink(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_PROCESS_SITE_LINK, enabled).apply()
        Log.d(TAG, "Process-SiteLink mirrored to native: $enabled")
    }
    fun getProcessSiteLink(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PROCESS_SITE_LINK, false)

    // ── W4: Authorized Senders (agent-managed; Hybrid checkValidSender extension) ──────
    // EXTENDS the built-in sender fence (MPESA/40400/40401) so the agent can authorise extra
    // senders whose payment SMS should be processed. Stored as a StringSet; the SMS receiver
    // reads it. SharedPreferences StringSet must be written as a fresh set (never mutated in
    // place), so each mutation copies, edits, and puts back.

    fun getAuthorizedSenders(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_AUTHORIZED_SENDERS, emptySet())?.toSet() ?: emptySet()

    /** Add a sender; returns true if newly added, false if blank or already present. */
    fun addAuthorizedSender(context: Context, sender: String): Boolean {
        val s = sender.trim()
        if (s.isEmpty()) return false
        val current = getAuthorizedSenders(context).toMutableSet()
        val added = current.add(s)
        if (added) prefs(context).edit().putStringSet(KEY_AUTHORIZED_SENDERS, current).apply()
        Log.d(TAG, "Authorized sender add '$s' -> added=$added (count=${current.size})")
        return added
    }

    fun removeAuthorizedSender(context: Context, sender: String) {
        val current = getAuthorizedSenders(context).toMutableSet()
        if (current.remove(sender)) {
            prefs(context).edit().putStringSet(KEY_AUTHORIZED_SENDERS, current).apply()
        }
        Log.d(TAG, "Authorized sender removed '$sender' (count=${current.size})")
    }

    // ── W4-batch-4: Auto-Save Contacts toggle ──────────────────────────────────────────
    fun saveAutoSaveContacts(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_AUTO_SAVE_CONTACTS, enabled).apply()
        Log.d(TAG, "Auto-save-contacts mirrored to native: $enabled")
    }
    fun getAutoSaveContacts(context: Context): Boolean =
        prefs(context).getBoolean(KEY_AUTO_SAVE_CONTACTS, false)

    // ── W3.F: SIM routing (Hybrid AppSetting parity) ──────────────────────────────────
    // Five booleans the native dial/SMS paths read via SimSubscriptionResolver. Dart's
    // SIM-setup screen mirrors them here. Defaults match a fresh single-SIM Hybrid install:
    // dial via SIM 1 (via2=false), reply via SIM 1 (via2=false), receive on SIM 1 (true) /
    // SIM 2 (false). On a single-SIM device these resolve to the one SIM.

    fun saveDialUssdViaSim2(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_DIAL_USSD_VIA_SIM2, enabled).apply()
        Log.d(TAG, "Dial-USSD-via-SIM2 mirrored: $enabled")
    }
    fun getDialUssdViaSim2(context: Context): Boolean =
        prefs(context).getBoolean(KEY_DIAL_USSD_VIA_SIM2, false)

    fun saveSendSmsViaSim2(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_SEND_SMS_VIA_SIM2, enabled).apply()
        Log.d(TAG, "Send-SMS-via-SIM2 mirrored: $enabled")
    }
    fun getSendSmsViaSim2(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SEND_SMS_VIA_SIM2, false)

    fun saveReceivePaymentsViaSim1(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_RECEIVE_PAYMENTS_VIA_SIM1, enabled).apply()
        Log.d(TAG, "Receive-payments-via-SIM1 mirrored: $enabled")
    }
    fun getReceivePaymentsViaSim1(context: Context): Boolean =
        prefs(context).getBoolean(KEY_RECEIVE_PAYMENTS_VIA_SIM1, true)

    fun saveReceivePaymentsViaSim2(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_RECEIVE_PAYMENTS_VIA_SIM2, enabled).apply()
        Log.d(TAG, "Receive-payments-via-SIM2 mirrored: $enabled")
    }
    fun getReceivePaymentsViaSim2(context: Context): Boolean =
        prefs(context).getBoolean(KEY_RECEIVE_PAYMENTS_VIA_SIM2, false)

    /** Called from Dart on logout / session invalidation. */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
        Log.d(TAG, "Session cleared from native store")
    }
}