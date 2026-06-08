// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdAccessibilityService.kt
package com.example.bingwa_pro

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale

/**
 * W3.C — Advanced-mode USSD automation, a verbatim behavioral port of Hybrid's
 * UssdAccessibilityService. This REPLACES the old hardcoded-English-menu-string version.
 *
 * How Advanced works end-to-end:
 *   1. UssdEngine.dialAdvancedCapturing extracts the steps (UssdUtils.extractSteps), pushes
 *      the menu-reply steps into UssdStepsRepository, dials the first step (*BASE#) via
 *      ACTION_CALL, and awaits UssdSessionManager.
 *   2. As each Safaricom USSD dialog appears, the framework delivers an AccessibilityEvent
 *      here. We recognise a USSD dialog (isUSSDWidget), and:
 *        - if it has an input field and steps remain → type the next step + tap SEND;
 *        - if it has an input field but no steps remain → read the text, dismiss, complete;
 *        - if it has no input field and exactly one button (final dialog) → read the text,
 *          tap the button, complete.
 *   3. completeSession runs the final text through UssdUtils.isSuccessfulResponse to mark
 *      the session Success or Failure, which unblocks the dialer coroutine.
 *
 * Gating: we only act when the agent's processing mode is ADVANCED (read from SessionBridge —
 * the same native mirror the background worker uses) AND a session is active. Otherwise every
 * event is ignored, so this service is inert for Express agents and when nothing is dialing.
 *
 * Hilt note: Hybrid constructor-injects sessionManager/stepsRepository/settingsRepository.
 * The framework instantiates accessibility services directly, so we reach the same singletons
 * via Kotlin objects (UssdSessionManager / UssdStepsRepository) and read the mode from
 * SessionBridge. Hybrid's onServiceConnected/onDestroy also post service health to an
 * AccessibilityRepository (W5 telemetry) — intentionally a no-op here, out of W3 scope.
 */
class UssdAccessibilityService : AccessibilityService() {
    private val TAG = "UssdA11yService"

    companion object {
        // Recognised dialog button labels (lowercase). Verbatim from Hybrid.
        private val BUTTON_TEXTS = listOf("send", "ok", "close", "cancel", "back", "got it", "done")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Only drive Advanced sessions; inert otherwise (Express agents / idle).
        if (SessionBridge.getProcessingMode(this) != "advanced") return
        if (!UssdSessionManager.isSessionActive()) return
        if (event == null) return
        if (!isUSSDWidget(event)) return

        if (hasInputField(event)) {
            if (!UssdStepsRepository.isEmpty()) {
                val step = UssdStepsRepository.pollStep() ?: return
                enterText(event, step)
                clickButton(event, "SEND")
            } else {
                // Input field present but no steps left → treat current text as the outcome.
                val response = getFinalResponse(event)
                dismissDialog(event)
                completeSession(response)
            }
        } else if (isFinalDialog(event)) {
            val response = getFinalResponse(event)
            clickFinalDialogButton(event)
            completeSession(response)
        }
        // No input field and not a final dialog → wait for the next event.
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Hybrid posts "connected" health to an AccessibilityRepository here (W5). No-op in W3.
        Log.d(TAG, "Accessibility service connected")
    }

    override fun onDestroy() {
        super.onDestroy()
        // Hybrid posts "disconnected" health here (W5). No-op in W3.
        Log.d(TAG, "Accessibility service destroyed")
    }

    // ── Session completion (Advanced SUCCESS/FAILED rule) ─────────────────────────────
    private fun completeSession(response: String) {
        if (UssdUtils.isSuccessfulResponse(response)) {
            UssdSessionManager.completeSession(UssdSessionState.Success(response))
        } else {
            UssdSessionManager.completeSession(UssdSessionState.Failure(response))
        }
    }

