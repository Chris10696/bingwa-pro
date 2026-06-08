// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SessionHeartbeatWorker.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * W3.J — 24/7 token-refresh heartbeat (WorkManager backstop layer of D-W3-7).
 *
 * Mirrors Hybrid's AccountHealthCheckWorker: a periodic (20-min, CONNECTED)
 * CoroutineWorker that VALIDATES the current session rather than refreshing it.
 * Rationale (matched to Hybrid + Pro's split architecture):
 *   - The mirrored token is a long-lived (~7-day) JWT, so it rarely expires
 *     mid-session; the heartbeat's job is to keep the session warm and to detect
 *     a dead/revoked session early — exactly Hybrid's health-check worker.
 *   - Token *refresh* stays in-app (auth_provider.refreshSession(), which already
 *     re-mirrors to SessionBridge) — a native worker has no refresh token to use
 *     (SessionBridge mirrors only the access token, baseUrl, agentId).
 *
 * On a dead session (401/403) this only LOGS (D-W3-J decision 3, conservative):
 * it does NOT wipe the mirror or force logout. The pipeline's own pre-dial
 * GET /offers/:id already aborts before dialing on a dead token (no wasted
 * dials), Dart owns the token lifecycle and re-authenticates on next foreground,
 * and a single transient 401 must not tear down a valid session.
 *
 * Scheduled/cancelled with the session mirror itself (WorkScheduler, hooked from
 * MainActivity's setSession/clearSession) — so it runs exactly while logged in.
 */
class SessionHeartbeatWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "SessionHeartbeat"
        // Lightweight authenticated probe — confirmed-existing + cheap. A 401/403
        // here means the session is dead; any 2xx means the token is still good.
        private const val PROBE_PATH = "/wallet/balance"
    }

    private val http: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val token = SessionBridge.getToken(applicationContext)
        val baseUrl = SessionBridge.getBaseUrl(applicationContext)
        if (token.isNullOrEmpty() || baseUrl.isNullOrEmpty()) {
            // Not logged in (or mirror cleared on logout) — nothing to keep warm.
            Log.d(TAG, "No mirrored session; heartbeat idle.")
            return@withContext Result.success()
        }

        try {
            val request = Request.Builder()
                .url("$baseUrl$PROBE_PATH")
                .addHeader("Authorization", "Bearer $token")
                .get()
                .build()
            http.newCall(request).execute().use { resp ->
                when {
                    resp.isSuccessful -> {
                        Log.d(TAG, "Session warm (HTTP ${resp.code}).")
                        Result.success()
                    }
                    resp.code == 401 || resp.code == 403 -> {
                        // Dead/revoked session. Log only — Dart re-auths on next
                        // foreground; do not wipe the mirror or force logout.
                        Log.w(TAG, "Session appears invalid (HTTP ${resp.code}); awaiting in-app re-auth.")
                        Result.success()
                    }
                    else -> {
                        // Server hiccup (5xx etc.) — try again next window.
                        Log.w(TAG, "Heartbeat probe HTTP ${resp.code}; will retry.")
                        Result.retry()
                    }
                }
            }
        } catch (e: IOException) {
            // Offline / timeout — CONNECTED constraint should gate most of these,
            // but retry the rest rather than treating them as a dead session.
            Log.w(TAG, "Heartbeat probe failed (network): ${e.message}; will retry.")
            Result.retry()
        } catch (e: Exception) {
            // Never let the heartbeat crash the worker.
            Log.e(TAG, "Heartbeat probe error: ${e.message}", e)
            Result.success()
        }
    }
}