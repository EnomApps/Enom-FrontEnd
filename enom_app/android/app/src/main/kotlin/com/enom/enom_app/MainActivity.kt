package com.enom.enom_app

import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "enom/upload_fgs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // First tick of a batch: actually start the foreground
                    // service. Called while the app is foreground (off the
                    // user's "post" tap), which Android 12+ requires.
                    "start" -> {
                        val intent = Intent(this, UploadForegroundService::class.java).apply {
                            action = UploadForegroundService.ACTION_START
                            putExtra(UploadForegroundService.EXTRA_TITLE, call.argument<String>("title"))
                            putExtra(UploadForegroundService.EXTRA_TEXT, call.argument<String>("text"))
                            putExtra(UploadForegroundService.EXTRA_PROGRESS, call.argument<Int>("progress") ?: 0)
                            putExtra(
                                UploadForegroundService.EXTRA_INDETERMINATE,
                                call.argument<Boolean>("indeterminate") ?: false,
                            )
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    // Subsequent progress ticks: refresh the SAME notification id
                    // via NotificationManager. This is background-safe — unlike
                    // startForegroundService, which throws if the app has since
                    // gone to the background.
                    "update" -> {
                        val notification = UploadForegroundService.buildNotification(
                            this,
                            call.argument<String>("title") ?: "Uploading post",
                            call.argument<String>("text") ?: "",
                            call.argument<Int>("progress") ?: 0,
                            call.argument<Boolean>("indeterminate") ?: false,
                        )
                        NotificationManagerCompat.from(this)
                            .notify(UploadForegroundService.NOTIF_ID, notification)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, UploadForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
