# Thiết Kế Chi Tiết: Tối Ưu Hóa Hiệu Năng, Pin & Tiết Kiệm Dữ Liệu Toàn Diện (Deep Performance, Battery & Data Optimization)

- **Ngày ban hành:** 2026-09-04
- **Đối tượng áp dụng:** `RemoteScreen`, `RemoteTabItem`, `FloatingCapsule`, `HeartbeatService`, `HomeScreen`
- **Mục tiêu chính:** 
  1. Loại bỏ hiện tượng nóng máy và tụt pin nhanh bằng kiến trúc Event-Driven (triệt tiêu 100% vòng lặp Polling DOM).
  2. Đạt độ mượt 60/120fps chuẩn công thái học bằng `ValueNotifier` và `RepaintBoundary`.
  3. Cắt giảm 80% dung lượng mạng di động (Data 4G/5G) và RAM thông qua Chromium Disk Cache và cơ chế Heartbeat On-Demand.

---

## 1. Bối cảnh & Phân tích Nút Thắt Hiệu Năng (Root Causes)

Qua profiling mã nguồn và đo lường thời gian thực thi:
1. **CPU Chạy Liên Tục Không Nghỉ (Battery & Thermal Drain):**
   - Vòng lặp `Timer.periodic(Duration(milliseconds: 1500))` chạy hàm `_pollAIResponseStatus()` liên tục 2.400 lần/giờ, ép Chromium chạy `querySelectorAll` trên toàn bộ cây DOM.
   - Vòng lặp `Timer.periodic(Duration(milliseconds: 2500))` chạy `_checkInstanceDisconnection()`.
   - Cả hai timer này ngăn chip CPU đi vào trạng thái nghỉ sâu (Deep Sleep / C-States), gây phát nhiệt và hao hụt dung lượng pin nghiêm trọng.
2. **Rebuild Toàn Màn Hình Khi Tải Trang (Micro-Stutters):**
   - Trong `onProgressChanged`, mỗi khi phần trăm tải tăng lên (gọi 30–80 lần trong 2 giây), hàm `setState(() {})` được gọi trên toàn bộ `RemoteScreen`, bắt Scaffold, AppBar, TabBar và FloatingCapsule phải rebuild liên tục.
3. **Overdraw & Invalidation giữa Flutter Layer và Native PlatformView:**
   - Khi người dùng kéo `FloatingCapsule`, thiếu `RepaintBoundary` khiến Flutter phải re-rasterize cả lớp Texture native của `InAppWebView` ở tần số 60–120Hz.
4. **Bung Quá Nhiều Headless Chromium Ngầm (High RAM & Data Drain):**
   - `HeartbeatService.pingAll` khi khởi động app tạo đồng loạt Headless WebView cho tất cả các session, tải toàn bộ web bundle Google Antigravity ngầm, gây tốn hàng chục MB data 4G và hơn 150MB RAM.

---

## 2. Kiến trúc Tối Ưu Hóa Chi Tiết

```
+------------------------------------------------------------------------------------+
|                         PERFORMANCE & BATTERY OPTIMIZATION                         |
+------------------------------------------------------------------------------------+
| 1. EVENT-DRIVEN ENGINE (CPU Deep Sleep)                                            |
|    - Triệt tiêu _aiResponsePollingTimer (1.5s) & _disconnectCheckTimer (2.5s)       |
|    - 100% Event-Driven: Console [TTFT] + UserScript MutationObserver Handlers      |
|    - Giải phóng WakeLock & ForegroundService lập tức khi AI hoàn thành             |
+------------------------------------------------------------------------------------+
| 2. RENDER TREE & REBUILD SCOPE ISOLATION (60/120fps)                               |
|    - ValueNotifier<double> cho tiến trình tải trang (0 rebuild trên RemoteScreen)  |
|    - RepaintBoundary bọc quanh: InAppWebView, FloatingCapsule, SessionTabBar        |
|    - Thao tác kéo FloatingCapsule chạy trên GPU Layer độc lập                      |
+------------------------------------------------------------------------------------+
| 3. RESOURCE & NETWORK CACHING (Save 80% Data & RAM)                               |
|    - InAppWebViewSettings: CacheMode.LOAD_DEFAULT + domStorage + disk cache        |
|    - HeartbeatService: Cache-First (Thời gian truy cập) + On-Demand Probe          |
|    - Headless WebView: loadsImagesAutomatically = false + strict 3.5s timeout      |
+------------------------------------------------------------------------------------+
```

---

## 3. Quy cách Triển khai Kỹ thuật

### 3.1. Chuyển đổi sang Event-Driven hoàn toàn (`RemoteScreen`)

1. **Xóa bỏ các Timer định kỳ:**
   - Xóa bỏ biến `_aiResponsePollingTimer` và hàm `_pollAIResponseStatus()`.
   - Xóa bỏ biến `_disconnectCheckTimer`.
