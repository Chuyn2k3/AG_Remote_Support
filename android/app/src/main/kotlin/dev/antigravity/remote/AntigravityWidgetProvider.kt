package dev.antigravity.remote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class AntigravityWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "antigravity_widget_prefs"
        const val KEY_SESSION_TITLE = "widget_session_title"
        const val KEY_STATUS = "widget_status"
        const val KEY_PREVIEW = "widget_preview"
        const val KEY_UPDATED_AT = "widget_updated_at"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val title = prefs.getString(KEY_SESSION_TITLE, "Antigravity Desktop") ?: "Antigravity Desktop"
            val status = prefs.getString(KEY_STATUS, "idle") ?: "idle"
            val preview = prefs.getString(KEY_PREVIEW, "Sẵn sàng làm việc với Antigravity 2.0") ?: "Sẵn sàng"
            val updatedAt = prefs.getString(KEY_UPDATED_AT, "Vừa cập nhật") ?: "Vừa cập nhật"

            val views = RemoteViews(context.packageName, R.layout.widget_agent_feed)
            views.setTextViewText(R.id.widget_session_title, title)
            views.setTextViewText(R.id.widget_preview_text, preview)
            views.setTextViewText(R.id.widget_updated_at, updatedAt)

            // Cập nhật trạng thái màu sắc
            when (status.lowercase()) {
                "thinking", "generating", "streaming" -> {
                    views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_status_dot_yellow)
                    views.setTextViewText(R.id.widget_status_text, "Đang xử lý...")
                    views.setTextColor(R.id.widget_status_text, 0xFFFF9F0A.toInt())
                }
                "action_required", "waiting_approval" -> {
                    views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_status_dot_red)
                    views.setTextViewText(R.id.widget_status_text, "Chờ duyệt")
                    views.setTextColor(R.id.widget_status_text, 0xFFFF453A.toInt())
                }
                "offline", "disconnected" -> {
                    views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_status_dot_red)
                    views.setTextViewText(R.id.widget_status_text, "Ngoại tuyến")
                    views.setTextColor(R.id.widget_status_text, 0xFF8E8E93.toInt())
                }
                else -> {
                    views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_status_dot_green)
                    views.setTextViewText(R.id.widget_status_text, "Sẵn sàng")
                    views.setTextColor(R.id.widget_status_text, 0xFF34C759.toInt())
                }
            }

            // 1. Chạm vào thân Widget -> Mở MainActivity
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingAppIntent = PendingIntent.getActivity(
                context, 0, appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingAppIntent)

            // 2. Chạm nút Duyệt / Tiếp tục -> Gửi broadcast tới WidgetActionReceiver
            val actionIntent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_APPROVE
            }
            val pendingActionIntent = PendingIntent.getBroadcast(
                context, 101, actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_widget_approve, pendingActionIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AntigravityWidgetProvider::class.java))
            for (id in ids) {
                updateAppWidget(context, manager, id)
            }
        }
    }
}
