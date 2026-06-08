// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\DialRequest.kt
package com.example.bingwa_pro

/**
 * W3.D — a unit of work for [UssdExecutionService]'s queue.
 *
 * Built by [ScheduleTransactionWorker] AFTER it has done all the safe PRE-dial
 * work (token check, GET, status validation). The service then performs the one
 * irreversible act (the dial) plus best-effort status push + recurrence/retry.
 *
 * `ussdTemplate` is the RAW offer template (may contain the "BH"/"AMT" tokens);
 * the service formats it via UssdEngine.formatUssdCode right before dialing
 * (Hybrid FormatUssdUseCase parity). `token` + `baseUrl` are captured fresh by
 * the worker so the service can PATCH status / POST the next renewal.
 *
 * W3.A: `externalRetries` carries the delayed-retry attempt count across the
 * WorkManager chain (Option C — no backend column). The worker reads it from
 * inputData; the ExternalRetry step in the service re-arms the SAME transactionId
 * with externalRetries+1 when it reschedules. Internal retries are NOT here —
 * they are an ephemeral in-session loop inside the service and never persisted.
 */
data class DialRequest(
    val transactionId: String,
    val ussdTemplate: String,
    val customerPhone: String,
    val amount: Int?,
    val isRecurringRenewal: Boolean,
    val daysRemaining: Int,
    val offerId: String?,
    val triggerAtMillis: Long,
    val token: String,
    val baseUrl: String,
    val externalRetries: Int = 0,
    // W3.M — auto-reply placeholder inputs. Threaded from the SMS path (customerName from
    // senderName, mpesaCode from the parsed code, offerName/offerPrice from the matched txn).
    // Nullable + defaulted so renewal/quick-dial construction sites compile unchanged; the
    // sender resolves missing values to ""/"null" exactly as Hybrid does for sparse records.
    val customerName: String? = null,
    val mpesaCode: String? = null,
    val offerName: String? = null,
    val offerPrice: Int? = null,
)