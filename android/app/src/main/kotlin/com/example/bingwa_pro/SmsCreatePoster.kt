// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SmsCreatePoster.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * W3.K — posts a parsed M-Pesa payment to the backend-first SMS endpoint and reports
 * back whether the device should dial. This is the inversion of the old dial-then-record
 * flow (D-W3-13): create-then-dial. Mirrors ScheduleTransactionWorker's OkHttp + SessionBridge
 * token pattern.
 *
 * POST /transactions/sms-create  (Bearer = mirrored session token)
 *   body = { mpesaTransactionId, amount, customerPhone, mpesaMessage }   (agentId from JWT)
 *
 * Backend (createFromSms) responses:
 *   201 + { transaction, autoReplyType:null,            shouldDial:true  } → MATCH (SCHEDULED, debited) → DIAL
 *   201 + { transaction, autoReplyType:'OFFER_UNAVAILABLE', shouldDial:false } → UNMATCHED (no debit) → no dial (W3.M reply)
 *   402  → agent has no plan → no dial
 *   409  → duplicate (mpesaTransactionId already recorded for this agent) → MUST NOT dial (idempotency)
 *
 * MONEY-SAFETY: the device dials ONLY on an explicit 201 + shouldDial=true that also carries a
 * non-blank ussdCode + transaction id. Any other outcome (402/409/parse-less body/transient
 * error) → DoNotDial. We never invent a dial from an ambiguous response.
 */
object SmsCreatePoster {
    private const val TAG = "SmsCreatePoster"
    private val JSON = "application/json".toMediaType()

    private val http: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    sealed class SmsCreateOutcome {
        /** 201 + shouldDial=true: enqueue this into UssdExecutionService. */
        data class Dial(val request: DialRequest) : SmsCreateOutcome()
        /**
         * 201 + shouldDial=false (UNMATCHED), 402 (no plan), 409 (dupe), or any non-dial case.
         * [autoReplyType] is non-null only when the backend asks for a customer reply
         * (UNMATCHED → "OFFER_UNAVAILABLE"); the parsed fields let the caller substitute it.
         */
        data class DoNotDial(
            val reason: String,
            val autoReplyType: String? = null,
            val parsed: ParsedMpesa? = null,
        ) : SmsCreateOutcome()
    }

    /**
     * Create the SMS transaction on the backend and decide whether to dial.
     * [triggerAtMillis] is "now" (M-Pesa dials are immediate, unlike scheduled renewals).
     */
    suspend fun createAndDecide(context: Context, parsed: ParsedMpesa): SmsCreateOutcome =
        withContext(Dispatchers.IO) {
            val token = SessionBridge.getToken(context)
            val baseUrl = SessionBridge.getBaseUrl(context) ?: BuildConfig.API_BASE_URL
            if (token.isNullOrBlank()) {
                // No mirrored session yet (not logged in / token not pushed). Nothing fired.
                return@withContext SmsCreateOutcome.DoNotDial("no session token")
            }

            val payload = JSONObject().apply {
                put("mpesaTransactionId", parsed.mpesaCode)
                put("amount", parsed.amount)
                put("customerPhone", parsed.customerPhone)
                // W4-batch-3: the sender name from the SMS so the backend can name the
                // get-or-created customer record (DefaultMessageExtractor "from <name>").
                put("customerName", parsed.senderName)
                put("mpesaMessage", parsed.rawMessage)
            }.toString()

            try {
                val request = Request.Builder()
                    .url("$baseUrl/transactions/sms-create")
                    .addHeader("Authorization", "Bearer $token")
                    .post(payload.toRequestBody(JSON))
                    .build()

                http.newCall(request).execute().use { response ->
                    val bodyStr = response.body?.string()
                    when (response.code) {
                        201 -> parseCreated(bodyStr, token, baseUrl, parsed)
                        402 -> SmsCreateOutcome.DoNotDial("402 no active plan")
                        409 -> SmsCreateOutcome.DoNotDial("409 duplicate payment (idempotent)")
                        else -> SmsCreateOutcome.DoNotDial("HTTP ${response.code}")
                    }
                }
            } catch (e: Exception) {
                // Transient/network failure: nothing dialed. The offline-queue concern (D-W3-13
                // guard #1) is a future enhancement; for now a failed create simply doesn't dial,
                // and the backend's mpesaTransactionId idempotency makes a later retry safe.
                Log.e(TAG, "createAndDecide error: ${e.message}", e)
                SmsCreateOutcome.DoNotDial("exception: ${e.message}")
            }
        }

    /** Parse a 201 SmsCreateResult and build a DialRequest iff shouldDial && it's dialable. */
    private fun parseCreated(
        bodyStr: String?,
        token: String,
        baseUrl: String,
        parsed: ParsedMpesa,
    ): SmsCreateOutcome {
        if (bodyStr.isNullOrBlank()) return SmsCreateOutcome.DoNotDial("201 with empty body")
        return try {
            val json = JSONObject(bodyStr)
            val shouldDial = json.optBoolean("shouldDial", false)
            val txn = json.optJSONObject("transaction")
            if (!shouldDial || txn == null) {
                // UNMATCHED → backend supplies autoReplyType (e.g. OFFER_UNAVAILABLE). Carry it
                // + the parsed inputs so the caller fires the W3.M reply.
                val hint = json.optString("autoReplyType", "").ifBlank { null }
                SmsCreateOutcome.DoNotDial(
                    reason = "UNMATCHED${if (hint != null) " ($hint)" else ""}",
                    autoReplyType = hint,
                    parsed = parsed,
                )
            } else {
                val txnId = txn.optString("id", "")
                val ussdTemplate = txn.optString("ussdCode", "")
                if (txnId.isBlank() || ussdTemplate.isBlank()) {
                    SmsCreateOutcome.DoNotDial("matched txn missing id/ussdCode")
                } else {
                    val customerPhone = txn.optString("customerPhone", "")
                    val offerIdRaw = txn.optString("offerId", "")
                    val offerId = if (offerIdRaw.isBlank()) null else offerIdRaw
                    val amount = if (txn.has("amount"))
                        txn.optDouble("amount", 0.0).toInt().takeIf { it > 0 } else null
                    val offerName = txn.optString("offerName", "").ifBlank { null }
                    val offerPrice = if (txn.has("amount"))
                        txn.optDouble("amount", 0.0).toInt().takeIf { it > 0 } else null
                    Log.d(TAG, "sms-create 201 MATCH → dialing txn=$txnId")
                    SmsCreateOutcome.Dial(
                        DialRequest(
                            transactionId = txnId,
                            ussdTemplate = ussdTemplate,
                            customerPhone = customerPhone,
                            amount = amount,
                            isRecurringRenewal = false, // M-Pesa one-shot (not a renewal)
                            daysRemaining = 0,
                            offerId = offerId,
                            triggerAtMillis = System.currentTimeMillis(),
                            token = token,
                            baseUrl = baseUrl,
                            externalRetries = 0,
                            // W3.M auto-reply inputs (customerName from the M-Pesa senderName).
                            customerName = parsed.senderName,
                            mpesaCode = parsed.mpesaCode,
                            offerName = offerName,
                            offerPrice = offerPrice,
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "parseCreated error: ${e.message}", e)
            SmsCreateOutcome.DoNotDial("bad 201 body")
        }
    }
}