2. **Kích hoạt phát hiện ngắt kết nối theo sự kiện:**
   - Chỉ gọi hàm `_checkInstanceDisconnection()` tại 3 thời điểm:
     - Khi trang web tải xong (`onLoadStop`).
     - Khi có lỗi mạng (`onReceivedError` / `onReceivedHttpError`).
     - Khi người dùng chạm nút **Tải lại (Reload)**.
3. **Đảm bảo thu hồi WakeLock:**
   - Khi nhận được tín hiệu `onAICompleted` (hoặc khi người dùng ấn Home), tự động gọi `_foregroundService.stopForegroundWatcher()` và giải phóng `WakelockPlus` nếu người dùng không bật chế độ "Giữ sáng cố định".

---

### 3.2. Thu hẹp Rebuild Scope & Cô lập Render Layer

1. **Nâng cấp `RemoteTabItem` với `ValueNotifier`:**
   ```dart
   class RemoteTabItem {
     final RemoteSession session;
     InAppWebViewController? controller;
     final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
     final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
     String? errorMessage;
     bool isStreaming = false;

     RemoteTabItem({required this.session});

     void dispose() {
       progressNotifier.dispose();
       loadingNotifier.dispose();
     }
   }
   ```
2. **Loại bỏ `setState` trong `onProgressChanged`:**
   ```dart
   onProgressChanged: (controller, progress) {
     final progressValue = progress / 100.0;
     tab.progressNotifier.value = progressValue;
     if (progress >= 95) {
       tab.loadingNotifier.value = false;
     }
   },
   ```
3. **Chỉ rebuild thanh tiến trình tải trang (Progress Bar):**
   ```dart
   ValueListenableBuilder<bool>(
     valueListenable: activeTab.loadingNotifier,
     builder: (context, isLoading, _) {
       if (!isLoading) return const SizedBox.shrink();
       return ValueListenableBuilder<double>(
         valueListenable: activeTab.progressNotifier,
         builder: (context, progress, _) {
           return LinearProgressIndicator(
             value: progress,
             minHeight: 2.0,
             backgroundColor: Colors.transparent,
             valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
           );
         },
       );
     },
   )
   ```
4. **Gắn `RepaintBoundary`:**
   - Bọc từng `InAppWebView` trong `RepaintBoundary`.
   - Bọc `FloatingCapsule` trong `RepaintBoundary`.
   - Bọc `SessionTabBar` trong `RepaintBoundary`.

---

### 3.3. Tối ưu Bộ nhớ đệm Disk Cache & Heartbeat Service

1. **Cấu hình Cache trong `InAppWebViewSettings`:**
   ```dart
   initialSettings: InAppWebViewSettings(
     userAgent: customUserAgent,
     javaScriptEnabled: true,
     domStorageEnabled: true,
     databaseEnabled: true,
     thirdPartyCookiesEnabled: true,
     cacheEnabled: true,
     cacheMode: CacheMode.LOAD_DEFAULT,
     clearCache: false,
     supportMultipleWindows: false,
     javaScriptCanOpenWindowsAutomatically: false,
     mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
     useHybridComposition: true,
     allowFileAccessFromFileURLs: false,
     allowUniversalAccessFromFileURLs: false,
     allowContentAccess: false,
     allowBackgroundAudioPlaying: true,
   )
   ```
2. **Tối ưu hóa `HeartbeatService`:**
   - Trong `HomeScreen.initState()`:
     - Gọi `evaluateSessionStatus(session)` để hiển thị trạng thái ban đầu ngay lập tức với **0 byte mạng** và **0MB RAM phụ trội**.
   - Chuyển `HeartbeatService.probeSession` sang cơ chế tiết kiệm data:
     - `loadsImagesAutomatically: false` (không tải hình ảnh khi probe ngầm).
     - Giới hạn thời gian chờ timeout còn 3.5 giây.
     - Luôn gọi `headless.dispose()` trong khối `finally`.

---

## 4. Kế hoạch Kiểm thử & Đo lường (Verification Plan)

### 4.1. Đo lường Hiệu năng & Rebuild (Automated Tests)
- Chạy `flutter test` đảm bảo 100% 31 unit tests hiện có và các test mới đều pass.
- Đảm bảo `RemoteTabItem.dispose()` giải phóng đúng cách không rò rỉ `ValueNotifier`.

### 4.2. Kiểm tra Static Analysis & Build
- `flutter analyze`: Đạt 0 issues.
- `flutter build apk --debug`: Biên dịch sạch sẽ.

### 4.3. Kiểm tra Thực tế (Manual Validation)
- Mở một session trong `RemoteScreen`, theo dõi logcat: Xác nhận không còn bất kỳ dòng log polling 1.5s/2.5s nào.
- Kéo di chuyển `FloatingCapsule`: Thao tác mượt mà không có hiện tượng giật khựng.
- Kiểm tra dung lượng mạng tải trang: Khi tải lại tab, hầu hết tài nguyên được đọc trực tiếp từ cache.
