# Android Home Screen Widget (Live Agent Feed & Quick Actions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng Android Home Screen Widget kích thước 4x2 cells chuẩn Dark Glassmorphism, hiển thị Live Agent Feed thời gian thực và nút "⚡ Duyệt / Tiếp tục" thực thi ngầm < 100ms.

**Architecture:** Native Android `AppWidgetProvider` kết hợp `RemoteViews` giao tiếp hai chiều với Flutter thông qua `MethodChannel('dev.antigravity.remote/home_widget')`. Cập nhật trạng thái tức thì từ `RemoteScreen` sang Widget và truyền intent tương tác trực tiếp từ Widget vào `InAppWebView` để tiếp tục phiên làm việc mà không cần mở app.

**Tech Stack:** Kotlin, Android AppWidget framework, XML RemoteViews, Flutter MethodChannel, InAppWebView DOM injection.

---

### Task 1: Native Android Widget Layouts & Drawables

**Files:**
- Create: `android/app/src/main/res/drawable/widget_container_bg.xml`
- Create: `android/app/src/main/res/drawable/widget_btn_approve_bg.xml`
- Create: `android/app/src/main/res/drawable/widget_status_dot_green.xml`
- Create: `android/app/src/main/res/drawable/widget_status_dot_yellow.xml`
- Create: `android/app/src/main/res/drawable/widget_status_dot_red.xml`
- Create: `android/app/src/main/res/layout/widget_agent_feed.xml`
- Create: `android/app/src/main/res/xml/widget_agent_feed_info.xml`

- [x] **Step 1: Tạo các drawable bo góc và chấm trạng thái**
Tạo file `android/app/src/main/res/drawable/widget_container_bg.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="20dp" />
    <solid android:color="#16161A" />
    <stroke
        android:width="1dp"
        android:color="#26FFFFFF" />
</shape>
```

Tạo file `android/app/src/main/res/drawable/widget_btn_approve_bg.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="10dp" />
    <solid android:color="#0A84FF" />
</shape>
```

Tạo file `android/app/src/main/res/drawable/widget_status_dot_green.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <size android:width="8dp" android:height="8dp" />
    <solid android:color="#34C759" />
</shape>
```

Tạo file `android/app/src/main/res/drawable/widget_status_dot_yellow.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <size android:width="8dp" android:height="8dp" />
    <solid android:color="#FF9F0A" />
</shape>
```

Tạo file `android/app/src/main/res/drawable/widget_status_dot_red.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <size android:width="8dp" android:height="8dp" />
    <solid android:color="#FF453A" />
</shape>
```

- [x] **Step 2: Tạo layout XML cho RemoteViews của Widget**
Tạo file `android/app/src/main/res/layout/widget_agent_feed.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_container_bg"
    android:orientation="vertical"
    android:padding="14dp">

    <!-- Header: Icon, Session Title, Status -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <ImageView
            android:layout_width="16dp"
            android:layout_height="16dp"
            android:contentDescription="AG Logo"
            android:src="@mipmap/ic_launcher" />

        <TextView
            android:id="@+id/widget_session_title"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_marginStart="8dp"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:text="Antigravity Desktop"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold" />

        <ImageView
            android:id="@+id/widget_status_dot"
            android:layout_width="8dp"
            android:layout_height="8dp"
            android:layout_marginEnd="5dp"
            android:src="@drawable/widget_status_dot_green" />

        <TextView
            android:id="@+id/widget_status_text"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Sẵn sàng"
            android:textColor="#34C759"
            android:textSize="11sp"
            android:textStyle="bold" />
    </LinearLayout>

    <!-- Body: Live Feed Preview Text -->
    <TextView
        android:id="@+id/widget_preview_text"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_marginTop="8dp"
        android:layout_marginBottom="8dp"
        android:layout_weight="1"
        android:ellipsize="end"
        android:lineSpacingExtra="2dp"
        android:maxLines="3"
        android:text="Đang kết nối tới Antigravity Desktop..."
        android:textColor="#D1D1D6"
        android:textSize="12.5sp" />

    <!-- Footer: Approve Button & Updated Time -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <Button
            android:id="@+id/btn_widget_approve"
            android:layout_width="wrap_content"
            android:layout_height="32dp"
            android:background="@drawable/widget_btn_approve_bg"
            android:minWidth="0dp"
            android:minHeight="0dp"
            android:paddingStart="12dp"
            android:paddingEnd="12dp"
            android:text="⚡ Duyệt / Tiếp tục"
            android:textAllCaps="false"
            android:textColor="#FFFFFF"
            android:textSize="11.5sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_updated_at"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="end"
            android:text="Vừa cập nhật"
            android:textColor="#8E8E93"
            android:textSize="10sp" />
    </LinearLayout>
</LinearLayout>
```

