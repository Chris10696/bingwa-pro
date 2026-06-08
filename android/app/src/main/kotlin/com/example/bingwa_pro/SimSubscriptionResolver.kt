// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SimSubscriptionResolver.kt
package com.example.bingwa_pro

import android.content.Context
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import android.util.Log

/**
 * W3.F — resolves the configured SIM (slot) to the platform identifiers the dial and SMS
 * paths need. Verbatim behavioral port of Hybrid's SubscriptionIdFetcherUseCase private
 * resolvers (getSubscriptionIdForSimSlot / getPhoneAccountHandleForSimSlot) + the slot
 * selection logic in its three public getters.
 *
 * Hybrid model (confirmed from bytecode): SIM choice is stored as booleans, not a SimCard
 * enum. Slot is 1-based; the active subscription for a slot is
 *   SubscriptionManager.getActiveSubscriptionInfoList()[slot - 1]
 * (so slot 1 → index 0). From the SubscriptionInfo:
 *   - subscriptionId → used by SmsManager (auto-reply) and TelephonyManager.sendUssdRequest (Express)
 *   - iccId → matched (contains) against TelecomManager.getCallCapablePhoneAccounts()[].id
 *             to find the dial PhoneAccountHandle (Advanced + Express ACTION_CALL fallback)
 *
 * Slot selection (Hybrid):
 *   dial slot = DIAL_USSD_VIA_SIM_2 ? 2 : 1
 *   sms  slot = SEND_SMS_VIA_SIM_2  ? 2 : 1
 *   receive   = { 1 if RECEIVE_PAYMENTS_VIA_SIM_1, 2 if RECEIVE_PAYMENTS_VIA_SIM_2 }  (set)
 *
 * Single-SIM: only slot 1 has an active sub; defaults select SIM 1 everywhere, so this
 * resolves to the lone SIM. A slot-2 lookup with no SIM-2 returns null → callers fall back
 * to the platform default (dial) rather than throwing (Hybrid throws; we prefer the safer
 * non-throwing fallback so a misconfiguration never hard-fails a dial — see callers).
 *
 * Permissions: getActiveSubscriptionInfoList needs READ_PHONE_STATE (already granted for the
 * SMS pipeline). On SecurityException / null list we return null and let callers fall back.
 */
object SimSubscriptionResolver {
    private const val TAG = "SimResolver"

    /** Slot (1-based) selected for dialing USSD. */
    private fun dialSlot(context: Context): Int =
        if (SessionBridge.getDialUssdViaSim2(context)) 2 else 1

    /** Slot (1-based) selected for sending auto-replies. */
    private fun smsSlot(context: Context): Int =
        if (SessionBridge.getSendSmsViaSim2(context)) 2 else 1

    /**
     * The subscription id for the dial SIM, or null if that slot has no active SIM.
     * Used by Express's sendUssdRequest path (TelephonyManager.createForSubscriptionId).
     */
    fun dialSubId(context: Context): Int? = subscriptionIdForSlot(context, dialSlot(context))

    /**
     * The PhoneAccountHandle for the dial SIM, or null if it can't be resolved. Used by the
     * ACTION_CALL dial (Advanced always; Express OEM/<26 fallback) as EXTRA_PHONE_ACCOUNT_HANDLE.
     */
    fun dialPhoneAccountHandle(context: Context): PhoneAccountHandle? =
        phoneAccountHandleForSlot(context, dialSlot(context))

    /**
     * The subscription id for the auto-reply SIM, or null if that slot has no active SIM.
     * Used by AutoReplySender (SmsManager.createForSubscriptionId).
     */
    fun smsSubId(context: Context): Int? = subscriptionIdForSlot(context, smsSlot(context))

    /**
     * The set of 1-based slots whose incoming SMS the agent allows processing
     * (RECEIVE_PAYMENTS_VIA_SIM_1/2). Mirrors Hybrid's validateEnabledSimCards allowed-set.
     */
    fun receivePaymentsAllowedSlots(context: Context): Set<Int> {
        val s = mutableSetOf<Int>()
        if (SessionBridge.getReceivePaymentsViaSim1(context)) s.add(1)
        if (SessionBridge.getReceivePaymentsViaSim2(context)) s.add(2)
        return s
    }

    // ── Verbatim resolvers ────────────────────────────────────────────────────────────

    /** SubscriptionManager.getActiveSubscriptionInfoList()[slot-1].subscriptionId, or null. */
    private fun subscriptionIdForSlot(context: Context, slot: Int): Int? {
        return try {
            val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                ?: return null
            @Suppress("MissingPermission")
            val subs = sm.activeSubscriptionInfoList ?: return null
            subs.getOrNull(slot - 1)?.subscriptionId
        } catch (e: SecurityException) {
            Log.e(TAG, "subscriptionIdForSlot($slot): missing READ_PHONE_STATE: ${e.message}")
            null
        } catch (e: Exception) {
            Log.e(TAG, "subscriptionIdForSlot($slot) error: ${e.message}")
            null
        }
    }

    /**
     * The call-capable PhoneAccountHandle whose id contains the slot's SIM iccId, or null.
     * Verbatim from Hybrid getPhoneAccountHandleForSimSlot.
     */
    private fun phoneAccountHandleForSlot(context: Context, slot: Int): PhoneAccountHandle? {
        return try {
            val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                ?: return null
            val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                ?: return null
            @Suppress("MissingPermission")
            val subs = sm.activeSubscriptionInfoList ?: return null
            val info = subs.getOrNull(slot - 1) ?: return null
            val iccId = info.iccId ?: return null
            @Suppress("MissingPermission")
            val handles = telecom.callCapablePhoneAccounts ?: return null
            handles.firstOrNull { it.id.contains(iccId) }
        } catch (e: SecurityException) {
            Log.e(TAG, "phoneAccountHandleForSlot($slot): permission denied: ${e.message}")
            null
        } catch (e: Exception) {
            Log.e(TAG, "phoneAccountHandleForSlot($slot) error: ${e.message}")
            null
        }
    }

    // ── SIM info for the setup screen ───────────────────────────────────────────────────

    /** A single active SIM's slot + display label, for the SIM-setup UI. */
    data class SimInfo(val slot: Int, val label: String)

    /**
     * Active SIMs as (slot, label) for the SIM-setup screen. slot is 1-based (simSlotIndex+1);
     * label is the carrier display name (falls back to "SIM N"). Empty if none / no permission.
     */
    fun getSimInfo(context: Context): List<SimInfo> {
        return try {
            val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                ?: return emptyList()
            @Suppress("MissingPermission")
            val subs = sm.activeSubscriptionInfoList ?: return emptyList()
            subs.map { info ->
                val slot = info.simSlotIndex + 1
                val name = info.displayName?.toString()?.takeIf { it.isNotBlank() } ?: "SIM $slot"
                SimInfo(slot = slot, label = name)
            }.sortedBy { it.slot }
        } catch (e: SecurityException) {
            Log.e(TAG, "getSimInfo: missing READ_PHONE_STATE: ${e.message}")
            emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "getSimInfo error: ${e.message}")
            emptyList()
        }
    }
}