// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\UssdEngine.kt
package com.example.bingwa_pro

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

// ─── dryRun parameter ────────────────────────────────────────────────────────
// dryRun = true  → every executeXxxUssd() logs what it would dial but never
//                  opens the dialler. Safe when airtime is zero.
// dryRun = false → real execution (default for production).
//
// MainActivity always passes dryRun = true when the call originates from the
// Flutter test-injection button so engineers can watch the full pipeline in
// Logcat without touching the dialler or needing airtime.
// ─────────────────────────────────────────────────────────────────────────────
class UssdEngine(
    private val context: Context,
    private val dryRun: Boolean = false
) {
    private val TAG = "UssdEngine"
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── USSD route table ─────────────────────────────────────────────────────
    // priceCents is the M-PESA payment amount × 100.
    // e.g. KES 20.00 → priceCents = 2000
    // The "@" placeholder in template is replaced by the customer phone number.
    // ─────────────────────────────────────────────────────────────────────────
    private val ussdRoutes = listOf(
        // ── SMS Bundles ──────────────────────────────────────────────────────
        UssdRoute("20sms_valid_24hrs",      "*188*10*1*1*@*1*2#",           500, "SMS",     "ADVANCED"),
        UssdRoute("200sms_valid_24hrs",     "*188*10*1*2*@*1*2#",          1000, "SMS",     "ADVANCED"),
        UssdRoute("1000sms_valid_7days",    "*188*10*2*2*@*1*2#",          3000, "SMS",     "ADVANCED"),

        // ── DATA Bundles – EXPRESS ────────────────────────────────────────────
        UssdRoute("1gb_1hr",               "*180*5*2*@*5*1#",              1900, "DATA",    "EXPRESS"),
        UssdRoute("250mb_24hrs",           "*180*5*2*@*6*1#",              2000, "DATA",    "EXPRESS"),
        UssdRoute("350mb_7days",           "*180*5*2*@*2*1#",              4700, "DATA",    "EXPRESS"),
        UssdRoute("1_5gb_3hrs",            "*180*5*2*@*1*1#",              4900, "DATA",    "EXPRESS"),
        UssdRoute("1_5gb_3hrs_v2",         "*180*5*2*@*1*1#",              5000, "DATA",    "EXPRESS"),
        UssdRoute("1_25gb_midnight",       "*180*5*2*@*8*1#",              5500, "DATA",    "EXPRESS"),
        UssdRoute("1gb_24hrs",             "*180*5*2*@*7*1#",              9900, "DATA",    "EXPRESS"),

        // ── DATA Bundles – ADVANCED ───────────────────────────────────────────
        UssdRoute("1gb_1hr_many",          "*544*98*13*3*2*@*1*1#",        2300, "DATA",    "ADVANCED"),
        UssdRoute("1_5gb_3hrs_many",       "*544*98*13*3*3*@*1*1#",        5300, "DATA",    "ADVANCED"),
        UssdRoute("2gb_24hrs_many",        "*544*98*13*3*1*@*1*1#",       11000, "DATA",    "ADVANCED"),

        // ── MINUTES Bundles ───────────────────────────────────────────────────
        UssdRoute("350_flex",              "*444*5*5*1*3*@*2*1#",          2100, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v2",           "*444*5*5*1*3*@*2*1#",          2200, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v3",           "*444*5*5*1*3*@*2*1#",          2400, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v4",           "*444*5*5*1*3*@*2*1#",          2500, "MINUTES", "ADVANCED"),
        UssdRoute("350_flex_v5",           "*444*5*5*1*3*@*2*1#",          2600, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_midnight",       "*444*5*7*7*3*@*2*1*1#",        5100, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_v1",             "*444*5*7*7*3*@*2*1*1#",        5200, "MINUTES", "ADVANCED"),
        UssdRoute("50mins_v3",             "*444*5*7*7*3*@*2*1*1#",        5400, "MINUTES", "ADVANCED"),
    )

    // ── Public API ───────────────────────────────────────────────────────────

    fun findUssdRouteByPrice(priceCents: Int): UssdRoute? =
        ussdRoutes.find { it.priceCents == priceCents }

    fun buildUssdCode(route: UssdRoute, customerPhone: String): String {
        var code = route.template.replace("@", customerPhone)
        if (!code.endsWith("#")) code += "#"
        return code
    }

    // ── Entry point called by MpesaMessageListener AND the test channel ──────
    // Parses the SMS body → matches a route → builds the USSD code → executes
    // (or dry-runs). This is the single authoritative pipeline for both paths.
    suspend fun processPaymentSms(body: String) {
        val info = parseMpesaMessage(body)
        if (info == null) {
            Log.w(TAG, "processPaymentSms: could not parse — raw body:\n$body")
            return
        }

        Log.d(TAG, "Payment parsed — Amount: ${info.amount} cents | Customer: ${info.customerPhone}")

        val route = findUssdRouteByPrice(info.amount)
        if (route == null) {
            Log.w(
                TAG, "No route matched ${info.amount} cents. " +
                "Defined prices: ${ussdRoutes.map { it.priceCents }.distinct().sorted()}"
            )
            return
        }

        Log.d(TAG, "Matched route: ${route.name} | Delivery: ${route.delivery}")

        val ussdCode = buildUssdCode(route, info.customerPhone)
        Log.d(TAG, "Final USSD code: $ussdCode")

        val success = if (route.delivery == "EXPRESS") {
            executeExpressUssd(ussdCode, info.customerPhone)
        } else {
            executeAdvancedUssd(ussdCode, info.customerPhone)
        }

        if (success) {
    Log.d(TAG, "✅ USSD delivered for ${info.customerPhone}")
    // Part 5 Step B — record on backend to prevent Flow 2 re-processing
    // Replace empty strings with values from SharedPreferences or passed context
    recordPaymentOnBackend(
        mpesaRef       = info.reference,
        amount         = info.amount,
        customerPhone  = info.customerPhone,
        agentId        = "",   // TODO: read from SharedPreferences
        authToken      = ""    // TODO: read from SecureStorage via MethodChannel
    )
} else {
    Log.e(TAG, "❌ USSD failed for ${info.customerPhone}")
}
    }

    // ── EXPRESS execution (direct Intent dial) ────────────────────────────────
    suspend fun executeExpressUssd(ussdCode: String, phoneNumber: String): Boolean =
        withContext(Dispatchers.IO) {
            try {
                val finalCode   = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
                val encodedCode = finalCode.replace("#", Uri.encode("#"))

                if (dryRun) {
                    Log.d(TAG, "🧪 DRY RUN — EXPRESS would dial: $finalCode for $phoneNumber")
                    Log.d(TAG, "🧪 Remove dryRun=true to execute for real.")
                    return@withContext true
                }

                val intent = Intent(Intent.ACTION_CALL).apply {
                    data  = Uri.parse("tel:$encodedCode")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                withContext(Dispatchers.Main) { context.startActivity(intent) }
                Log.d(TAG, "EXPRESS USSD executed: $finalCode")
                true
            } catch (e: Exception) {
                Log.e(TAG, "EXPRESS USSD failed: ${e.message}", e)
                false
            }
        }

    // ── ADVANCED execution (accessibility-service menu navigation) ────────────
    suspend fun executeAdvancedUssd(ussdCode: String, phoneNumber: String): Boolean =
        withContext(Dispatchers.IO) {
            try {
                val finalCode   = if (ussdCode.endsWith("#")) ussdCode else "$ussdCode#"
                val encodedCode = finalCode.replace("#", Uri.encode("#"))

                if (dryRun) {
                    Log.d(TAG, "🧪 DRY RUN — ADVANCED would dial: $finalCode for $phoneNumber")
                    Log.d(TAG, "🧪 Remove dryRun=true to execute for real.")
                    return@withContext true
                }

                val intent = Intent(Intent.ACTION_CALL).apply {
                    data  = Uri.parse("tel:$encodedCode")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                withContext(Dispatchers.Main) { context.startActivity(intent) }
                Log.d(TAG, "ADVANCED USSD initiated: $finalCode")
                true
            } catch (e: Exception) {
                Log.e(TAG, "ADVANCED USSD failed: ${e.message}", e)
                false
            }
        }

    fun cancelCurrentUssd() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    // ── SMS parser ────────────────────────────────────────────────────────────
    // Mirrors the patterns in MpesaMessageListener so both production and test
    // paths exercise identical parsing logic.

    private val confirmationPattern = Regex(
        """Confirmed\.\s+KES\s*([\d,]+\.?\d*)\s+received\s+from\s+[\w\s]+\s+(07\d{8}|2547\d{8}|01\d{8}|2541\d{8})""",
        RegexOption.IGNORE_CASE
    )
    private val fallbackPattern = Regex(
        """KES\s*([\d,]+\.?\d*)\s+(?:received\s+from|paid\s+by)\s+[\w\s]*?(07\d{8}|2547\d{8}|01\d{8}|2541\d{8})""",
        RegexOption.IGNORE_CASE
    )

    private fun parseMpesaMessage(body: String): MpesaPaymentInfo? {
        val match = confirmationPattern.find(body) ?: fallbackPattern.find(body)
        if (match == null) {
            Log.w(TAG, "parseMpesaMessage: no regex match")
            return null
        }

        val amountStr = match.groupValues[1].replace(",", "")
        val rawPhone  = match.groupValues[2]
        val amount    = amountStr.toDoubleOrNull() ?: run {
            Log.w(TAG, "parseMpesaMessage: bad amount string '$amountStr'")
            return null
        }

        val normalizedPhone = normalizePhone(rawPhone)
        val refMatch        = Regex("""^([A-Z0-9]{10})""").find(body.trim())
        val reference       = refMatch?.groupValues?.get(1) ?: "N/A"

        return MpesaPaymentInfo(
            amount        = (amount * 100).toInt(),
            customerPhone = normalizedPhone,
            reference     = reference,
            rawMessage    = body
        )
    }

    private fun normalizePhone(phone: String): String = when {
        phone.startsWith("2547") -> "0" + phone.substring(3)
        phone.startsWith("2541") -> "0" + phone.substring(3)
        else -> phone
    }

        // Call this AFTER successful USSD execution to prevent Flow 2 re-processing
    private suspend fun recordPaymentOnBackend(
        mpesaRef: String,
        amount: Int,
        customerPhone: String,
        agentId: String,
        authToken: String
    ) = withContext(Dispatchers.IO) {
        if (dryRun) {
            Log.d(TAG, "🧪 DRY RUN — skipping backend recording")
            return@withContext
        }
        try {
            val json = JSONObject().apply {
                put("mpesaTransactionId", mpesaRef)
                put("amount", amount / 100.0)
                put("customerPhone", customerPhone)
                put("agentId", agentId)
            }.toString()

            val client = OkHttpClient()
            val request = Request.Builder()
                .url("${BuildConfig.API_BASE_URL}/transactions/record-sms-payment")
                .addHeader("Authorization", "Bearer $authToken")
                .post(json.toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(request).execute()
            when (response.code) {
                201 -> Log.d(TAG, "✅ Payment recorded on backend: $mpesaRef")
                409 -> Log.w(TAG, "⚠️ Duplicate payment — already recorded: $mpesaRef")
                else -> Log.e(TAG, "Backend record failed: ${response.code}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "recordPaymentOnBackend error: ${e.message}", e)
            // Non-fatal — USSD already fired; don't crash the engine
        }
    }
}

// ── Data classes ──────────────────────────────────────────────────────────────

data class UssdRoute(
    val name:       String,
    val template:   String,
    val priceCents: Int,
    val category:   String,
    val delivery:   String
)