- [x] **Step 3: Tạo AppWidgetProviderInfo XML metadata**
Tạo file `android/app/src/main/res/xml/widget_agent_feed_info.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/widget_agent_feed"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen">
</appwidget-provider>
```

- [x] **Step 4: Commit**
```bash
git add android/app/src/main/res/drawable/ android/app/src/main/res/layout/ android/app/src/main/res/xml/
git commit -m "feat(widget): add Android AppWidget XML layouts and glassmorphism drawables"
```

---

### Task 2: Native Kotlin Widget Provider & Action Receiver

**Files:**
- Create: `android/app/src/main/kotlin/dev/antigravity/remote/AntigravityWidgetProvider.kt`
- Create: `android/app/src/main/kotlin/dev/antigravity/remote/WidgetActionReceiver.kt`
- Modify: `android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [x] **Step 1: Viết `AntigravityWidgetProvider.kt`**
Tạo file `android/app/src/main/kotlin/dev/antigravity/remote/AntigravityWidgetProvider.kt`:
```kotlin
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
```

- [x] **Step 2: Viết `WidgetActionReceiver.kt`**
Tạo file `android/app/src/main/kotlin/dev/antigravity/remote/WidgetActionReceiver.kt`:
```kotlin
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
```

- [x] **Step 3: Cập nhật `MainActivity.kt` thêm `WIDGET_CHANNEL`**
Trong `android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt`:
Thêm channel:
```kotlin
    companion object {
        const val LIFECYCLE_CHANNEL = "dev.antigravity.remote/app_lifecycle"
        const val BUBBLE_CHANNEL = "dev.antigravity.remote/floating_bubble"
        const val SECURITY_CHANNEL = "dev.antigravity.remote/security"
        const val WIDGET_CHANNEL = "dev.antigravity.remote/home_widget"

        var widgetChannel: MethodChannel? = null

        fun sendWidgetActionToFlutter(action: String): Boolean {
            return if (widgetChannel != null) {
                widgetChannel?.invokeMethod("onWidgetAction", mapOf("action" to action))
                true
            } else {
                false
            }
        }
    }
