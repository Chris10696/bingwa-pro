// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\PortalRelays.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log
import io.socket.client.Socket
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * W5.F.2b — the HybridConnect/Portal OUTBOUND read-only "display" relays, ported from
 * Hybrid's TransactionRelay / OfferRelay / KpiRelay / AirtimeRelay (rebranded).
 *
 * The web Portal asks (e.g. emits `kpis.sync`); the phone fetches the agent's data and
 * emits the matching `*.sync.ack` back over the socket. Our F.1 gateway is a dumb relay,
 * so this request→respond pattern is what surfaces live data on the Portal.
 *
 * EVENT NAMES + ENVELOPE KEYS match Hybrid verbatim (the protocol contract):
 *   transactions.sync {offset,limit} → transactions.sync.ack {total, current, transaction[], device}
 *   offers.sync                      → offers.sync.ack          {offers[], device}
 *   kpis.sync                        → kpis.sync.ack            {kpis:{successCount,failedCount,limitedTokens,unlimitedTokensExpiry}, device}
 *   airtime_balance.sync             → airtime_balance.sync.ack {balance, device}
 *   airtime_used.sync                → airtime_used.sync.ack    {used, device}
 * The NESTED objects (transaction/offer rows) carry Pro's backend JSON shapes — the Portal
 * is the user's own deployment built against Pro's API, so we pass them through unchanged.
 *
 * SCOPE: read-only display only. The inbound MUTATING commands Hybrid also wires here
 * (transaction.retry / transaction.delete / offer.update / offer.delete) are deliberately
 * NOT registered — they move money / delete data remotely and are deferred to F.2c.
 *
 * SOURCES (read via the mirrored session token, like SmsCreatePoster):
 *   transactions ← GET /transactions/history?page&pageSize
 *   offers       ← GET /offers
 *   kpis         ← GET /transactions/summary/today  (+ GET /wallet/balance for tokens)
 *   airtime bal. ← SessionBridge cache (populated by AirtimeChecker) — NEVER dials *144#
 *                  on a Portal request; airtime_used has no Pro source yet → 0.0 (placeholder).
 */
object PortalRelays {
    private const val TAG = "PortalRelays"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val JSON = "application/json".toMediaType()

    private val http: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    /** Register the read-only sync listeners on a freshly-connected socket. */
    fun register(socket: Socket, appCtx: Context, connectId: () -> String?) {
        socket.on("transactions.sync") { args ->
            scope.launch { handleTransactionsSync(socket, appCtx, connectId(), args) }
        }
        socket.on("offers.sync") { _ ->
            scope.launch { handleOffersSync(socket, appCtx, connectId()) }
        }
        socket.on("kpis.sync") { _ ->
            scope.launch { handleKpisSync(socket, appCtx, connectId()) }
        }
        socket.on("airtime_balance.sync") { _ ->
            scope.launch { handleAirtimeBalanceSync(socket, appCtx, connectId()) }
        }
        socket.on("airtime_used.sync") { _ ->
            handleAirtimeUsedSync(socket, connectId())
        }
        // W5.F.2c — inbound MUTATING commands. Backend enforces ownership via the mirrored JWT.
        //   offer.update / offer.delete → PATCH/DELETE /offers/:id.
        //   transaction.retry → re-enqueue a FAILED sale through the W3 pipeline (re-dial).
        // transaction.delete is intentionally NOT wired (Pro's transactions are a money/audit
        // ledger with no delete endpoint — locked decision: no remote ledger deletion).
        socket.on("offer.update") { args ->
            scope.launch { handleOfferUpdate(socket, appCtx, connectId(), args) }
        }
        socket.on("offer.delete") { args ->
            scope.launch { handleOfferDelete(socket, appCtx, connectId(), args) }
        }
        socket.on("transaction.retry") { args ->
            scope.launch { handleTransactionRetry(appCtx, args) }
        }
    }

    // ── handlers ────────────────────────────────────────────────────────────────────

    private fun handleTransactionsSync(
        socket: Socket,
        ctx: Context,
        device: String?,
        args: Array<out Any?>?,
    ) {
        val req = args?.firstOrNull() as? JSONObject
        val limit = (req?.optInt("limit", 20) ?: 20).coerceIn(1, 100)
        val offset = (req?.optInt("offset", 0) ?: 0).coerceAtLeast(0)
        val page = (offset / limit) + 1

        val body = get(ctx, "/transactions/history?page=$page&pageSize=$limit")
        val obj = body?.let { runCatching { JSONObject(it) }.getOrNull() }
        val list = obj?.optJSONArray("transactions") ?: JSONArray()
        val total = obj?.optInt("total", list.length()) ?: 0

        emit(socket, "transactions.sync.ack", JSONObject()
            .put("total", total)
            .put("current", offset)
            .put("transaction", list)
            .put("device", device ?: ""))
    }

