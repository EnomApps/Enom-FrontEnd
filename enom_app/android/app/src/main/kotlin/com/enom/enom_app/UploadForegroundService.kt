package com.enom.enom_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that owns the upload progress notification.
 *
 * Why native instead of a Flutter plugin: this is the only way to show a real
 * determinate progress bar (NotificationCompat.setProgress) on a foreground
 * service notification, keep it truly un-swipeable, and keep the app process
 * alive so an in-flight upload survives the user swiping the app away.
 *
 * Lifecycle (driven by Dart UploadManager over a MethodChannel):
 *  - start: startForegroundService → onStartCommand → startForeground. Must be
 *    called while the app is foreground (Android 12+ forbids starting an FGS
 *    from the background). The Dart side guarantees this — the first progress
 *    tick fires synchronously off the user's "post" tap.
 *  - update: the running notification is refreshed via NotificationManager
 *    .notify() straight from MainActivity (background-safe), NOT a fresh
 *    startForegroundService call (which would throw in the background).
 *  - stop: stopService → notification removed.
 */
class UploadForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "enom_upload_progress"
        const val CHANNEL_NAME = "Post Upload"
        const val NOTIF_ID = 9000
        const val ACTION_START = "com.enom.enom_app.upload.START"
        const val ACTION_STOP = "com.enom.enom_app.upload.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_INDETERMINATE = "indeterminate"

        /** Builds the progress notification. Shared by the service (start) and
         *  by MainActivity (background-safe updates via NotificationManager). */
        fun buildNotification(
            context: Context,
            title: String,
            text: String,
            progress: Int,
            indeterminate: Boolean,
        ): Notification {
            createChannel(context)

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            val contentIntent = launchIntent?.let {
                PendingIntent.getActivity(
                    context,
                    0,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setProgress(100, progress, indeterminate)
                .apply { if (contentIntent != null) setContentIntent(contentIntent) }
                .build()
        }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    val channel = NotificationChannel(
                        CHANNEL_ID,
                        CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply { setShowBadge(false) }
                    nm.createNotificationChannel(channel)
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Uploading post"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0
        val indeterminate = intent?.getBooleanExtra(EXTRA_INDETERMINATE, false) ?: false

        val notification = buildNotification(this, title, text, progress, indeterminate)
        // On Android 10+ the foreground service type must be supplied at
        // startForeground time and match the manifest (dataSync). START_NOT_STICKY:
        // if the OS kills us mid-upload we don't want a zombie service with no
        // work — the Dart side drives uploads, not the service.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
        return START_NOT_STICKY
    }
}