```
Và trong `configureFlutterEngine`:
```kotlin
        // 3. Home Widget Channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val title = call.argument<String>("sessionTitle") ?: "Antigravity Desktop"
                    val status = call.argument<String>("status") ?: "idle"
                    val preview = call.argument<String>("preview") ?: ""
                    val updatedAt = call.argument<String>("updatedAt") ?: "Vừa cập nhật"

                    val prefs = getSharedPreferences(AntigravityWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(AntigravityWidgetProvider.KEY_SESSION_TITLE, title)
                        .putString(AntigravityWidgetProvider.KEY_STATUS, status)
                        .putString(AntigravityWidgetProvider.KEY_PREVIEW, preview)
                        .putString(AntigravityWidgetProvider.KEY_UPDATED_AT, updatedAt)
                        .apply()

                    AntigravityWidgetProvider.updateAllWidgets(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
```

- [x] **Step 4: Khai báo Receiver và AppWidgetProvider trong `AndroidManifest.xml`**
Trong `android/app/src/main/AndroidManifest.xml`, thêm vào trong `<application>`:
```xml
        <!-- Android Home Screen Widget Provider -->
        <receiver
            android:name=".AntigravityWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/widget_agent_feed_info" />
        </receiver>

        <!-- Widget Quick Action Broadcast Receiver -->
        <receiver
            android:name=".WidgetActionReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="dev.antigravity.remote.ACTION_WIDGET_APPROVE" />
            </intent-filter>
        </receiver>
```

- [x] **Step 5: Commit**
```bash
git add android/app/src/main/kotlin/ android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): implement AntigravityWidgetProvider and WidgetActionReceiver"
```

---

### Task 3: Flutter `HomeWidgetService` & Unit Tests

**Files:**
- Create: `lib/core/services/home_widget_service.dart`
- Create: `test/home_widget_service_test.dart`

- [x] **Step 1: Viết failing unit test cho `HomeWidgetService`**
Tạo file `test/home_widget_service_test.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeWidgetService service;
  final List<MethodCall> log = [];

  setUp(() {
    log.clear();
    service = HomeWidgetService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.antigravity.remote/home_widget'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'updateWidgetData') {
          return true;
        }
        return null;
      },
    );
  });

  test('updateWidgetFeed dispatches updateWidgetData method call with formatted arguments', () async {
    final result = await service.updateWidgetFeed(
      sessionTitle: 'MacBook Pro',
      status: 'generating',
      preview: 'Đang sửa file index.html',
    );

    expect(result, isTrue);
    expect(log.length, 1);
    expect(log.first.method, 'updateWidgetData');
    expect(log.first.arguments['sessionTitle'], 'MacBook Pro');
    expect(log.first.arguments['status'], 'generating');
    expect(log.first.arguments['preview'], 'Đang sửa file index.html');
  });

  test('updateWidgetFeed truncates preview text if longer than 150 characters', () async {
    final longText = 'A' * 200;
    await service.updateWidgetFeed(
      sessionTitle: 'Test Session',
      status: 'idle',
      preview: longText,
    );

    final String sentPreview = log.first.arguments['preview'] as String;
    expect(sentPreview.length, lessThanOrEqualTo(153));
    expect(sentPreview.endsWith('...'), isTrue);
  });

  test('registerActionListener triggers listener callback on onWidgetAction call', () {
    String? capturedAction;
    service.registerActionListener((action) {
      capturedAction = action;
    });

    service.handleActionFromPlatform('approve');
    expect(capturedAction, 'approve');
  });
}
```

- [x] **Step 2: Chạy test để xác nhận test fail**
```bash
flutter test test/home_widget_service_test.dart
```
Expected: FAIL (file `home_widget_service.dart` does not exist).

- [x] **Step 3: Viết triển khai `HomeWidgetService`**
Tạo file `lib/core/services/home_widget_service.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef WidgetActionCallback = void Function(String action);

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('dev.antigravity.remote/home_widget');

  WidgetActionCallback? _actionCallback;

  HomeWidgetService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onWidgetAction') {
      final args = call.arguments;
      final action = args is Map ? args['action']?.toString() : null;
      if (action != null) {
        handleActionFromPlatform(action);
      }
    }
  }

  @visibleForTesting
  void handleActionFromPlatform(String action) {
    _actionCallback?.call(action);
  }

  void registerActionListener(WidgetActionCallback callback) {
    _actionCallback = callback;
  }

  void unregisterActionListener() {
    _actionCallback = null;
  }

  Future<bool> updateWidgetFeed({
    required String sessionTitle,
    required String status,
    required String preview,
    String? updatedAt,
  }) async {
    try {
      String cleanPreview = preview.trim().replaceAll('\n', ' ');
      if (cleanPreview.length > 150) {
        cleanPreview = '${cleanPreview.substring(0, 147)}...';
      }

      final now = DateTime.now();
      final timeStr = updatedAt ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final result = await _channel.invokeMethod<bool>('updateWidgetData', {
        'sessionTitle': sessionTitle,
        'status': status,
        'preview': cleanPreview,
        'updatedAt': timeStr,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[HomeWidgetService] Error updating widget data: $e');
      return false;
    }
  }
}
```

- [x] **Step 4: Chạy lại test để xác nhận test pass**
```bash
flutter test test/home_widget_service_test.dart
```
Expected: PASS (all 3 tests pass).

- [x] **Step 5: Commit**
```bash
git add lib/core/services/home_widget_service.dart test/home_widget_service_test.dart
git commit -m "feat(widget): implement HomeWidgetService with unit tests"
```

---

### Task 4: Tích Hợp HomeWidgetService Vào RemoteScreen

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`

- [x] **Step 1: Khởi tạo HomeWidgetService và gắn listener trong `initState`**
Trong `lib/screens/remote/remote_screen.dart`:
Khởi tạo instance:
```dart
final HomeWidgetService _homeWidgetService = HomeWidgetService();
```
Trong `initState`:
```dart
    _homeWidgetService.registerActionListener((action) {
      if (action == 'approve') {
        _handleWidgetQuickApprove();
      }
    });
```
Trong `dispose`:
```dart
    _homeWidgetService.unregisterActionListener();
```

- [x] **Step 2: Thêm hàm `_syncWidgetState` và `_handleWidgetQuickApprove`**
Trong `_RemoteScreenState`:
```dart
  void _syncWidgetState({required String status, String? preview}) {
    if (_tabs.isEmpty) return;
    final sessionTitle = _activeTab.session.title;
    _homeWidgetService.updateWidgetFeed(
      sessionTitle: sessionTitle,
      status: status,
      preview: preview ?? 'Đang kết nối tới Antigravity Desktop...',
    );
  }

  Future<void> _handleWidgetQuickApprove() async {
    final controller = _activeTab.controller;
    if (controller == null) return;
    try {
      await controller.evaluateJavascript(source: '''
        (function() {
          const btns = document.querySelectorAll('button, [role="button"]');
          for (let b of btns) {
            const t = (b.innerText || b.getAttribute('aria-label') || '').toLowerCase();
            if (t.includes('approve') || t.includes('duyệt') || t.includes('allow') || t.includes('confirm') || t.includes('tiếp tục')) {
              b.click();
              return 'clicked_button';
            }
          }
          if (window.__agTriggerUserSent) {
            window.__agTriggerUserSent();
            return 'triggered_user_sent';
          }
          return 'none';
        })();
      ''');
      _onUserPromptSubmitted(_activeTab.session.title, 'Widget Quick Approve');
    } catch (e) {
      debugPrint('[RemoteScreen] Widget approve error: $e');
    }
  }
```

- [x] **Step 3: Gọi `_syncWidgetState` khi các sự kiện AI xảy ra**
- Trong `_onUserPromptSubmitted`:
  `_syncWidgetState(status: 'generating', preview: '⚡ Đang gửi prompt tới Antigravity...');`
- Trong `_onAITokenStreaming`:
  `_syncWidgetState(status: 'streaming', preview: _aiLastPreview.isNotEmpty ? _aiLastPreview : 'Đang sinh phản hồi...');`
- Trong `_onAICompleted`:
  `_syncWidgetState(status: 'idle', preview: preview ?? 'Đã hoàn thành phản hồi!');`
- Trong `_checkInstanceDisconnection`:
  `_syncWidgetState(status: 'offline', preview: 'Máy tính đã ngắt kết nối');`

- [x] **Step 4: Chạy toàn bộ test suite để đảm bảo không có regression**
```bash
flutter analyze
flutter test
```
Expected: 0 issues, all tests pass.

- [x] **Step 5: Commit**
```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "feat(remote): integrate HomeWidgetService with quick approve DOM injection"
```

---

### Task 5: Build Debug APK, Nạp Lên Xiaomi 11T & Kiểm Thử Toàn Diện

**Files:**
- Device target: `21081111RG` (Xiaomi 11T, HyperOS / Android 14)

- [x] **Step 1: Build Debug APK**
```bash
flutter build apk --debug
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` thành công.

- [ ] **Step 2: Cài đặt lên thiết bị Xiaomi 11T qua adb**
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Expected: `Success`.

- [ ] **Step 3: Mở ứng dụng và xác nhận không có lỗi logcat**
```bash
adb shell am start -n dev.antigravity.remote/dev.antigravity.remote.MainActivity
```

- [ ] **Step 4: Commit & Push lên GitHub origin main**
```bash
git push origin main
```
