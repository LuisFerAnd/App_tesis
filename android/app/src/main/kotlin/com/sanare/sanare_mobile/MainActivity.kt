package com.sanare.sanare_mobile

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.sanare.sanare_mobile/recording_service"
    private val notificationPermissionRequest = 7301
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRecordingService(result)
                    "stop" -> {
                        stopService(Intent(this, RecordingForegroundService::class.java))
                        result.success(null)
                    }
                    "isRunning" -> result.success(RecordingForegroundService.isRunning)
                    "notificationsEnabled" -> result.success(notificationsEnabled())
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startRecordingService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, RecordingForegroundService::class.java)
            ContextCompat.startForegroundService(this, intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("foreground_service_start_failed", error.javaClass.simpleName, null)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(notificationsEnabled())
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.success(false)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequest,
        )
    }

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequest) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingNotificationPermissionResult?.success(granted && notificationsEnabled())
        pendingNotificationPermissionResult = null
    }

    override fun onDestroy() {
        pendingNotificationPermissionResult?.success(false)
        pendingNotificationPermissionResult = null
        super.onDestroy()
    }
}
