package dev.antigravity.remote

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
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class ForegroundWatcherService : Service() {

    companion object {
        const val CHANNEL_ID = "ag_foreground_watcher_channel"
        const val NOTIFICATION_ID = 20261
        const val ACTION_START = "dev.antigravity.remote.FOREGROUND_START"
        const val ACTION_STOP = "dev.antigravity.remote.FOREGROUND_STOP"
        const val EXTRA_TITLE = "extra_title"

        var isRunning = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Antigravity AI Background Watcher",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Duy trì kết nối và theo dõi phản hồi AI khi chạy ngầm"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                releaseWakeLock()
                stopForeground(true)
                stopSelf()
                isRunning = false
                return START_NOT_STICKY
            }
            else -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Phiên làm việc Antigravity"
                startForegroundWithNotification(title)
                acquireWakeLock()
                isRunning = true
            }
        }
        return START_STICKY
    }

    private fun startForegroundWithNotification(sessionTitle: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Antigravity AI đang chạy")
            .setContentText("$sessionTitle: Đang theo dõi phản hồi [Chạm để mở]")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "AGRemote::AiGenerationWakeLock"
                )
            }
            if (wakeLock?.isHeld != true) {
                // Tự động hết hạn sau 15 phút nếu có sự cố để bảo vệ pin máy
                wakeLock?.acquire(15 * 60 * 1000L)
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()
        isRunning = false
    }
}
