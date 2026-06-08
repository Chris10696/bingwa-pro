// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdSessionManager.kt
package com.example.bingwa_pro

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred

/**
 * W3.C — the rendezvous between the dialer coroutine and the accessibility service for
 * an Advanced-mode USSD session. Verbatim behavioral port of Hybrid's
 * UssdSessionManagerImpl.
 *
 * UssdEngine.dialAdvancedCapturing awaits waitForCompletion(); UssdAccessibilityService
 * calls completeSession(...) once it has typed all steps and read the final dialog.
 * Like the steps repo, Hybrid injects this as a Hilt @Singleton; the framework-instantiated
 * accessibility service forces the process-wide-object equivalent here.
 *
 * CompletableDeferred is itself thread-safe (kotlinx.coroutines), so completeSession on the
 * main thread and await on the IO/dialer thread are safe.
 *
 * resetSession() intentionally only swaps in a fresh deferred WHEN the current one is
 * already completed — this is Hybrid's exact semantics. dialAdvancedCapturing calls it
 * before dialing (so a completed prior session yields a fresh one) and again after the
 * await (so the just-completed session is recycled for next time).
 */
object UssdSessionManager {
    @Volatile
    private var sessionCompletion: CompletableDeferred<UssdSessionState> = CompletableDeferred()

    /** Completes the active session if not already completed (idempotent, like Hybrid). */
    fun completeSession(state: UssdSessionState) {
        if (!sessionCompletion.isCompleted) {
            sessionCompletion.complete(state)
        }
    }

    fun isSessionActive(): Boolean = !sessionCompletion.isCompleted

    /** Replaces the deferred with a fresh one ONLY if the current one is completed. */
    fun resetSession() {
        if (sessionCompletion.isCompleted) {
            sessionCompletion = CompletableDeferred()
        }
    }

    fun waitForCompletion(): Deferred<UssdSessionState> = sessionCompletion
}