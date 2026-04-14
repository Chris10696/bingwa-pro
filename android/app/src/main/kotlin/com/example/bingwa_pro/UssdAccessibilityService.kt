// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdAccessibilityService.kt
package com.example.bingwa_pro

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Bundle  // ADD THIS MISSING IMPORT
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class UssdAccessibilityService : AccessibilityService() {
    private val TAG = "UssdAccessibility"
    private val handler = Handler(Looper.getMainLooper())
    private var currentSessionId: String? = null
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        setServiceInfo(info)
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val packageName = event.packageName?.toString() ?: return
                
                // Check if this is a USSD window
                if (packageName.contains("com.android.phone") || 
                    packageName.contains("com.sec.android.app") ||
                    packageName.contains("telephony")) {
                    
                    Log.d(TAG, "USSD window detected: $packageName")
                    handleUssdWindow(event)
                }
            }
        }
    }
    
    private fun handleUssdWindow(event: AccessibilityEvent) {
        val root = rootInActiveWindow ?: return
        
        // Find the USSD message text
        val messageNode = findMessageNode(root)
        if (messageNode != null) {
            val messageText = messageNode.text?.toString() ?: ""
            Log.d(TAG, "USSD Message: $messageText")
            
            // Parse the response
            when {
                messageText.contains("CON") -> {
                    // Need user input - we can automate based on context
                    handleContinuation(messageText, root)
                }
                messageText.contains("END") -> {
                    // Session ended
                    Log.d(TAG, "USSD session ended")
                    currentSessionId = null
                }
                messageText.contains("Enter") || messageText.contains("Select") -> {
                    // Need input - send appropriate response
                    handleInputRequired(messageText, root)
                }
            }
        }
    }
    
    private fun findMessageNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // Look for text in the window
        if (node.text != null && node.text!!.isNotEmpty()) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findMessageNode(child)
            if (result != null) return result
            child.recycle()
        }
        
        return null
    }
    
    private fun handleContinuation(message: String, root: AccessibilityNodeInfo) {
        // For advanced USSD, we may need to send specific inputs
        // This is where you'd map the response to the next step
        Log.d(TAG, "USSD continuation needed: $message")
    }
    
    private fun handleInputRequired(message: String, root: AccessibilityNodeInfo) {
        // Find input field and send appropriate response
        val inputField = findInputField(root)
        if (inputField != null) {
            // Determine what input to send based on context
            val response = determineResponse(message)
            if (response != null) {
                setText(inputField, response)
                performAction(inputField, AccessibilityNodeInfo.ACTION_FOCUS)
                performAction(inputField, AccessibilityNodeInfo.ACTION_CLICK)
            }
        }
    }
    
    private fun findInputField(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) return node
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findInputField(child)
            if (result != null) return result
            child.recycle()
        }
        
        return null
    }
    
    private fun determineResponse(message: String): String? {
        // Map USSD message to appropriate response
        return when {
            message.contains("1. Buy Airtime") -> "1"
            message.contains("2. Buy Data") -> "2"
            message.contains("3. Buy SMS") -> "3"
            message.contains("4. Check Balance") -> "4"
            message.contains("Confirm") -> "1"
            else -> null
        }
    }
    
    private fun setText(node: AccessibilityNodeInfo, text: String) {
        val arguments = Bundle()
        arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
    }
    
    private fun performAction(node: AccessibilityNodeInfo, action: Int) {
        node.performAction(action)
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }
}