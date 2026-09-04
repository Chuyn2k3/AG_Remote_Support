# Thiết kế Kỹ thuật: Native Floating Chat Head (Bong bóng tròn như Zalo) & Hệ thống Thông báo AI Nền

- **Ngày tạo:** 2026-09-04
- **Trạng thái:** Đã thống nhất thiết kế với người dùng, chuẩn bị lập kế hoạch triển khai
- **Phạm vi:** Android Native (Kotlin) & Flutter Layer

---

## 1. Bối cảnh & Vấn đề cần giải quyết

Trong quá trình sử dụng AG Remote Support trên điện thoại Android, người dùng gặp phải 2 trở ngại lớn:

1. **Bong bóng nổi (Floating Bubble) đè màn hình và không di chuyển được:**
   - Plugin `system_alert_window` trước đây tạo một khung chữ nhật cố định ở đáy màn hình với kích thước lớn.
   - Do vướng cơ chế bắt sự kiện cảm ứng của Flutter, cửa sổ không thể kéo thả di chuyển được, gây che khuất bàn phím và nội dung của các ứng dụng khác (Facebook, Zalo, YouTube...).
   - Người dùng mong muốn trải nghiệm **Bong bóng tròn nhỏ gọn (Chat Head 56x56 dp)** giống hệt Zalo và Facebook Messenger: có thể kéo thả tự do khắp màn hình, tự động hút dính vào mép khi buông tay, chạm vào là mở bung app ngay.

2. **Gõ lệnh cho AI chạy rồi thoát ra ngoài thì không nhận được thông báo:**
   - Khi người dùng gửi câu lệnh cho Antigravity AI rồi bấm phím **Home** ra màn hình chính, hệ điều hành Android tự động đưa Activity vào trạng thái `onPause()`.
   - Nhân Chromium của WebView tự động **"đóng băng" toàn bộ luồng JavaScript** (`setInterval`, `MutationObserver`, và `evaluateJavascript`) để tiết kiệm pin.
   - Khiến bộ đếm giám sát AI bị ngắt quãng, không thể phát hiện lúc AI trả lời xong khi người dùng đang ở ngoài màn hình chính.

---

## 2. Mục tiêu (Goals) & Giới hạn (Non-Goals)

### Mục tiêu (Goals)
- **Bong bóng tròn Chat Head Native (Kotlin):** Kích thước tròn 56x56 dp, hiển thị logo Antigravity phát sáng và chấm trạng thái kết nối/AI.
- **Cơ chế vật lý mượt mà (Physics Snapping):** Kéo thả tự do 60fps trên toàn màn hình; khi thả tay, bóng tự động trượt mượt mà bám sát vào cạnh trái hoặc phải gần nhất.
- **Tương tác trực quan:**
  - Chạm nhẹ vào bóng ➔ Bật app `MainActivity` lên màn hình ngay lập tức, giữ nguyên phiên làm việc.
  - Kéo bóng vào vùng hủy (✕) ở đáy màn hình ➔ Đóng/ẩn bong bóng nổi.
- **Ngăn Android đóng băng WebView bằng Foreground Service:** Khi người dùng gửi lệnh hoặc bật bong bóng, kích hoạt Android Foreground Service siêu nhẹ kèm CPU WakeLock. Giữ cho WebView và tiến trình Flutter tiếp tục chạy ngầm ổn định.
- **Thông báo AI hoàn thành chuẩn xác (Heads-up Notification):** Bắn thông báo pop-up banner rơi từ đỉnh màn hình kèm âm báo, rung, và trích đoạn câu trả lời khi AI hoàn thành.

### Giới hạn (Non-Goals)
- Tính năng Bong bóng nổi chỉ hỗ trợ trên nền tảng **Android** (do chính sách Apple Sandbox không cho phép vẽ cửa sổ nổi đè lên ứng dụng khác trên iOS). Trên iOS, ứng dụng sẽ chỉ sử dụng thông báo đẩy chuẩn.

---

## 3. Kiến trúc Chi tiết & Thành phần

### A. Tầng Native Android (Kotlin) — `FloatingHeadService.kt`

Xây dựng Service Native độc lập kế thừa từ `android.app.Service`:

1. **Giao diện bóng tròn (Head View):**
   - Khởi tạo View thông qua `android.view.WindowManager`.
   - Layout parameters:
     - `type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY` (Android 8.0+)
     - `flags = FLAG_NOT_FOCUSABLE or FLAG_LAYOUT_NO_LIMITS`
     - `width = 56.dpToPx()`, `height = 56.dpToPx()`
     - `gravity = Gravity.TOP or Gravity.START`
   - Thiết kế Canvas vẽ hình tròn bo viền gradient neon cyan `#38BDF8`, nền dark frosted `#181820`, icon terminal màu trắng ở giữa và chấm nhỏ hiển thị trạng thái (Xanh lá / Vàng nhấp nháy / Đỏ).

