// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SocketService.kt
package com.example.bingwa_pro

import android.content.Context
import android.os.Build
import android.util.Log
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

/**
 * W5.F.2 — HybridConnect / Portal native socket client (port of Bingwa Hybrid's
 * SocketServiceImpl + AppRelay, rebranded to Nexus).
 *
 * The phone and the web Portal both join the same socket "room" (keyed by a Connect
 * ID the agent generates). Our NestJS gateway (W5.F.1) is a *dumb relay*: it forwards
 * every event phone→portal and portal→phone. So the event protocol lives here on the
 * client, exactly as in Hybrid — and we match Hybrid's event names + JSON payload shapes
 * verbatim so a Portal that speaks Hybrid's protocol interoperates unchanged.
 *
 * SCOPE (W5.F.2): the inbound master-switch relay (AppRelay) + presence + status.
 *   - app_state.set  → start/pause/stop the engine, then ack app_state.set.ack
 *   - app.status / app_state.sync → reply app.status.ack with the phone's current state
 *   - app.presence   → the gateway tells us how many portals are watching (logged)
 * The outbound data-sync relays (transactions/offers/airtime/kpis) are W5.F.2b — they
 * need data sources wired deliberately and are intentionally NOT in this batch.
 *
 * HANDSHAKE divergence from Hybrid (locked this session): Hybrid sends
 * clientType="BingwaHybrid". Our gateway routes the phone vs the portal on
 * clientType=="phone" (anything else = portal), so we send clientType="phone" and carry
 * the Nexus product identity in a separate appClient field the gateway ignores. The rest
 * of the auth map keeps Hybrid's shape (clientVersion/deviceModel/connectId/userId/token).
 *
 * APPSTATE bridge: Hybrid's wire values are STATE_RUNNING/STATE_PAUSED/STATE_STOPPED
 * (AppState.name()). Pro stores the engine's master switch in SessionBridge as the
 * lowercase "running"/"paused"/"stopped" the dashboard + SMS receiver already use, so we
 * translate at this boundary only — leaving the existing engine wiring untouched. Setting
 * the state is the *whole* action (matching Pro's local play/pause/stop, which likewise
 * only calls SessionBridge.saveAppState): the SMS receiver self-gates on getAppState()
 * and the dialer is enqueue-driven, so no service juggling is needed here.
 */
object SocketService {
    private const val TAG = "SocketService"

    private var socket: Socket? = null
    private var connectId: String? = null

    fun isConnected(): Boolean = socket?.connected() == true

    /** Open (or no-op if already up) the socket for [connectId]. Reads the mirrored session. */
    fun connect(context: Context, connectId: String) {
        val appCtx = context.applicationContext

        val token = SessionBridge.getToken(appCtx)
        if (token.isNullOrBlank()) {
            Log.w(TAG, "You need to be logged in to use this feature")
            return
        }
        if (connectId.isBlank()) {
            Log.w(TAG, "App cannot connect without a valid Connect ID")
            return
        }
        if (socket?.connected() == true) {
            Log.d(TAG, "Socket is already connected or connecting")
            return
        }
        val baseUrl = SessionBridge.getBaseUrl(appCtx)
        if (baseUrl.isNullOrBlank()) {
            Log.w(TAG, "No mirrored baseUrl for the socket")
            return
        }

        this.connectId = connectId

        val opts = IO.Options()
        // Match Hybrid's auth-map shape; clientType="phone" satisfies our F.1 relay's
        // phone-vs-portal routing, appClient carries the Nexus identity (gateway ignores it).
        opts.auth = mapOf(
            "connectId" to connectId,
            "clientType" to "phone",
            "appClient" to "BingwaNexus",
            "clientVersion" to appVersion(appCtx),
            "deviceModel" to Build.MODEL,
            "userId" to (SessionBridge.getAgentId(appCtx) ?: ""),
            "token" to token,
        )
        opts.reconnection = true
        opts.reconnectionDelay = 1_000
        opts.reconnectionDelayMax = 5_000
        opts.timeout = 20_000

        val s = try {
            IO.socket(baseUrl, opts)
        } catch (e: URISyntaxException) {
            Log.e(TAG, "Socket connection error: bad baseUrl '$baseUrl'", e)
            return
        }
        socket = s

        // Mirror Hybrid: log every incoming event for debuggability.
        s.onAnyIncoming { args -> Log.d(TAG, "Socket event in: ${args?.joinToString()}") }

        s.on(Socket.EVENT_CONNECT) { _ -> Log.d(TAG, "Socket connected") }
        s.on(Socket.EVENT_DISCONNECT) { _ -> Log.d(TAG, "Socket disconnected") }
        s.on(Socket.EVENT_CONNECT_ERROR) { args ->
            Log.e(TAG, "Socket connection error: ${args?.firstOrNull()}")
        }

        registerAppRelay(appCtx)
        // W5.F.2b: outbound read-only display relays (transactions/offers/kpis/airtime).
        PortalRelays.register(s, appCtx) { connectId }

        s.connect()
    }

    fun disconnect() {
        socket?.let {
            it.disconnect()
            it.close()
        }
        socket = null
        Log.d(TAG, "Socket disconnected and closed")
    }

    // ── AppRelay (verbatim Hybrid event names + payload keys) ───────────────────────────
    private fun registerAppRelay(appCtx: Context) {
        val s = socket ?: return
        s.on("app_state.set") { args -> handleAppStateSet(appCtx, args) }
        s.on("app_state.sync") { _ -> handleAppStatusQuery(appCtx) }
        s.on("app.status") { _ -> handleAppStatusQuery(appCtx) }
        s.on("app.presence") { args -> Log.d(TAG, "Presence: ${args?.firstOrNull()}") }
    }

    /** Remote start/pause/stop. Sets the engine's master switch, then acks app_state.set.ack. */
    private fun handleAppStateSet(appCtx: Context, args: Array<out Any?>?) {
        val json = args?.firstOrNull() as? JSONObject ?: return
        val stateStr = json.optString("state")
        // Hybrid parses case-insensitively against AppState.name(); map to Pro's wire value.
        val wire = when (stateStr.uppercase()) {
            "STATE_RUNNING" -> "running"
            "STATE_PAUSED" -> "paused"
            "STATE_STOPPED" -> "stopped"
            else -> {
                Log.e(TAG, "Invalid app state: $stateStr")
                return
            }
        }
        SessionBridge.saveAppState(appCtx, wire)

        val ack = JSONObject()
            .put("state", canonical(wire)) // echo the canonical STATE_* name (Hybrid: appState.name())
            .put("device", connectId ?: "")
        socket?.emit("app_state.set.ack", ack)
    }

    /** Status query (app.status / app_state.sync) → reply app.status.ack with current state. */
    private fun handleAppStatusQuery(appCtx: Context) {
        val json = JSONObject()
            .put("appState", canonical(SessionBridge.getAppState(appCtx)))
            .put("isConnected", isConnected())
            .put("device", connectId ?: "")
        socket?.emit("app.status.ack", json)
    }

    /** Pro lowercase wire value → Hybrid's canonical AppState.name(). */
    private fun canonical(wire: String): String = when (wire) {
        "running" -> "STATE_RUNNING"
        "paused" -> "STATE_PAUSED"
        else -> "STATE_STOPPED"
    }

    private fun appVersion(context: Context): String =
        try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
}
