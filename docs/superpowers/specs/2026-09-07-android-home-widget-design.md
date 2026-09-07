# Thiết Kế Kỹ Thuật: Android Home Screen Widget (Live Agent Feed & Background Actions)

## 1. Tổng Quan & Mục Tiêu (Context & Goals)
Ứng dụng **AG Remote Support** hiện đã hoạt động ổn định trên thiết bị Android / Xiaomi HyperOS với khả năng kết nối phiên làm việc Antigravity 2.0 Desktop, dịch vụ chạy ngầm duy trì kết nối (`ForegroundWatcherService`) và bong bóng nổi (`NativeBubbleService`).

Tính năng **Android Home Screen Widget** mang trải nghiệm Antigravity ra ngay màn hình chính của điện thoại:
- **Live Agent Feed:** Theo dõi trạng thái máy tính (Online/Offline/Generating/Idle) và trích đoạn phản hồi hoặc yêu cầu phê duyệt mới nhất của AI Agent mà không cần mở app.
- **Background Execution:** Cung cấp nút hành động nhanh (Ví dụ: **"⚡ Duyệt / Tiếp tục"**) thực thi ngầm qua `PendingIntent` và `ForegroundWatcherService`, gửi lệnh tiếp tục trực tiếp vào WebView trong vòng < 100ms mà không làm gián đoạn màn hình hiện tại của người dùng.
- **1-Tap Deep Link:** Chạm vào bất kỳ vùng nào trên thân Widget để mở app và chuyển thẳng vào màn hình phiên làm việc (`RemoteScreen`).

---

## 2. Thiết Kế Thị Giác & Bố Cục Giao Diện (Visual & Layout)

### 2.1. Thông số & Kích thước:
- **Kích thước mặc định:** 4x2 cells (khoảng 260dp x 110dp).
- **Khả năng co giãn:** `resizeMode="horizontal|vertical"`, tương thích hoàn hảo với launcher Xiaomi HyperOS, OneUI và Pixel Launcher.
- **Tone màu chủ đạo:** Dark Glassmorphism đồng bộ với Apple Cupertino HIG của ứng dụng.

### 2.2. Cấu trúc giao diện (`widget_agent_feed.xml`):
```
┌───────────────────────────────────────────────────────────┐
│ 🚀 MacBook Pro • AG 2.0                     🟢 Sẵn sàng    │  ← Header
├───────────────────────────────────────────────────────────┤
│ "Đã hoàn thành phân tích mã nguồn và cập nhật 3 files.     │  ← Live Feed Body
│  Chờ duyệt lệnh git commit..."                            │  (2-3 dòng text)
├───────────────────────────────────────────────────────────┤
│ [ ⚡ Duyệt / Tiếp tục ]                  🕒 Cập nhật 2p trc│  ← Footer Actions
└───────────────────────────────────────────────────────────┘
```
- **Khung chứa (Container):** Nền bo tròn `20dp`, màu xám đen đậm (`#16161A`), viền mảnh `0.8dp` độ mờ `12%` trắng.
- **Thanh tiêu đề (Header):**
  - Icon Antigravity logo + Tên phiên làm việc (`widget_session_title`).
  - Badge trạng thái (`widget_status_text` & `widget_status_dot`):
    - 🟢 Sẵn sàng (`#34C759`)
    - 🟡 Đang xử lý... (`#FF9F0A` - nhấp nháy hoặc hiển thị khi AI đang stream/suy nghĩ)
    - 🔴 Cần phê duyệt (`#FF453A` - khi AI yêu cầu xác nhận lệnh)
    - ⚪ Ngoại tuyến (`#8E8E93` - khi ngắt kết nối máy tính)
- **Vùng nội dung (Live Feed Body):**
  - TextView 2–3 dòng (`widget_preview_text`), cỡ chữ 13sp, màu chữ `#E5E5EA`, cắt đuôi `end_ellipsis`.
- **Thanh tác vụ (Footer):**
  - **Nút "⚡ Duyệt / Tiếp tục" (`btn_widget_approve`):** Button bo góc 10dp, nền xanh Apple Blue (`#0A84FF`), chữ trắng in đậm 12sp.
  - Nhãn thời gian cập nhật nhỏ (`widget_timestamp_text`): 10sp màu `#8E8E93`.

---

## 3. Kiến Trúc Thành Phần (Component Architecture)

```
[RemoteScreen (Flutter / Dart)]
       │
       ▼ (1. Đẩy trạng thái khi có DOM event)
[HomeWidgetService (Dart)]
       │
       ▼ (2. MethodChannel 'dev.antigravity.remote/home_widget')
[MainActivity / AntigravityWidgetProvider (Kotlin)]
       │
       ▼ (3. Lưu SharedPreferences & update RemoteViews)
[Android Home Screen Widget UI]
       │
       ▼ (4. User bấm nút "⚡ Duyệt / Tiếp tục")
[WidgetActionReceiver (BroadcastReceiver)]
       │
       ▼ (5. Gửi Intent tới ForegroundWatcherService / MethodChannel)
[InAppWebView Controller (Flutter)]
       │
       ▼ (6. Inject JS: Click nút Approve / Submit prompt ngầm)
[Google Antigravity Desktop Web Session]
```