    // ── Text entry: try ACTION_SET_TEXT, fall back to clipboard paste (verbatim) ──────
    private fun enterText(event: AccessibilityEvent, text: String) {
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        for (node in getNodes(event)) {
            if (node.isEditable && node.isFocusable && node.isEnabled) {
                if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("text", text))
                    node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                }
                break
            }
        }
    }

    // ── Button taps (verbatim): SEND → last button, CANCEL → second-to-last ───────────
    private fun clickButton(event: AccessibilityEvent, label: String) {
        val buttons = getNodes(event).filter { isButton(it) }
        if (buttons.isEmpty()) return
        when (label) {
            "SEND" -> buttons.lastOrNull()?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            "CANCEL" -> if (buttons.size > 1) {
                buttons[buttons.size - 2].performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }
    }

    /** Final (single-button) dialog → click the first/only button. */
    private fun clickFinalDialogButton(event: AccessibilityEvent) {
        getNodes(event).firstOrNull { isButton(it) }?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    /** Dismiss every recognised button on the current event's dialog (verbatim). */
    private fun dismissDialog(event: AccessibilityEvent) {
        getNodes(event).asSequence()
            .filter { isButton(it) }
            .filter { node ->
                BUTTON_TEXTS.any { bt ->
                    node.text?.toString()?.lowercase(Locale.getDefault())?.contains(bt) == true
                }
            }
            .forEach { it.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
    }

    /**
     * Hybrid-parity helper: dismiss buttons on the *active window root* (not a specific event).
     * Currently only the event-based dismissDialog is used by the state machine; this mirrors
     * Hybrid's surface and may be wired by a later wave.
     */
    @Suppress("unused")
    private fun dismissCurrentDialog() {
        val root = rootInActiveWindow ?: return
        val nodes = mutableListOf<AccessibilityNodeInfo>()
        extractNodes(nodes, root)
        nodes.asSequence()
            .filter { isButton(it) }
            .filter { node ->
                BUTTON_TEXTS.any { bt ->
                    node.text?.toString()?.lowercase(Locale.getDefault())?.contains(bt) == true
                }
            }
            .forEach { it.performAction(AccessibilityNodeInfo.ACTION_CLICK) }
    }

    // ── Dialog inspection helpers (all verbatim from Hybrid) ──────────────────────────

    private fun isButton(node: AccessibilityNodeInfo): Boolean {
        val cls = node.className?.toString()?.lowercase(Locale.getDefault()) ?: return false
        return cls.contains("button")
    }

    private fun hasInputField(event: AccessibilityEvent): Boolean =
        getNodes(event).any { it.isEditable && it.isFocusable && it.isEnabled }

    /** A "final" USSD dialog has exactly one button (no input + just an acknowledge button). */
    private fun isFinalDialog(event: AccessibilityEvent): Boolean =
        getNodes(event).count { isButton(it) } == 1

    /** A dialog is a USSD widget if any of its texts is exactly a known button label. */
    private fun isUSSDWidget(event: AccessibilityEvent): Boolean =
        collectAllTexts(event).any { it.lowercase(Locale.getDefault()) in BUTTON_TEXTS }

    /** The response text = all dialog texts minus button labels, joined and trimmed. */
    private fun getFinalResponse(event: AccessibilityEvent): String =
        collectAllTexts(event)
            .filterNot { it.lowercase(Locale.getDefault()).trim() in BUTTON_TEXTS }
            .joinToString(" ")
            .trim()

    /**
     * Gather every visible text from three sources, de-duplicated (verbatim from Hybrid):
     *   1. event.text
     *   2. the active-window root node tree (text + contentDescription + hintText)
     *   3. the event source node tree (text + contentDescription + hintText)
     */
    private fun collectAllTexts(event: AccessibilityEvent): List<String> {
        val eventTexts = event.text.map { it.toString().trim() }.filter { it.isNotEmpty() }

        val rootTexts = mutableListOf<String>()
        rootInActiveWindow?.let { root ->
            val nodes = mutableListOf<AccessibilityNodeInfo>()
            extractNodes(nodes, root)
            for (n in nodes) {
                n.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { rootTexts.add(it) }
                n.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { rootTexts.add(it) }
                n.hintText?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { rootTexts.add(it) }
            }
        }

        val sourceTexts = mutableListOf<String>()
        for (n in getNodes(event)) {
            n.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { sourceTexts.add(it) }
            n.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { sourceTexts.add(it) }
            n.hintText?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { sourceTexts.add(it) }
        }

        return (eventTexts + rootTexts + sourceTexts).filter { it.isNotEmpty() }.distinct()
    }

    /** All nodes reachable from the event's source. */
    private fun getNodes(event: AccessibilityEvent): List<AccessibilityNodeInfo> {
        val nodes = mutableListOf<AccessibilityNodeInfo>()
        event.source?.let { extractNodes(nodes, it) }
        return nodes
    }

    /** Depth-first flatten of a node subtree. */
    private fun extractNodes(out: MutableList<AccessibilityNodeInfo>, node: AccessibilityNodeInfo) {
        out.add(node)
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { extractNodes(out, it) }
        }
    }
}