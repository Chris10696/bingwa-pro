package com.example.bingwa_pro

import android.content.Context
import android.provider.Settings
import android.util.Log

/**
 * W5.D — clock gate (Hybrid DeviceTimeAutoCheck / DialUssdUseCase.verifyAutomaticDateAndTimeEnabled).
 *
 * The USSD pipeline's scheduling, timeout, and recurrence anchors all depend on a correct clock,
 * so Hybrid refuses to dial when the device's automatic date & time is OFF. We mirror that gate.
 * Fail-OPEN on any read error — missing a real dial is worse than a rare false-negative on an OEM
 * that hides the AUTO_TIME setting.
 */
object DeviceTimeCheck {
    private const val TAG = "DeviceTimeCheck"

    // Verbatim Hybrid DeviceTimeAutoCheck message (do not reword).
    const val INACCURATE_MESSAGE =
        "Your phone's date is inaccurate. Please adjust your date and time to keep enjoying the app"

    fun isAutoTimeEnabled(context: Context): Boolean = try {
        Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME, 1) == 1
    } catch (e: Exception) {
        Log.w(TAG, "AUTO_TIME read failed (${e.message}) — failing open")
        true
    }
}
