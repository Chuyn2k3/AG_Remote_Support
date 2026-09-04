# Thiết Kế Tính Năng Kiểm Tra Trạng Thái Máy Tính (Live Desktop Heartbeat Monitor)

**Ngày lập:** 04/09/2026  
**Dự án:** `antigravity_support` (Flutter Mobile App)  
**Nhánh:** `feat/antigravity-remote-wrapper`  
**Thuộc lộ trình nâng cấp:** Tính năng số 2 trong chuỗi (2 ➔ 3 ➔ 4 ➔ 5 ➔ 1)  

---

## 1. Mục Tiêu & Yêu Cầu

### 1.1. Bối cảnh & Vấn đề
Phiên làm việc Antigravity Remote yêu cầu máy tính Desktop phải đang mở phần mềm **Antigravity 2.0**. Nếu máy tính bị Sleep, mất mạng, hoặc người dùng đã tắt phần mềm ở Desktop thì kết nối sẽ bị đứt. Hiện tại, người dùng chỉ phát hiện được điều này sau khi đã bấm vào phiên và đợi WebView báo lỗi.

### 1.2. Giải pháp
- Tích hợp dịch vụ kiểm tra kết nối nhẹ (**Heartbeat Engine**) để xác định ngay máy tính nào đang mở (Online) và máy tính nào đang tắt (Offline) ngay trên màn hình chính.
- Cơ chế kiểm tra theo **Phương án B**:
  - Tự động kiểm tra một lần khi vừa mở app.
  - Cung cấp thao tác vuốt kéo xuống (**Pull-to-refresh**) để làm mới trạng thái bất cứ khi nào người dùng muốn.
  - Không chạy nền ngầm liên tục nhằm tiết kiệm tối đa pin và dung lượng 4G/5G.

### 1.3. Ràng buộc quan trọng
- **Tuyệt đối không sử dụng màu đỏ Viettel** (`#EE0033`, `#61000E`). Trạng thái Offline sử dụng xám trung tính Apple (`#8E8E93`).
- Timeout tối đa mỗi lần ping là **3.5 giây** để trải nghiệm vuốt làm mới luôn tức thì.

---

## 2. Kiến Trúc Kỹ Thuật (Architecture & Components)

### 2.1. Dịch Vụ Kiểm Tra Kết Nối: `HeartbeatService`
- **Vị trí tệp:** `lib/core/services/heartbeat_service.dart`.
- **Enum trạng thái:**
  ```dart
  enum DeviceStatus { online, offline, checking }
  ```
- **Hàm cốt lõi:**
  1. `Future<DeviceStatus> pingSession(RemoteSession session)`:
     - Lấy ID phiên làm việc từ `session.id`.
     - Tạo địa chỉ tunnel kiểm tra trực tiếp: `https://antigravity.google.com/r/<sessionId>-v2`.
     - Sử dụng `HttpClient` có sẵn của `dart:io`, gửi yêu cầu `HEAD` với `timeout: Duration(milliseconds: 3500)`.
     - Nếu nhận mã phản hồi HTTP `200`, `302`, `401`, `403`: Máy chủ tunnel Google đang giữ phiên hoạt động với máy tính ➔ trả về `DeviceStatus.online`.
     - Nếu nhận mã lỗi `404`, `502`, `504` hoặc gặp `SocketException` / `TimeoutException` ➔ trả về `DeviceStatus.offline`.
  2. `Future<Map<String, DeviceStatus>> pingAll(List<RemoteSession> sessions)`:
     - Sử dụng `Future.wait` để ping đồng thời toàn bộ danh sách phiên làm việc, hoàn tất toàn bộ trong vòng 1–2 giây.

### 2.2. Màn Hình Chính: `HomeScreen`
- Quản lý trạng thái bằng biến nội bộ: `Map<String, DeviceStatus> _deviceStatuses`.
- Bọc toàn bộ danh sách phiên làm việc trong `RefreshIndicator`:
  - `color`: Màu xanh Apple (`AppColors.lightPrimary` / `AppColors.darkPrimary`).
  - `onRefresh`: Kích hoạt hàm `_refreshDeviceStatuses()`.
- Tự động gọi `_refreshDeviceStatuses()` trong `initState()`.

### 2.3. Thẻ Thiết Bị: `SessionCard`
- Bổ sung tham số `final DeviceStatus status`.
- Cập nhật giao diện theo trạng thái:
  - **Online (🟢):**
    - Chấm tròn xanh lá (`#34C759` ở Light Mode, `#30D158` ở Dark Mode).
    - Huy hiệu `Active` nền xanh nhạt, chữ xanh.
    - Dòng mô tả: *"Sẵn sàng kết nối"*.
    - Nút *"Vào lại →"* nổi bật màu xanh Apple.
  - **Offline (⚪):**
    - Chấm tròn xám `#8E8E93`.
    - Huy hiệu `Offline` nền xám nhạt, chữ xám.
    - Dòng mô tả: *"Chưa mở Antigravity 2.0 trên máy tính"*.
    - Nút *"Vào lại →"* vẫn bấm được (đáp ứng tình huống người dùng vừa bật máy).
  - **Checking (🔄):**
    - Chấm tròn xanh dương nhạt nhấp nháy hoặc spinner 10px.
    - Dòng mô tả: *"Đang kiểm tra kết nối..."*.

---

## 3. Kế Hoạch Kiểm Thử & Xác Minh

1. **Unit Test (`test/heartbeat_service_test.dart`):**
   - Kiểm tra phân loại chính xác các trạng thái `DeviceStatus.online`, `offline`, `checking`.
   - Kiểm tra cơ chế xử lý Timeout trong thời gian 3.5 giây mà không làm crash ứng dụng.
2. **Kiểm tra Lint (`flutter analyze`):**
   - Đảm bảo 0 lỗi lint và 0 warnings.
3. **Biên dịch APK (`flutter build apk --debug`):**
   - Biên dịch thành công APK mới trên máy tính.
