// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\ScheduleTransactionWorker.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * W3.E + W3.D — fires a SCHEDULED transaction when it comes due (auto-renewals).
 *
 * REVISED for W3.D: this worker now does only the SAFE PRE-dial work, then hands the
 * irreversible dial to [UssdExecutionService] (the foreground queue dialer) and exits.
 * It no longer dials, PATCHes status, or chains recurrence directly — the service does
 * all of that with the REAL captured outcome.
 *
 * ── MONEY-SAFETY ────────────────────────────────────────────────────────────────
 * Every retry() path here is strictly PRE-dial (no token yet, or the row fetch blipped)
 * — nothing has fired, so retrying is safe. The worker returns success() immediately
 * after enqueuing, so WorkManager does not retry it once the dial has been handed off.
 * A duplicate run (worker crashes after enqueue, before returning) is caught two ways:
 * the service has already moved the row to PROCESSING (this worker's GET then sees a
 * non-SCHEDULED status and skips), and the service's in-flight guard rejects a second
 * dial of the same id. Bias: never double-charge.
 *
 * WorkManager persists the request across reboot (built-in RescheduleReceiver), so an
 * overdue job fires on the next boot — D-W3-18 "fire all overdues", no custom boot code.
 */
class ScheduleTransactionWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        const val KEY_TRANSACTION_ID = "transactionId"
        const val KEY_TRIGGER_AT_MILLIS = "triggerAtMillis"
        const val KEY_EXTERNAL_RETRIES = "externalRetries"
        private const val TAG = "ScheduleTxnWorker"
    }

    private val http: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    override suspend fun doWork(): Result {
        val txnId = inputData.getString(KEY_TRANSACTION_ID)
        if (txnId.isNullOrBlank()) {
            Log.e(TAG, "No transactionId in input data — failing permanently")
            return Result.failure()
        }
        val triggerAtMillis = inputData.getLong(KEY_TRIGGER_AT_MILLIS, -1L)

        val token = SessionBridge.getToken(applicationContext)
        val baseUrl = SessionBridge.getBaseUrl(applicationContext) ?: BuildConfig.API_BASE_URL

        // PRE-DIAL retry: no session mirrored yet (Dart token push / W3.J). Nothing
        // fired — safe to retry; self-heals once the token is mirrored.
        if (token.isNullOrBlank()) {
            Log.w(TAG, "No session token for $txnId yet — retrying later")
            return Result.retry()
        }

        val txn = fetchTransaction(baseUrl, token, txnId)
        if (txn == null) {
            Log.w(TAG, "Could not fetch txn $txnId (network/transient) — retrying")
            return Result.retry()
        }

        val status = txn.optString("status", "")
        if (status != "SCHEDULED" && status != "RESCHEDULED") {
            // Cancelled, already fired/processing (re-entrancy guard), or deleted.
            // SCHEDULED = first fire; RESCHEDULED = an external-retry re-arm (W3.A).
            Log.d(TAG, "Txn $txnId status=$status (not SCHEDULED/RESCHEDULED) — skipping")
            return Result.success()
        }

        val ussdTemplate = txn.optString("ussdCode", "")
        if (ussdTemplate.isBlank()) {
            Log.e(TAG, "Txn $txnId has no ussdCode — nothing to dial; marking handled")
            return Result.success()
        }
        val customerPhone = txn.optString("customerPhone", "")
        val offerIdRaw = txn.optString("offerId", "")
        val offerId = if (offerIdRaw.isBlank()) null else offerIdRaw
        val amount = if (txn.has("amount")) txn.optDouble("amount", 0.0).toInt().takeIf { it > 0 } else null

        val reschedule = txn.optJSONObject("rescheduleInfo")
        val isRecurring = reschedule?.optBoolean("isRecurring", false) ?: false
        val daysRemaining = reschedule?.optInt("daysRemaining", 0) ?: 0

        // W3.A external-retry chain (Option C): the attempt count rides in inputData,
        // not the backend. First fire = 0; each external-retry re-arm carries +1.
        val externalRetries = inputData.getInt(KEY_EXTERNAL_RETRIES, 0)

        // Hand the irreversible dial to the foreground service (W3.D). The service
        // formats BH→phone, dials once via the capturing Express path (W3.B), runs the
        // retry/classifier pipeline (W3.A), PATCHes the REAL status, and chains
        // recurrence / external-retry. No dial/PATCH here → no post-dial retry here.
        UssdExecutionService.enqueue(
            applicationContext,
            DialRequest(
                transactionId = txnId,
                ussdTemplate = ussdTemplate,
                customerPhone = customerPhone,
                amount = amount,
                isRecurringRenewal = isRecurring,
                daysRemaining = daysRemaining,
                offerId = offerId,
                triggerAtMillis = triggerAtMillis,
                token = token,
                baseUrl = baseUrl,
                externalRetries = externalRetries,
            ),
        )
        Log.d(TAG, "Enqueued $txnId into UssdExecutionService")
        return Result.success()
    }

    /** GET /transactions/:id with Bearer auth. Returns the row JSON, or null on transient failure. */
    private suspend fun fetchTransaction(baseUrl: String, token: String, id: String): JSONObject? =
        withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("$baseUrl/transactions/$id")
                    .addHeader("Authorization", "Bearer $token")
                    .get()
                    .build()
                http.newCall(request).execute().use { response ->
                    val body = response.body?.string()
                    when {
                        response.isSuccessful && body != null -> JSONObject(body)
                        response.code == 404 -> {
                            Log.d(TAG, "GET /transactions/$id → 404 (row gone)")
                            JSONObject().put("status", "DELETED")
                        }
                        else -> {
                            Log.w(TAG, "GET /transactions/$id → HTTP ${response.code}")
                            null
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "fetchTransaction error: ${e.message}", e)
                null
            }
        }
}