    private fun handleOffersSync(socket: Socket, ctx: Context, device: String?) {
        val body = get(ctx, "/offers")
        val offers = parseArray(body, "offers", "data", "items")
        emit(socket, "offers.sync.ack", JSONObject()
            .put("offers", offers)
            .put("device", device ?: ""))
    }

    private fun handleKpisSync(socket: Socket, ctx: Context, device: String?) {
        // success/failed counts (today) + token state from the wallet balance.
        val summary = get(ctx, "/transactions/summary/today")
            ?.let { runCatching { JSONObject(it) }.getOrNull() }
        val successCount = summary?.optInt("successful", 0) ?: 0
        val failedCount = summary?.optInt("failed", 0) ?: 0

        val balance = get(ctx, "/wallet/balance")
            ?.let { runCatching { JSONObject(it) }.getOrNull() }
        val plans = balance?.optJSONArray("plans") ?: JSONArray()
        var limitedTokens = 0
        var unlimitedExpiry: String? = null
        for (i in 0 until plans.length()) {
            val p = plans.optJSONObject(i) ?: continue
            when (p.optString("type").uppercase()) {
                "LIMITED" -> limitedTokens += p.optInt("tokensRemaining", 0)
                "UNLIMITED" -> {
                    val exp = p.optString("expiresAt", "")
                    if (exp.isNotBlank()) unlimitedExpiry = exp
                }
            }
        }

        val kpis = JSONObject()
            .put("successCount", successCount)
            .put("failedCount", failedCount)
            .put("limitedTokens", limitedTokens)
            .put("unlimitedTokensExpiry", unlimitedExpiry ?: JSONObject.NULL)

        Log.d(TAG, "Syncing KPIs: successCount=$successCount, failedCount=$failedCount")
        emit(socket, "kpis.sync.ack", JSONObject()
            .put("kpis", kpis)
            .put("device", device ?: ""))
    }

    private fun handleAirtimeBalanceSync(socket: Socket, ctx: Context, device: String?) {
        // Last cached *144# balance — NEVER dials on a Portal request (a dial would spend
        // a USSD round-trip on the dial SIM). The cache is populated by AirtimeChecker.
        val balance = SessionBridge.getLastAirtimeBalance(ctx) ?: 0.0
        emit(socket, "airtime_balance.sync.ack", JSONObject()
            .put("balance", balance)
            .put("device", device ?: ""))
    }

    private fun handleAirtimeUsedSync(socket: Socket, device: String?) {
        // PLACEHOLDER: Pro has no "airtime used today" source yet (W5.B deferred it). Emit 0.0
        // so the Portal doesn't hang waiting; wire a real figure when a source exists.
        emit(socket, "airtime_used.sync.ack", JSONObject()
            .put("used", 0.0)
            .put("device", device ?: ""))
    }

    // ── W5.F.2c mutating offer handlers ───────────────────────────────────────────────

    private fun handleOfferUpdate(
        socket: Socket,
        ctx: Context,
        device: String?,
        args: Array<out Any?>?,
    ) {
        val req = args?.firstOrNull() as? JSONObject
        val offer = req?.optJSONObject("offer")
        if (offer == null) {
            Log.e(TAG, "Key 'offer' missing in JSONObject")
            return
        }
        val id = offer.optString("id")
        if (id.isBlank()) {
            Log.e(TAG, "offer.update missing offer id")
            return
        }
        // Forward the editable fields; strip server-managed ones (the backend whitelists too).
        val body = JSONObject(offer.toString()).apply {
            remove("id"); remove("agentId"); remove("createdAt"); remove("updatedAt")
        }
        val (code, respBody) = patch(ctx, "/offers/$id", body.toString())
        if (code !in 200..299) {
            Log.e(TAG, "Error updating offer: HTTP $code")
            return
        }
        val updated = respBody?.let { runCatching { JSONObject(it) }.getOrNull() } ?: offer
        emit(socket, "offer.update.ack", JSONObject()
            .put("offer", updated)
            .put("device", device ?: ""))
    }

    private fun handleOfferDelete(
        socket: Socket,
        ctx: Context,
        device: String?,
        args: Array<out Any?>?,
    ) {
        val req = args?.firstOrNull() as? JSONObject
        val offerId = req?.optString("offerId")
        if (offerId.isNullOrBlank()) {
            Log.e(TAG, "offer.delete missing offerId")
            return
        }
        val code = delete(ctx, "/offers/$offerId")
        val success = code in 200..299
        if (!success) Log.e(TAG, "Error deleting offer: HTTP $code")
        emit(socket, "offer.delete.ack", JSONObject()
            .put("offerId", offerId)
            .put("success", success)
            .put("device", device ?: ""))
    }

