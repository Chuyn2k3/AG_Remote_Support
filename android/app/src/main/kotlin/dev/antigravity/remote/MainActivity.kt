package dev.antigravity.remote

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val LIFECYCLE_CHANNEL = "dev.antigravity.remote/app_lifecycle"
        const val BUBBLE_CHANNEL = "dev.antigravity.remote/floating_bubble"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. App Lifecycle Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIFECYCLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    "bringToFront" -> {
                        val intent = Intent(applicationContext, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Native Floating Bubble & Foreground Watcher Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BUBBLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(this))
                        } else {
                            result.success(true)
                        }
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.canDrawOverlays(this)) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(false)
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "showBubble" -> {
                        val title = call.argument<String>("title") ?: "AG Remote"
                        val status = call.argument<String>("status") ?: "online"
                        val intent = Intent(this, FloatingHeadService::class.java).apply {
                            action = FloatingHeadService.ACTION_START
                            putExtra(FloatingHeadService.EXTRA_TITLE, title)
                            putExtra(FloatingHeadService.EXTRA_STATUS, status)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "updateBubbleStatus" -> {
                        val status = call.argument<String>("status") ?: "online"
                        val intent = Intent(this, FloatingHeadService::class.java).apply {
                            action = FloatingHeadService.ACTION_UPDATE_STATUS
                            putExtra(FloatingHeadService.EXTRA_STATUS, status)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "hideBubble" -> {
                        val intent = Intent(this, FloatingHeadService::class.java).apply {
                            action = FloatingHeadService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "isBubbleShowing" -> {
                        result.success(FloatingHeadService.isRunning)
                    }
                    "startForegroundWatcher" -> {
                        val title = call.argument<String>("title") ?: "Antigravity Session"
                        val intent = Intent(this, ForegroundWatcherService::class.java).apply {
                            action = ForegroundWatcherService.ACTION_START
                            putExtra(ForegroundWatcherService.EXTRA_TITLE, title)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopForegroundWatcher" -> {
                        val intent = Intent(this, ForegroundWatcherService::class.java).apply {
                            action = ForegroundWatcherService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