### 3.1. Các thành phần Native Android:
1. **`res/layout/widget_agent_feed.xml`:** Giao diện `RemoteViews` của widget.
2. **`res/xml/widget_agent_feed_info.xml`:** Cấu hình AppWidgetProviderInfo (`minWidth="250dp"`, `minHeight="110dp"`, `updatePeriodMillis="0"` để không lãng phí pin bằng polling định kỳ của OS).
3. **`AntigravityWidgetProvider.kt`:**
   - Kế thừa `AppWidgetProvider`.
   - Cung cấp hàm `updateAppWidget(context, appWidgetManager, appWidgetId)`.
   - Đọc dữ liệu từ `SharedPreferences("antigravity_widget_prefs")` và render lên `RemoteViews`.
4. **`WidgetActionReceiver.kt`:**
   - Kế thừa `BroadcastReceiver`.
   - Nhận intent action `ACTION_WIDGET_APPROVE`.
   - Nếu `ForegroundWatcherService` đang chạy: chuyển phát sự kiện tới Flutter thông qua `MethodChannel` để WebView kích hoạt lệnh duyệt.
   - Nếu app đã bị tắt: kích hoạt `MainActivity` với cờ mở đúng tab để người dùng thao tác.

### 3.2. Các thành phần Flutter / Dart:
1. **`lib/core/services/home_widget_service.dart`:**
   - Quản lý MethodChannel `dev.antigravity.remote/home_widget`.
   - Cung cấp API `updateWidgetFeed({required String sessionTitle, required String status, required String preview})`.
   - Đăng ký lắng nghe sự kiện từ `WidgetActionReceiver` (`onWidgetAction`).
2. **Tích hợp trong `RemoteScreen`:**
   - Lắng nghe callback `onWidgetAction`: Khi nhận sự kiện `approve`, tìm và kích hoạt nút chấp thuận hoặc gửi phím Enter / text `Tiếp tục` vào khung chat Antigravity.
   - Khi AI observer phát hiện thay đổi trạng thái, tự động gọi `HomeWidgetService.updateWidgetFeed`.

---

## 4. Chi Tiết Kỹ Thuật Thực Thi Ngầm (Background DOM Injection)

Khi người dùng bấm **"⚡ Duyệt / Tiếp tục"** trên Widget:
1. `WidgetActionReceiver` kích hoạt và gửi callback về Dart:
```dart
HomeWidgetService.onActionReceived((action) {
  if (action == 'approve') {
    _handleWidgetQuickApprove();
  }
});
```
2. Phương thức `_handleWidgetQuickApprove()` trong `RemoteScreen`:
```javascript
(function() {
  // 1. Thử click nút Approve / Duyệt nếu có hộp thoại xác nhận lệnh
  const approveButtons = document.querySelectorAll('button, [role="button"]');
  for (let b of approveButtons) {
    const text = (b.innerText || b.getAttribute('aria-label') || '').toLowerCase();
    if (text.includes('approve') || text.includes('duyệt') || text.includes('allow') || text.includes('confirm')) {
      b.click();
      return 'approved_button_clicked';
    }
  }
  // 2. Nếu không có nút duyệt riêng biệt, tự động điền 'Tiếp tục' và gửi prompt
  if (window.__agTriggerUserSent) {
    window.__agTriggerUserSent();
  }
  return 'continue_triggered';
})();
```
3. Ngay lập tức cập nhật trạng thái Widget thành `🟡 Đang tiếp tục...` để người dùng thấy phản hồi thị giác ngay trên Home Screen.

---

## 5. Xử Lý Ngoại Lệ & Độ Bền Vững (Edge Cases & Fallbacks)
- **App bị kill hoàn toàn:** Nút "Duyệt" trên Widget nhận diện trạng thái không có Service chạy nền sẽ tự động mở Activity chính kèm deep-link vào đúng session.
- **Nhiều session khác nhau:** Widget lưu và hiển thị session được truy cập gần nhất (`activeSession`).
- **Nội dung preview quá dài:** Cắt chuỗi an toàn ở mức 120 ký tự, loại bỏ ký tự điều khiển/HTML tags để tránh vỡ giao diện `RemoteViews`.
- **Chế độ tiết kiệm pin trên Xiaomi:** Tận dụng `ForegroundWatcherService` (đã có notification mức ưu tiên cao) để đảm bảo intent từ Widget không bị chặn.

---

## 6. Kế Hoạch Kiểm Thử (Verification Plan)
1. **Kiểm tra biên dịch & phân tích mã nguồn:**
   - Chạy `flutter analyze` & `flutter test` đảm bảo 0 lỗi.
   - Build Android debug APK với cấu hình AppWidget mới.
2. **Kiểm tra trên thiết bị thực tế Xiaomi 11T qua ADB:**
   - Thêm Widget ra màn hình chính qua Launcher.
   - Mở app, vào phiên làm việc, gửi prompt và kiểm tra Widget cập nhật nội dung tương ứng theo thời gian thực.
   - Thoát ra màn hình chính, nhấn nút "⚡ Duyệt / Tiếp tục" trực tiếp trên Widget và xác nhận lệnh được gửi ngầm tới Antigravity Desktop qua logcat.
