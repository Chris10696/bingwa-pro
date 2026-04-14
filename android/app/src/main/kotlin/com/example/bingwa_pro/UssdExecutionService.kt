package com.example.bingwa_pro

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class UssdExecutionService : Service() {

    private val TAG = "UssdService"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "bingwa_ussd_channel"

    companion object {
        // Allows MainActivity to accurately report whether the service is running
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "USSD Execution Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "USSD Execution Service started")
        isRunning = true
        startForeground(NOTIFICATION_ID, createNotification())
        Log.d(TAG, "Foreground service active — M-PESA receiver is live via manifest")
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bingwa Pro USSD Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service for processing USSD transactions"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bingwa Pro")
            .setContentText("Monitoring M-PESA payments...")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        Log.d(TAG, "USSD Execution Service destroyed")
    }
}