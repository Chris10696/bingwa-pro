// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\SocketForegroundService.kt
package com.example.bingwa_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * W5.F.2 — foreground service that owns the HybridConnect socket lifecycle, ported from
 * Bingwa Hybrid's SocketForegroundService (rebranded to Nexus).
 *
 * Started/stopped from Dart (W5.F.3's "Hybrid Portal" toggle) via the bingwa_pro/socket
 * channel → [start]/[stop]. Runs as foregroundServiceType="dataSync" (same type as
 * UssdExecutionService; Hybrid's socket FGS is also a keep-alive, not a phone-call type)
 * so the connection survives Doze with the battery-optimisation exemption already requested.
 *
 * Notification copy + channel match Hybrid verbatim except the Nexus rebrand of the title.
 * Intent actions keep Hybrid's CONNECT/DISCONNECT shape under Pro's package id.
 */
class SocketForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "socket_channel"
        private const val NOTIFICATION_ID = 1002 // Hybrid's socket-FGS id; distinct from UssdExecutionService's
        const val ACTION_CONNECT = "com.example.bingwa_pro.CONNECT"
        const val ACTION_DISCONNECT = "com.example.bingwa_pro.DISCONNECT"
        const val EXTRA_CONNECT_ID = "connectId"

        /** Start the FGS and connect the socket for [connectId]. */
        fun start(context: Context, connectId: String) {
            val intent = Intent(context, SocketForegroundService::class.java).apply {
                action = ACTION_CONNECT
                putExtra(EXTRA_CONNECT_ID, connectId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Disconnect the socket and stop the FGS. */
        fun stop(context: Context) {
            val intent = Intent(context, SocketForegroundService::class.java).apply {
                action = ACTION_DISCONNECT
            }
            // Delivered to onStartCommand, which disconnects + stops the service itself.
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val connectId = intent.getStringExtra(EXTRA_CONNECT_ID) ?: ""
                SocketService.connect(applicationContext, connectId)
            }
            ACTION_DISCONNECT -> {
                SocketService.disconnect()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        // Keep the connection alive across process pressure; a sticky restart with no
        // action just re-shows the notification (the socket reconnects on demand).
        return START_STICKY
    }

    override fun onDestroy() {
        SocketService.disconnect()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bingwa Nexus")
            .setContentText("Keeping you connected…")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Socket Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the socket connection alive"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
