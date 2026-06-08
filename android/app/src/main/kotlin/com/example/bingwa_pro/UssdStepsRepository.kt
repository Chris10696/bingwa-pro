// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdStepsRepository.kt
package com.example.bingwa_pro

import java.util.LinkedList
import java.util.Queue

/**
 * W3.C — the remaining-steps queue for an Advanced-mode multi-step USSD session.
 *
 * Verbatim behavioral port of Hybrid's UssdStepsRepositoryImpl. Hybrid injects this as
 * a Hilt @Singleton shared between the dialer use-case and the accessibility service;
 * since our UssdAccessibilityService is instantiated by the Android framework (not DI),
 * the process-wide equivalent is a Kotlin `object`. UssdEngine.dialAdvancedCapturing
 * writes the steps (addSteps) right before dialing; UssdAccessibilityService drains them
 * (pollStep) as each menu dialog appears.
 *
 * THREADING (matches Hybrid): the backing LinkedList is not synchronized, exactly as in
 * Hybrid. Access is causally serial — addSteps() completes before startActivity() opens
 * the dialer, and pollStep() only runs later on the main thread inside onAccessibilityEvent
 * (after the dialer UI exists). Hybrid ships this unsynchronized and it is proven in the
 * field; we match it rather than diverge.
 */
object UssdStepsRepository {
    private val ussdSteps: Queue<String> = LinkedList()

    fun addSteps(steps: List<String>) {
        ussdSteps.clear()
        ussdSteps.addAll(steps)
    }

    fun clearSteps() {
        ussdSteps.clear()
    }

    fun getSteps(): Queue<String> = LinkedList(ussdSteps)

    fun isEmpty(): Boolean = ussdSteps.isEmpty()

    /** Dequeue the next step, or null when empty. */
    fun pollStep(): String? = ussdSteps.poll()
}