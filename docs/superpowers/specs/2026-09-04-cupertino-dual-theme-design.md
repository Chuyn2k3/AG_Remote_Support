# Thiết Kế Hệ Thống Giao Diện Apple Cupertino Clean & Chế Độ Sáng / Tối (Dual Theme)

**Ngày lập:** 04/09/2026  
**Dự án:** `antigravity_support` (Flutter Mobile App)  
**Nhánh:** `feat/antigravity-remote-wrapper`  
**Phong cách chủ đạo:** Apple Human Interface Guidelines (Cupertino Clean Style)  

---

## 1. Mục Tiêu & Yêu Cầu Thiết Kế

### 1.1. Bối cảnh
Giao diện trước đây mang phong cách cyberpunk/sci-fi với gradient neon tím/cyan, viền phát sáng và hiệu ứng laser quét camera. Người dùng mong muốn nâng cấp toàn diện sang phong cách hiện đại, tối giản, chuyên nghiệp và thân thiện chuẩn **Apple Developer Tools**, đồng thời bổ sung **chế độ Sáng / Tối (Light & Dark Theme)** có thể chuyển đổi linh hoạt.

### 1.2. Ràng buộc quan trọng
- **Tuyệt đối không sử dụng màu đỏ Viettel** (`#EE0033`, `#61000E`).
- Tối ưu cho cả iOS và Android theo hướng trung tính cao cấp (Cupertino HIG).
- Giữ nguyên và bảo toàn toàn bộ tính năng kỹ thuật cốt lõi:
  - Quản lý đa tài khoản Google OAuth (`AccountChooser` trong WebView).
  - Hệ thống bỏ chặn WebView Google (`X-Requested-With` bypass, User-Agent Chrome Mobile).
  - Giữ sáng màn hình (Wakelock).
  - Lưu trữ bền vững phiên làm việc (`SharedPreferences`).
  - Mở liên kết ra trình duyệt ngoài (Safari/Chrome).

---

## 2. Hệ Thống Design Tokens & Chế Độ Sáng / Tối (Cupertino Dual Theme)

### 2.1. Bảng màu (Palette Tokens)

| Token | Light Mode (Giao diện Sáng) | Dark Mode (Giao diện Tối) | Mục đích sử dụng |
|---|---|---|---|
| `background` | `#F2F2F7` (Apple Grouped Background) | `#000000` (OLED True Black) | Nền chính của toàn ứng dụng |
| `surface` | `#FFFFFF` (Thuần trắng) | `#1C1C1E` (Apple Dark Elevated) | Nền thẻ (Card), BottomSheet, Dialog |
| `surfaceSecondary` | `#E5E5EA` (Xám phụ nhạt) | `#2C2C2E` (Xám phụ tối) | Nền nút phụ, ô nhập liệu |
| `primary` | `#007AFF` (Apple System Blue) | `#0A84FF` (Apple Dark Blue) | Nút bấm chính, liên kết, điểm nhấn |
| `primaryLight` | `#EBF5FF` | `rgba(10, 132, 255, 0.15)` | Nền icon, badge tài khoản |
| `statusSuccess` | `#34C759` (Apple Green) | `#30D158` (Apple Green Dark) | Chấm trạng thái kết nối hoạt động |
| `textPrimary` | `#000000` | `#FFFFFF` | Tiêu đề, văn bản chính |
| `textSecondary` | `#8E8E93` (Apple Tertiary Gray) | `#8E8E93` | Mô tả, nhãn phụ, thời gian |
| `border` | `#E5E5EA` | `#2C2C2E` | Viền thẻ 1px tinh tế |
| `divider` | `#F2F2F7` | `#2C2C2E` | Đường phân cách danh sách |

### 2.2. Kiểu dáng & Hiệu ứng (Shape & Elevation)
- **Bo góc (Corner Radius):**
  - Thẻ (Cards / Sheets): `16px`.
  - Nút bấm (Buttons): `12px`.
  - Viên thuốc / Pill (Badges, Floating Capsule): `24px` - `30px`.
- **Đổ bóng (Shadow):**
  - Light Mode: Rất nhẹ và lan tỏa `rgba(0, 0, 0, 0.04)` bán kính 8px. Không dùng đổ bóng đậm màu.
  - Dark Mode: Không dùng shadow đổ màu, dùng viền tinh tế 1px `#2C2C2E` để phân tách độ sâu không gian.

### 2.3. Kiến trúc Quản lý Giao diện (Theme Architecture)
- Hỗ trợ 3 chế độ: `ThemeMode.system` (Mặc định theo hệ điều hành), `ThemeMode.light`, `ThemeMode.dark`.
- Lưu cấu hình vào `SharedPreferences` dưới khóa `app_theme_mode`.
- Cung cấp `ValueNotifier<ThemeMode>` cấp toàn cục tại `main.dart` để cập nhật UI tức thì không cần tải lại app.
- Nút chuyển nhanh theme (☀️ / 🌙) trên AppBar của `HomeScreen`.

---

## 3. Thiết Kế Chi Tiết Từng Màn Hình

### 3.1. Trang Chủ (HomeScreen) & Thẻ Thiết Bị
- **Thanh tiêu đề (AppBar):**
  - Tiêu đề tối giản: `Antigravity` kèm phụ đề nhỏ `Remote Control`.
  - Nút chuyển giao diện dạng tròn kính mờ (☀️/🌙).
