# Native Floating Chat Head & Background AI Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai bong bóng nổi tròn chuẩn Native Android (Chat Head 56x56 dp giống Zalo/Messenger có thể kéo thả tự do, tự hút bám mép màn hình, chạm mở app, kéo xuống đáy để tắt) và hệ thống Android Foreground Service ngăn chặn đóng băng WebView khi ra màn hình chính, đảm bảo thông báo AI hoàn thành nổ 100% chuẩn xác.

**Architecture:**
- **Native Android (Kotlin):** `FloatingHeadService.kt` tạo icon tròn 56dp thông qua Android `WindowManager`, xử lý kéo thả cảm ứng mượt mà 60fps, tự hút bám mép trái/phải với animation lò xo, và vùng hủy ✕ ở đáy màn hình.
- **Foreground Service & Wakelock (Kotlin):** `ForegroundWatcherService.kt` giữ tiến trình và kết nối WebSocket của Antigravity luôn hoạt động khi bấm Home, ngăn Chromium WebView tạm dừng JavaScript.
- **Flutter Bridge & Dart Watcher:** `NativeBubbleService.dart` kết nối qua `MethodChannel`, phối hợp với bộ quét Dart Watcher trong `remote_screen.dart` để cập nhật chấm trạng thái động trên bóng tròn và bắn thông báo pop-up banner khi AI trả lời xong.

**Tech Stack:** Kotlin, Android WindowManager & Services, Flutter 3.5.4, Flutter InAppWebView 6.1.5, Flutter Local Notifications 18.0.0.

---

### Task 1: Cấu hình Android Manifest cho Native Floating Head & Foreground Service

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Thêm khai báo Services vào AndroidManifest.xml**

Cần khai báo `FloatingHeadService` và `ForegroundWatcherService` với cờ `foregroundServiceType="specialUse"`:

```xml
        <!-- Native Floating Chat Head Service -->
        <service
            android:name=".FloatingHeadService"
            android:exported="false" />

        <!-- Background Foreground Watcher Service keeping WebView alive -->
        <service
            android:name=".ForegroundWatcherService"
            android:exported="false"
            android:foregroundServiceType="specialUse" />
```

- [ ] **Step 2: Thêm permission WAKE_LOCK nếu còn thiếu**

Đảm bảo manifest có `<uses-permission android:name="android.permission.WAKE_LOCK"/>`.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "chore: declare FloatingHeadService and ForegroundWatcherService in manifest"
```

---

### Task 2: Triển khai Native Kotlin FloatingHeadService (Bong bóng tròn 56x56 dp)

**Files:**
- Create: `android/app/src/main/kotlin/dev/antigravity/remote/FloatingHeadService.kt`

- [ ] **Step 1: Viết mã nguồn FloatingHeadService.kt**

Dịch vụ kế thừa `android.app.Service`, tạo View tròn đường kính 56dp:
1. `createFloatingView()`: Vẽ View tròn với nền dark `#1A1A22`, viền neon `#38BDF8`, icon terminal trắng ở giữa và chấm trạng thái góc.
2. `createDismissView()`: Vòng tròn 64dp có icon ✕ ở đáy màn hình xuất hiện khi đang kéo bóng.
3. `onTouch`: Bắt `ACTION_DOWN`, `ACTION_MOVE`, `ACTION_UP`. Tính toán khoảng cách di chuyển:
   - Nếu $< 10$ px: Click ➔ gọi `openMainActivity()`.
   - Nếu thả vào vùng hủy ➔ `stopSelf()`.
   - Nếu thả ngoài vùng hủy ➔ Chạy `ValueAnimator` hút về mép trái ($x=16$) hoặc mép phải ($x=\text{screenWidth} - 56\text{dp} - 16$).
4. Nhận Broadcast/Intent để cập nhật màu chấm trạng thái:
   - `online`: Xanh lá
   - `thinking`: Vàng nhấp nháy
   - `offline`: Đỏ

- [ ] **Step 2: Tạo layout drawable và icon nếu cần hoặc vẽ hoàn toàn bằng code Canvas/ShapeDrawable**

Sử dụng `GradientDrawable` và `ImageView`/`FrameLayout` thuần bằng code để không cần phụ thuộc XML layout rời rạc, tránh lỗi thiếu resource.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/dev/antigravity/remote/FloatingHeadService.kt
git commit -m "feat(android): implement native FloatingHeadService with physics snapping and dismiss target"
```

---

### Task 3: Triển khai Native Kotlin ForegroundWatcherService (Ngăn Chromium đóng băng WebView)

**Files:**
- Create: `android/app/src/main/kotlin/dev/antigravity/remote/ForegroundWatcherService.kt`

- [ ] **Step 1: Viết mã nguồn ForegroundWatcherService.kt**

1. Khởi tạo Notification Channel `foreground_watcher_channel`.
2. Khi `startForeground()` được gọi:
   - Hiển thị notification tiền sảnh nhẹ: *"Antigravity AI đang chạy câu lệnh... [Chạm để mở]"*.
   - Tạo và giữ `PowerManager.WakeLock(PARTIAL_WAKE_LOCK)` với tag `"AGRemote::AiGenerationWakeLock"`.
3. Khi nhận intent action `"ACTION_STOP"`:
   - Giải phóng WakeLock an toàn (`wakeLock.release()`).
   - Gọi `stopForeground(STOP_FOREGROUND_REMOVE)` và `stopSelf()`.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/dev/antigravity/remote/ForegroundWatcherService.kt
git commit -m "feat(android): implement ForegroundWatcherService with wake lock"
```

