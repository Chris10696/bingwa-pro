// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\WorkScheduler.kt
package com.example.bingwa_pro

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

/**
 * W3.E — device-side scheduled firing.
 *
 * Mirrors Hybrid's per-worker `*WorkerManager` helpers + ScheduleTransactionWorker:
 * a WorkManager OneTimeWorkRequest keyed by transactionId, with input data
 * { transactionId, triggerAtMillis }. WorkManager persists the request across
 * process death and reboot (via its built-in RescheduleReceiver), so an overdue
 * job fires on the next boot — D-W3-18 "fire all overdues", no custom boot code.
 *
 * Unique work (REPLACE) keyed by transactionId guarantees re-arming the same row
 * never stacks duplicate jobs.
 *
 * Why triggerAtMillis is also stored in inputData (W3.E recurrence): when a
 * recurring row fires, the worker schedules the next day. Anchoring "+1 day" on
 * the original epoch-millis trigger (carried here) avoids parsing the stored
 * ISO `scheduledFor` string entirely — sidestepping both the Dart-vs-Java ISO
 * format mismatch and the java.time-needs-API-26 desugaring trap. The ISO string
 * is only ever *formatted* from millis for display/storage, never parsed.
 */
object WorkScheduler {
    private const val TAG = "WorkScheduler"
    const val TAG_SCHEDULED = "scheduled_txn"

    private fun uniqueName(transactionId: String): String = "scheduled_txn_$transactionId"

    /**
     * Arm a one-shot to fire the scheduled transaction at [triggerAtMillis]
     * (epoch millis). A past timestamp fires as soon as constraints allow
     * (handles overdue rows). CONNECTED constraint defers the fire until the
     * device has network, since the worker must reach the backend.
     */
    fun arm(context: Context, transactionId: String, triggerAtMillis: Long, externalRetries: Int = 0) {
        val delayMs = (triggerAtMillis - System.currentTimeMillis()).coerceAtLeast(0L)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<ScheduleTransactionWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setInputData(
                workDataOf(
                    ScheduleTransactionWorker.KEY_TRANSACTION_ID to transactionId,
                    ScheduleTransactionWorker.KEY_TRIGGER_AT_MILLIS to triggerAtMillis,
                    ScheduleTransactionWorker.KEY_EXTERNAL_RETRIES to externalRetries,
                ),
            )
            .setConstraints(constraints)
            .addTag(TAG_SCHEDULED)
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork(uniqueName(transactionId), ExistingWorkPolicy.REPLACE, request)
        Log.d(TAG, "Armed scheduled txn $transactionId in ${delayMs}ms (triggerAt=$triggerAtMillis, externalRetries=$externalRetries)")
    }

    /** Cancel the armed one-shot for a (cancelled) scheduled transaction. */
    fun cancel(context: Context, transactionId: String) {
        WorkManager.getInstance(context.applicationContext)
            .cancelUniqueWork(uniqueName(transactionId))
        Log.d(TAG, "Cancelled scheduled txn $transactionId")
    }

    // ── W3.J: 24/7 session-validity heartbeat (WorkManager backstop) ──────────────
    private const val HEARTBEAT_WORK = "SessionHeartbeatWork"
    private const val HEARTBEAT_INTERVAL_MIN = 20L // Hybrid AccountHealthCheckWorker

    /**
     * Schedule the periodic session-validity heartbeat. Mirrors Hybrid's
     * AccountHealthCheckWorker: every 20 min, CONNECTED. KEEP (not REPLACE) so
     * re-scheduling on each launch/login is idempotent and never resets the
     * period. WorkManager persists this across process death + reboot.
     *
     * Hooked from MainActivity's setSession handler, so it begins as soon as a
     * session is mirrored and is cancelled on clearSession (logout).
     */
    fun scheduleSessionHeartbeat(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<SessionHeartbeatWorker>(
            HEARTBEAT_INTERVAL_MIN, TimeUnit.MINUTES,
        )
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniquePeriodicWork(
                HEARTBEAT_WORK, ExistingPeriodicWorkPolicy.KEEP, request,
            )
        Log.d(TAG, "Session heartbeat scheduled (every ${HEARTBEAT_INTERVAL_MIN}min, KEEP)")
    }

    /** Cancel the heartbeat on logout (clearSession). */
    fun cancelSessionHeartbeat(context: Context) {
        WorkManager.getInstance(context.applicationContext)
            .cancelUniqueWork(HEARTBEAT_WORK)
        Log.d(TAG, "Session heartbeat cancelled")
    }
}