2. **Bộ xử lý chạm & Kéo thả (Touch & Drag Listener):**
   - `ACTION_DOWN`: Ghi nhận tọa độ chạm ban đầu (`initialX, initialY, initialTouchX, initialTouchY`). Khởi tạo vùng hủy (Dismiss View) ở đáy màn hình.
   - `ACTION_MOVE`: Cập nhật liên tục `params.x` và `params.y` theo đầu ngón tay. Nếu bóng chạm gần vùng hủy ở đáy, phóng to nhẹ biểu tượng hủy để báo hiệu.
   - `ACTION_UP`:
     - Nếu khoảng cách di chuyển $< 8$ pixel: Coi là thao tác **Click**. Kích hoạt Intent `dev.antigravity.remote.MainActivity` với flags `FLAG_ACTIVITY_REORDER_TO_FRONT or FLAG_ACTIVITY_SINGLE_TOP` để mở app ngay lập tức.
     - Nếu rơi vào vùng hủy: Hủy dịch vụ `FloatingHeadService`.
     - Nếu thả tay ở vị trí bất kỳ: Dùng `ValueAnimator` để chạy hiệu ứng lò xo (Spring Animation) đưa tọa độ `x` của bóng về mép trái ($x = 16\text{px}$) hoặc mép phải ($x = \text{screenWidth} - 56\text{dp} - 16\text{px}$).

3. **Vùng hủy (Dismiss Target View):**
   - Một vòng tròn $64\text{dp}$ có icon `✕` màu trắng xuất hiện mờ dần ở giữa cạnh đáy màn hình khi người dùng bắt đầu kéo bóng, và ẩn đi khi buông tay.

---

### B. Tầng Giữ Tiến Trình & Nền — `ForegroundWatcherService.kt`

1. **Android Foreground Service:**
   - Chạy với notification dạng `FOREGROUND_SERVICE_SPECIAL_USE`.
   - Thông báo tiền sảnh thông báo rõ ràng cho người dùng: *"Antigravity AI đang chạy tác vụ nền..."*.
   - Khóa CPU WakeLock nhẹ (`PowerManager.PARTIAL_WAKE_LOCK`) trong suốt thời gian AI đang sinh câu trả lời.
   - Khiến hệ thống Android coi ứng dụng như một tác vụ đa phương tiện/dẫn đường, **không bao giờ đóng băng WebView hoặc tạm dừng JavaScript**.

2. **Chuyển đổi trạng thái tiêu thụ điện năng:**
   - Khi AI hoàn thành và thông báo đã được gửi ➔ Foreground Service tự động hủy WakeLock và chuyển về chế độ chạy ngầm tiêu chuẩn để tiết kiệm pin.

---

### C. Tầng Cầu nối Flutter & Trình Giám Sát AI (Dart)

1. **Platform Channel (`dev.antigravity.remote/floating_bubble`):**
   - `showBubble(sessionTitle, status)`: Bật bóng tròn native.
   - `updateBubbleStatus(status)`: Cập nhật màu chấm trạng thái (🟢 Sẵn sàng, 🟡 Đang suy nghĩ, 🔴 Offline).
   - `hideBubble()`: Tắt bóng tròn.

2. **Bộ quét Dart Watcher cải tiến (`remote_screen.dart`):**
   - Chạy định kỳ `Timer.periodic(1500ms)`.
   - Do có Foreground Service giữ tiến trình, hàm `evaluateJavascript` vẫn thực thi đều đặn ngay cả khi người dùng đang ở ngoài màn hình chính.
   - **Quy tắc phát hiện hoàn thành:**
     - `isGenerating == false` (không còn nút Stop / Cancel / Spinner).
     - `textLength` không tăng thêm trong 2.0 giây.
     - ➔ Kích hoạt `_notificationService.showAICompletedNotification(...)`.
     - ➔ Đồng thời cập nhật chấm bóng tròn từ 🟡 về 🟢.

---

## 4. Kế hoạch Kiểm thử & Xác minh

1. **Kiểm tra Phân tích mã nguồn:**
   - Chạy `flutter analyze` bảo đảm 0 lỗi, 0 cảnh báo.
   - Chạy `flutter test` bảo đảm 22/22 unit tests hiện có đều pass.
2. **Kiểm thử Native trên thiết bị Android:**
   - **Test 1 (Kéo thả bóng tròn):** Bấm nút Bubble ➔ Bóng tròn 56dp xuất hiện. Kéo thả quanh màn hình xem có mượt 60fps không, buông tay xem có tự động hút dính vào mép trái/phải không.
   - **Test 2 (Chạm mở app):** Chạm vào bóng tròn khi đang ở màn hình chính hoặc Zalo ➔ App AG Remote mở bung lên ngay lập tức tại đúng tab đang làm việc.
   - **Test 3 (Hủy bóng):** Kéo bóng vào biểu tượng ✕ ở đáy màn hình ➔ Bóng biến mất.
   - **Test 4 (Thông báo AI nền):** Mở WebView, gõ câu lệnh yêu cầu AI tạo code hoặc phân tích, bấm Gửi và nhấn phím Home ra ngoài màn hình chính ➔ Chấm trên bóng chuyển sang vàng ➔ Chờ AI phản hồi xong ➔ Thông báo pop-up banner rơi xuống đỉnh màn hình kèm trích đoạn câu trả lời!
