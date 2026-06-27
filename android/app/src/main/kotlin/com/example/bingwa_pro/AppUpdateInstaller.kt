// C:\bingwa_pro\android\app\src\main\kotlin\com\example\bingwa_pro\AppUpdateInstaller.kt
package com.example.bingwa_pro

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File

/**
 * W5.H — in-app APK update install (port of Hybrid's AppUpdateRepositoryImpl/DownloadReceiver).
 *
 * Flow: delete any old app_update.apk → DownloadManager.enqueue(apkUrl) → on completion the
 * registered receiver installs it via FileProvider + ACTION_VIEW (mime
 * application/vnd.android.package-archive). The APK is hosted on YOUR deployment (D-W5-3);
 * the client only points at the URL the version endpoint advertises.
 *
 * On Android 8+ installing requires the per-app "install unknown apps" permission; the Dart
 * UI gates on [canInstallUnknownSources] and sends the user to [openInstallSettings] first.
 */
object AppUpdateInstaller {
    private const val TAG = "AppUpdate"
    private const val APK_NAME = "app_update.apk"

    /** Whether this app may install APKs (always true pre-Android 8). */
    fun canInstallUnknownSources(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()

    /** Open the system "install unknown apps" screen for this package. */
    fun openInstallSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    /** Download [apkUrl] to the app's external files dir and install it on completion. */
    fun downloadAndInstall(context: Context, apkUrl: String) {
        val appCtx = context.applicationContext
        Log.d(TAG, "Updating app from URL: $apkUrl")

        // Delete the previous download so a stale APK is never installed.
        val dest = File(
            appCtx.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
            APK_NAME,
        )
        if (dest.exists() && dest.delete()) Log.d(TAG, "Old APK deleted")

        val dm = appCtx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(apkUrl))
            .setTitle("Downloading Update")
            .setDescription("Please wait…")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setMimeType("application/vnd.android.package-archive")
            .setDestinationInExternalFilesDir(
                appCtx,
                Environment.DIRECTORY_DOWNLOADS,
                APK_NAME,
            )
        val downloadId = dm.enqueue(request)

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                val completed =
                    intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
                if (completed != downloadId) return
                try {
                    appCtx.unregisterReceiver(this)
                } catch (_: Exception) {
                }
                installApk(appCtx, dest)
            }
        }
        // ACTION_DOWNLOAD_COMPLETE is a system broadcast → must be exported on Android 14+.
        ContextCompat.registerReceiver(
            appCtx,
            receiver,
            IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
            ContextCompat.RECEIVER_EXPORTED,
        )
    }

    private fun installApk(context: Context, file: File) {
        if (!file.exists()) {
            Log.e(TAG, "APK file not found!")
            return
        }
        Log.d(TAG, "Preparing to install apk file…")
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.provider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_ACTIVITY_NEW_TASK,
            )
        }
        context.startActivity(intent)
    }
}
