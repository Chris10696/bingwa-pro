// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdSessionState.kt
package com.example.bingwa_pro

/**
 * W3.C — the terminal/!terminal states of an Advanced-mode USSD session, a verbatim
 * port of Hybrid's UssdSessionState. The accessibility service completes the session
 * with Success(response) or Failure(reason); the dialer coroutine awaits and maps that
 * to a UssdDialResult. Processing is the initial/in-flight marker (unused by the await
 * path but kept for parity).
 */
sealed class UssdSessionState {
    data class Success(val response: String) : UssdSessionState()
    data class Failure(val reason: String) : UssdSessionState()
    data object Processing : UssdSessionState()
}