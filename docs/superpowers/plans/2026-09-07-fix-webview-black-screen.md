# Khắc phục triệt để lỗi Màn hình đen trên WebView (Xiaomi HyperOS / Android 14) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loại bỏ hoàn toàn `BackdropFilter` khỏi tất cả các widget nổi (`FloatingCapsule`, `GitActionsModal`) và hiệu chỉnh `transparentBackground: false` trên `InAppWebView` để sửa dứt điểm lỗi màn hình đen trên Xiaomi HyperOS / Android 14.

**Architecture:** Flutter Engine trên Android gặp xung đột đồ họa khi rasterizer thực hiện pass blur (`BackdropFilter`) đè lên Android native `PlatformView` (`SurfaceView`), khiến compositor layer sập thành màu đen `#000000`. Giải pháp loại bỏ hoàn toàn `BackdropFilter` trên các layer nổi, chuyển sang Apple Dark Surface nguyên khối với đổ bóng & viền tinh tế, đồng thời tắt cờ nền trong suốt trên WebView native.

**Tech Stack:** Flutter 3.5.4, Dart, `flutter_inappwebview` 6.x, Android `SurfaceView` Hybrid Composition.

---

### Task 1: Loại bỏ `BackdropFilter` khỏi `FloatingCapsule`

**Files:**
- Modify: `lib/screens/remote/widgets/floating_capsule.dart:1-125`

- [ ] **Step 1: Kiểm tra các tham chiếu `dart:ui` và `BackdropFilter` hiện tại**

Run: `git grep -n "BackdropFilter" lib/screens/remote/widgets/floating_capsule.dart`
Expected: Tìm thấy dòng 82 và 114 chứa `BackdropFilter`.

- [ ] **Step 2: Gỡ bỏ `import 'dart:ui';` và các widget `BackdropFilter` trong `floating_capsule.dart`**

Thực hiện:
- Xóa `import 'dart:ui';` ở đầu file.
- Tại `build()` của `_FloatingCapsuleState`:
  - Gỡ bỏ `ClipRRect` và `BackdropFilter` bọc ngoài `AnimatedContainer`.
  - Giữ nguyên `AnimatedContainer` với `decoration: BoxDecoration(...)`.
  - Thay đổi `color: const Color(0xFF16161A).withOpacity(0.96)`.
  - Gỡ bỏ `BackdropFilter` bọc quanh `_buildMoreMenu()`.

- [ ] **Step 3: Chạy `flutter analyze` xác nhận không có lỗi cú pháp hoặc unused import**

Run: `flutter analyze lib/screens/remote/widgets/floating_capsule.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/screens/remote/widgets/floating_capsule.dart
git commit -m "fix(capsule): remove BackdropFilter causing black screen over SurfaceView"
```

---

### Task 2: Loại bỏ `BackdropFilter` khỏi `GitActionsModal`

**Files:**
- Modify: `lib/screens/remote/widgets/git_actions_modal.dart:1-170`

- [ ] **Step 1: Kiểm tra `BackdropFilter` trong `git_actions_modal.dart`**

Run: `git grep -n "BackdropFilter" lib/screens/remote/widgets/git_actions_modal.dart`
Expected: Tìm thấy dòng 155.

- [ ] **Step 2: Gỡ bỏ `BackdropFilter` và dùng màu nền đặc**

Thực hiện:
- Thay vì bọc `BackdropFilter` bên trong `ClipRRect`, trả về trực tiếp `Container` bên trong `ClipRRect` với màu nền đặc `color: surfaceColor`.
- Xóa `import 'dart:ui';` nếu không còn sử dụng.

- [ ] **Step 3: Chạy `flutter analyze`**

Run: `flutter analyze lib/screens/remote/widgets/git_actions_modal.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/screens/remote/widgets/git_actions_modal.dart
git commit -m "fix(modal): remove BackdropFilter from GitActionsModal"
```

---

### Task 3: Cập nhật `InAppWebViewSettings` trong `RemoteScreen`

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart:1280-1295`

- [ ] **Step 1: Đổi `transparentBackground: true` thành `false`**

Tại dòng ~1284 của `lib/screens/remote/remote_screen.dart`:
```dart
        useHybridComposition: true, // SurfaceView chuẩn — MIUI GuiExtAux xử lý đúng
        transparentBackground: false, // Tắt transparent để tránh lộ đệm đen SurfaceView native
```

- [ ] **Step 2: Chạy `flutter analyze` trên toàn bộ dự án**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Chạy unit tests hiện có**

Run: `flutter test`
Expected: Tất cả 31 unit tests pass 100%.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "fix(webview): set transparentBackground to false for solid SurfaceView rendering"
```

---

### Task 4: Kiểm thử thực tế trên thiết bị Xiaomi qua ADB

**Files:**
- Test target: Thiết bị thật `21081111RG` (Xiaomi HyperOS / Android 14)

- [ ] **Step 1: Build và khởi chạy APK trên thiết bị**

Run: `flutter run -d adb-mnnn8tlj5twktcr8-N1WTNS._adb-tls-connect._tcp --debug`

- [ ] **Step 2: Mở session Antigravity từ màn hình Hub**

Quan sát:
- Vòng xoay kết nối xuất hiện trong 1–2 giây.
- Sau khi tải xong, giao diện Antigravity Web UI hiển thị sắc nét, đầy đủ danh sách hội thoại, khung nhập chat.
- Thanh viên thuốc `FloatingCapsule` hiển thị rõ ràng trên nền đen/sáng của web, có thể kéo thả và bấm menu.

- [ ] **Step 3: Chụp ảnh màn hình qua ADB lưu artifact nghiệm thu**

Run: `adb exec-out screencap -p > /Users/onenet/.gemini/antigravity-ide/brain/eb2efed3-7f39-4ee2-bb52-96955f721ae8/scratch/phone_fixed_screen.png`

- [ ] **Step 4: Đẩy commit lên GitHub repository**

Run: `git push origin main`