---

### Task 4: Cập nhật MainActivity.kt kết nối MethodChannel Flutter <-> Native

**Files:**
- Modify: `android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt`

- [ ] **Step 1: Bổ sung các lệnh điều khiển bóng và foreground service trong MethodChannel**

Kênh `dev.antigravity.remote/floating_bubble`:
- `showBubble`: Bắt đầu `FloatingHeadService` với session title và trạng thái.
- `updateStatus`: Gửi Broadcast hoặc cập nhật trạng thái chấm bóng tròn.
- `hideBubble`: Dừng `FloatingHeadService`.
- `startForegroundWatcher`: Khởi động `ForegroundWatcherService`.
- `stopForegroundWatcher`: Dừng `ForegroundWatcherService`.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt
git commit -m "feat(android): connect floating bubble and foreground watcher to MethodChannel in MainActivity"
```

---

### Task 5: Tạo NativeBubbleService phía Flutter thay thế system_alert_window

**Files:**
- Create: `lib/core/services/native_bubble_service.dart`
- Test: `test/native_bubble_service_test.dart`

- [ ] **Step 1: Viết unit test cho NativeBubbleService**

Kiểm tra các method invocation của platform channel `dev.antigravity.remote/floating_bubble`.

- [ ] **Step 2: Viết mã nguồn NativeBubbleService.dart**

Wrapper gọi các phương thức:
- `Future<bool> checkPermission()`
- `Future<bool> requestPermission()`
- `Future<void> showBubble({required String sessionTitle, String status})`
- `Future<void> updateBubbleStatus(String status)`
- `Future<void> hideBubble()`
- `Future<void> startForegroundWatcher({required String title})`
- `Future<void> stopForegroundWatcher()`

- [ ] **Step 3: Chạy test NativeBubbleService**

Run: `flutter test test/native_bubble_service_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/native_bubble_service.dart test/native_bubble_service_test.dart
git commit -m "feat: implement NativeBubbleService with platform channel wrapper"
```

---

### Task 6: Tích hợp Native Bubble & Foreground Watcher vào RemoteScreen

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Cập nhật _toggleBubble() trong RemoteScreen**

Thay thế `OverlayService` (system_alert_window cũ) bằng `NativeBubbleService`:
- Kiểm tra & xin quyền `SYSTEM_ALERT_WINDOW`.
- Gọi `NativeBubbleService.showBubble()`.
- Hiện SnackBar hướng dẫn: *"🟢 Đã bật Bong bóng tròn Chat Head! Bạn có thể kéo thả tự do, chạm để mở app, kéo xuống đáy để tắt."*
- Gọi `AppLifecycleService.moveTaskToBack()`.

- [ ] **Step 2: Cập nhật bộ phát hiện AI trả lời xong kết hợp Foreground Watcher**

1. Khi câu lệnh được gửi (gõ Enter / click Send / Voice prompt):
   - Kích hoạt `NativeBubbleService.startForegroundWatcher()` để ngăn Android đóng băng WebView khi user ấn Home.
   - Cập nhật chấm bóng tròn sang `thinking` (🟡).
2. Khi bộ quét phát hiện AI hoàn thành (hết nút Stop + text dừng tăng trong 2.0s):
   - Bắn thông báo pop-up banner: `_notificationService.showAICompletedNotification(...)`.
   - Cập nhật chấm bóng tròn về `online` (🟢).
   - Gọi `NativeBubbleService.stopForegroundWatcher()` để tiết kiệm pin.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "feat(remote): integrate NativeBubbleService and ForegroundWatcher into RemoteScreen"
```

---

### Task 7: Xác minh toàn diện & Đóng gói APK Debug

**Files:**
- Verification: toàn bộ dự án

- [ ] **Step 1: Chạy flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Chạy bộ unit tests**

Run: `flutter test`
Expected: Tất cả các bài test đều PASS.

- [ ] **Step 3: Build APK Debug**

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` thành công không có lỗi Kotlin.

- [ ] **Step 4: Commit và cập nhật walkthrough**

```bash
git commit -am "chore: update walkthrough with verified native chat head and AI background notification"
```