- **Thẻ Quét QR Nhanh (QrHeroCard):**
  - Card bo góc 16px, icon máy ảnh trong nền xanh nhẹ.
  - Nút chính: `Mở Camera` (Xanh Apple `#007AFF` / `#0A84FF`).
  - Nút phụ: `Dán liên kết` (Xám nhạt tối giản).
- **Danh sách Phiên Làm Việc (SessionCard):**
  - Tiêu đề nhóm: `THIẾT BỊ GẦN ĐÂY` (chữ in hoa 11px chuẩn Apple Settings).
  - Từng thẻ phiên làm việc:
    - Chấm tròn xanh lá 8px báo hiệu trạng thái sẵn sàng.
    - Tên máy (Alias thân thiện, có thể đổi tên).
    - Huy hiệu email Google (Account Badge) màu xanh Apple dịu mắt (giúp phân biệt các tài khoản khác nhau).
    - Thời gian truy cập gần nhất (`Vừa kết nối`, `X phút trước`).
    - Nút truy cập nhanh `Vào lại →` và menu `•••` (Đổi tên, Ghim, Mở trình duyệt ngoài Safari/Chrome, Xóa).
- **Trạng thái Trống (Empty State):**
  - Icon laptop tối giản, chữ màu xám phụ hướng dẫn kết nối máy tính lần đầu.

### 3.2. Màn Hình Quét Mã QR (ScannerScreen)
- **Khung ngắm Apple Camera Viewfinder:**
  - Kích thước 260×260px với 4 góc bo trắng (corner brackets) dày 3px, bán kính 16px.
  - Lớp phủ nền làm mờ tối nhẹ xung quanh khung ngắm (`Colors.black54`).
  - Bỏ hoàn toàn vạch laser quét lên xuống màu neon.
- **Thao tác điều khiển:**
  - Nút tròn Đóng (✕) và Bật/Tắt Flash (⚡️) ở góc trên, bo tròn kính mờ bán trong suốt.
  - Dòng chỉ dẫn nhỏ gọn phía dưới: *"Hướng camera vào mã QR trên Antigravity 2.0"*.

### 3.3. Trình Xem Remote & Viên Thuốc Điều Khiển (RemoteScreen & Dynamic Island Capsule)
- **Viên thuốc điều khiển nổi (FloatingCapsule):**
  - Thiết kế lấy cảm hứng từ Dynamic Island của Apple, sử dụng `BackdropFilter` làm mờ kính (Frosted Glass blur 16px) với nền đen mờ mờ 80%.
  - Trạng thái thu gọn (Mini Pill): Kích thước nhỏ 36px, bo góc 18px, hiển thị icon trạng thái, có thể kéo thả tự do dán vào cạnh màn hình.
  - Trạng thái mở rộng (Expanded Menu): Mở thanh điều khiển tối giản:
    1. 👤 Đổi/Chọn tài khoản Google (Multi-account modal).
    2. 💡 Giữ sáng màn hình (Wakelock on/off).
    3. 🔄 Tải lại trang (Reload).
    4. 🔗 Sao chép URL phiên.
    5. 🌐 Mở bằng trình duyệt ngoài (Safari/Chrome).
    6. 🏠 Quay về Trang chủ.
- **Thanh tiến trình tải (Linear Progress Bar):**
  - Độ dày 2px màu xanh Apple ở sát mép trên WebView.
- **Banner mất kết nối:**
  - Thiết kế kính mờ xám trung tính tinh tế phía trên, hướng dẫn kiểm tra Antigravity 2.0 trên máy tính mà không dùng màu đỏ cảnh báo gay gắt.

---

## 4. Kế Hoạch Triển Khai & Kiểm Thử

### 4.1. Các Tệp Mã Nguồn Cần Cập Nhật
1. `lib/core/theme/app_colors.dart`: Bổ sung toàn bộ bảng màu Apple Light & Dark tokens.
2. `lib/core/theme/app_theme.dart`: Xây dựng `lightTheme` và `darkTheme` chuẩn Cupertino Typography & Component styles.
3. `lib/main.dart`: Tích hợp `ThemeMode` controller và lưu vào `SharedPreferences`.
4. `lib/screens/home/home_screen.dart`: Cập nhật layout Apple Grouped Style, thêm nút chuyển theme trên AppBar.
5. `lib/screens/home/widgets/qr_hero_card.dart`: Tái cấu trúc theo Cupertino Clean Card.
6. `lib/screens/home/widgets/session_card.dart`: Tái cấu trúc danh sách thiết bị và badge tài khoản Google.
7. `lib/screens/scanner/scanner_screen.dart`: Thiết kế lại khung ngắm Apple Camera Viewfinder.
8. `lib/screens/remote/widgets/floating_capsule.dart`: Cải tiến viên thuốc Dynamic Island kính mờ.
9. `lib/screens/remote/remote_screen.dart`: Hoàn thiện loading bar và thông báo mất kết nối nhã nhặn.

### 4.2. Kế Hoạch Xác Minh (Verification)
- **Kiểm thử tự động:**
  - `flutter test`: Xác minh tất cả test logic hiện tại (`url_parser_test.dart`, `storage_service_test.dart`) chạy qua 100%.
  - Bổ sung test kiểm tra lưu trữ và khởi tạo `ThemeMode`.
- **Phân tích mã nguồn:**
  - `flutter analyze`: Đảm bảo 0 lint errors, 0 warnings.
- **Kiểm tra biên dịch:**
  - `flutter build apk --debug`: Đảm bảo toàn bộ ứng dụng build thành công mượt mà trên môi trường thật.
