package dev.antigravity.remote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_APPROVE = "dev.antigravity.remote.ACTION_WIDGET_APPROVE"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_APPROVE) {
            // 1. Phản hồi tức thì lên Widget
            val prefs = context.getSharedPreferences(AntigravityWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(AntigravityWidgetProvider.KEY_STATUS, "generating")
                .putString(AntigravityWidgetProvider.KEY_PREVIEW, "⚡ Đang gửi lệnh tiếp tục tới Desktop...")
                .putString(AntigravityWidgetProvider.KEY_UPDATED_AT, "Vừa bấm")
                .apply()
            AntigravityWidgetProvider.updateAllWidgets(context)

            // 2. Chuyển tiếp callback cho Flutter thông qua MainActivity nếu đang chạy
            val dispatched = MainActivity.sendWidgetActionToFlutter("approve")
            if (!dispatched) {
                // Nếu app chưa ở memory, mở app lên
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("AUTO_APPROVE", true)
                }
                context.startActivity(launchIntent)
            } else {
                Toast.makeText(context, "Đã gửi lệnh tiếp tục tới Antigravity", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