    // ── W5.F.2c transaction.retry (re-dial a FAILED sale through the W3 pipeline) ──────
    // MONEY-SAFETY: only a FAILED transaction with a ussdCode is re-enqueued, and the W3
    // pipeline dials each request at most once. A SUCCESS/PROCESSING/etc. row is skipped, so
    // a remote retry can never re-deliver a sale that already went through. No ack (Hybrid's
    // handleRetryTransaction emits none); the outcome surfaces via the next transactions.sync.
    private fun handleTransactionRetry(ctx: Context, args: Array<out Any?>?) {
        val req = args?.firstOrNull() as? JSONObject
        val txnId = req?.optString("transactionId")
        if (txnId.isNullOrBlank()) {
            Log.e(TAG, "Could not get transaction ID")
            return
        }
        val txn = get(ctx, "/transactions/$txnId")
            ?.let { runCatching { JSONObject(it) }.getOrNull() }
        if (txn == null) {
            Log.e(TAG, "transaction.retry: could not fetch $txnId")
            return
        }
        val status = txn.optString("status").uppercase()
        if (status != "FAILED") {
            Log.w(TAG, "transaction.retry skipped: $txnId status=$status (only FAILED is retriable)")
            return
        }
        val ussdCode = txn.optString("ussdCode")
        if (ussdCode.isBlank()) {
            Log.w(TAG, "transaction.retry skipped: $txnId has no ussdCode")
            return
        }
        val token = SessionBridge.getToken(ctx)
        val baseUrl = SessionBridge.getBaseUrl(ctx) ?: BuildConfig.API_BASE_URL
        if (token.isNullOrBlank()) {
            Log.w(TAG, "transaction.retry skipped: no mirrored session token")
            return
        }
        val customerPhone = txn.optString("customerPhone").ifBlank { txn.optString("recipientPhone") }
        val offerId = txn.optString("offerId").ifBlank { null }
        val offerName = txn.optString("offerName").ifBlank { null }
        val amount = if (txn.has("amount"))
            txn.optDouble("amount", 0.0).toInt().takeIf { it > 0 } else null

        UssdExecutionService.enqueue(
            ctx,
            DialRequest(
                transactionId = txnId,
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
                customerName = null,
                mpesaCode = null,
                offerName = offerName,
                offerPrice = amount,
            ),
        )
        Log.d(TAG, "transaction.retry: re-enqueued FAILED txn $txnId")
    }

    // ── helpers ─────────────────────────────────────────────────────────────────────

    private fun emit(socket: Socket, event: String, payload: JSONObject) {
        try {
            socket.emit(event, payload)
        } catch (e: Exception) {
            Log.e(TAG, "emit $event failed: ${e.message}")
        }
    }

    /** Authenticated GET against the backend using the mirrored session. Null on any failure. */
    private fun get(ctx: Context, path: String): String? {
        val token = SessionBridge.getToken(ctx)
        if (token.isNullOrBlank()) return null
        val baseUrl = SessionBridge.getBaseUrl(ctx) ?: BuildConfig.API_BASE_URL
        return try {
            val req = Request.Builder()
                .url("$baseUrl$path")
                .addHeader("Authorization", "Bearer $token")
                .get()
                .build()
            http.newCall(req).execute().use { resp ->
                if (resp.isSuccessful) resp.body?.string() else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "GET $path failed: ${e.message}")
            null
        }
    }

    /** Authenticated PATCH. Returns (httpCode, body); code 0 on transport failure. */
    private fun patch(ctx: Context, path: String, jsonBody: String): Pair<Int, String?> {
        val token = SessionBridge.getToken(ctx) ?: return 0 to null
        val baseUrl = SessionBridge.getBaseUrl(ctx) ?: BuildConfig.API_BASE_URL
        return try {
            val req = Request.Builder()
                .url("$baseUrl$path")
                .addHeader("Authorization", "Bearer $token")
                .patch(jsonBody.toRequestBody(JSON))
                .build()
            http.newCall(req).execute().use { resp -> resp.code to resp.body?.string() }
        } catch (e: Exception) {
            Log.e(TAG, "PATCH $path failed: ${e.message}")
            0 to null
        }
    }

    /** Authenticated DELETE. Returns the http code (0 on transport failure). */
    private fun delete(ctx: Context, path: String): Int {
        val token = SessionBridge.getToken(ctx) ?: return 0
        val baseUrl = SessionBridge.getBaseUrl(ctx) ?: BuildConfig.API_BASE_URL
        return try {
            val req = Request.Builder()
                .url("$baseUrl$path")
                .addHeader("Authorization", "Bearer $token")
                .delete()
                .build()
            http.newCall(req).execute().use { resp -> resp.code }
        } catch (e: Exception) {
            Log.e(TAG, "DELETE $path failed: ${e.message}")
            0
        }
    }

    /** Parse [body] into a JSONArray — directly if it's an array, else from the first wrapper key. */
    private fun parseArray(body: String?, vararg keys: String): JSONArray {
        if (body.isNullOrBlank()) return JSONArray()
        val trimmed = body.trim()
        return try {
            if (trimmed.startsWith("[")) {
                JSONArray(trimmed)
            } else {
                val obj = JSONObject(trimmed)
                keys.firstNotNullOfOrNull { obj.optJSONArray(it) } ?: JSONArray()
            }
        } catch (e: Exception) {
            JSONArray()
        }
    }
}
