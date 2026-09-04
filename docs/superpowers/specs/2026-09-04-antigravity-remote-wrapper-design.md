# Antigravity 2.0 Remote Control Mobile Wrapper - Design Specification

- **Date:** 2026-09-04
- **Topic:** Antigravity 2.0 Remote Control Mobile Wrapper App
- **Target Platforms:** iOS & Android (Flutter SDK ^3.5.4)
- **Design Guidelines:** VHT Modern Minimalism (Tuân thủ `docs/ĐỀ XUẤT UIUX_VHT_20260803/ĐỀ XUẤT UIUX_VHT_20260803.pdf`, Font Roboto, Nghiêm cấm sử dụng màu đỏ thương hiệu Viettel).

---

## 1. Mục tiêu & Bối cảnh dự án (Goal & Context)

### 1.1 Vấn đề hiện tại
Antigravity 2.0 cung cấp tính năng Remote Control điều khiển từ xa qua điện thoại bằng cách quét mã QR hiển thị trên Desktop IDE. Đường dẫn có định dạng:
`https://accounts.google.com/AccountChooser?Email=...&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F<session-id>-v2`

Khi mở trực tiếp trên trình duyệt di động (Safari/Chrome):
- Bị vướng thanh URL, thanh công cụ duyệt web (back/forward/tab) chiếm dụng không gian dọc quý giá.
- Màn hình điện thoại tự động tắt sau 30s - 1 phút khi người dùng đặt máy trên bàn để quan sát Agent làm việc.
- Không lưu trữ danh sách các máy tính / phiên làm việc gần đây để kết nối lại nhanh chóng.
- Phải dùng ứng dụng máy ảnh ngoài hoặc app quét QR rồi chuyển hướng sang trình duyệt, gây gián đoạn trải nghiệm.

### 1.2 Giải pháp đề xuất
Xây dựng một ứng dụng Mobile Wrapper hoàn chỉnh bằng Flutter (`antigravity_support`), biến trải nghiệm điều khiển Antigravity trên điện thoại thành một sản phẩm Native chuyên nghiệp:
- **Workspace Hub:** Quản lý danh sách phiên làm việc gần đây, đặt tên gợi nhớ, trạng thái online/idle.
- **Native QR Scanner:** Tích hợp camera quét mã QR tốc độ cao ngay trong ứng dụng, có tính năng dán link từ clipboard.
- **Full-Screen InAppWebView:** Nhúng trang điều khiển Antigravity 2.0 toàn màn hình 100%, có cơ chế tùy biến User-Agent tránh lỗi Google OAuth 403 `disallowed_useragent` và duy trì phiên đăng nhập Google vĩnh viễn (Persistent Cookie Jar).
- **Floating Capsule Assistant:** Menu kính mờ Glassmorphism kéo thả tự do, cung cấp các nút tiện ích: Keep Awake (giữ sáng màn hình), Reload trang, Sao chép link, Quay lại Hub, hoặc thu nhỏ thành chấm tròn mini không che khuất code/chat.

---

## 2. Hệ thống Design System & Bảng màu (VHT Minimalist - Non Red)

Dựa trên tài liệu *ĐỀ XUẤT UIUX_VHT_20260803.pdf*, loại bỏ hoàn toàn mã màu đỏ (`#EE0033`, `#61000E`) của Viettel, áp dụng phong cách **Modern Minimalism**:

### 2.1 Bảng màu (Color Palette)
| Vai trò | Mã màu | Mô tả & Ứng dụng |
| :--- | :--- | :--- |
| **Primary Brand** | `#7A5AF8` | Tím công nghệ AI (Deep Tech Violet), dùng cho Nút chính (Primary CTA), radar quét QR, border active |
| **Accent / In-Progress** | `#0284C7` | Xanh dương kỹ thuật (Cyan/Tech Blue), dùng cho thanh tiến trình tải trang web (Linear Loading Bar), trạng thái remote live |
| **Success State** | `#10B981` | Xanh lục chuẩn VHT, dùng cho chấm trạng thái Online, thông báo quét thành công |
| **Warning State** | `#FEBA00` | Vàng hổ phách chuẩn VHT, dùng khi bật chế độ Keep Awake, cảnh báo mạng yếu |
| **Background Surface** | `#0F1012` | Nền chính của ứng dụng (Deep Slate Dark), tạo chiều sâu thị giác chuyên nghiệp |
| **Card & Modal Surface**| `#18191B` | Nền các thẻ Card phiên, Header, Floating Capsule |
| **Border & Divider** | `#2F3033` | Đường kẻ mảnh 1px tinh tế phân chia các khối component |
| **Text Primary** | `#F8FAFC` | Trắng ngà có độ tương phản cao, chống mỏi mắt |
| **Text Secondary** | `#94A3B8` | Xám bạc cho phụ đề, thời gian, session ID |

### 2.2 Typography (Quy chuẩn Phông chữ)
- **Font Family:** `Roboto` (hoặc font hệ thống Google Sans tương thích) với đầy đủ các weight:
  - **Regular 400:** Nội dung mô tả, phụ đề, label nhỏ (11sp - 13sp).
  - **Medium 500:** Nút bấm, nhãn tag trạng thái (12sp - 14sp).
  - **SemiBold 600:** Tiêu đề thẻ Card, tên máy tính (14sp - 16sp).
  - **Bold / ExtraBold 700-800:** Tiêu đề chính của màn hình (18sp - 22sp).

### 2.3 Quy chuẩn Component (UI Tokens)
- **Bo góc (Border Radius):**
  - Card & Input: `12px`
  - Nút bấm: `8px` - `10px`
  - Floating Capsule: `24px` - `30px` (dạng viên nang pill tròn hoàn toàn)
- **Hiệu ứng Kính mờ (Glassmorphism):** Sử dụng `BackdropFilter` làm mờ hậu cảnh `sigmaX: 16.0, sigmaY: 16.0` với nền bán trong suốt `rgba(24, 25, 27, 0.88)` cho menu nổi.

---

## 3. Kiến trúc Kỹ thuật & Luồng Dữ liệu (Technical Architecture)

### 3.1 Cấu trúc Thư mục Dự án (`lib/`)
```
lib/
├── main.dart                      # Điểm khởi chạy ứng dụng, cấu hình theme và binding
├── core/
│   ├── theme/
│   │   ├── app_colors.dart        # Bảng màu chuẩn VHT (Non-Red)
│   │   ├── app_text_styles.dart   # Định nghĩa kiểu chữ Roboto
│   │   └── app_theme.dart         # ThemeData chuẩn Dark Mode
│   ├── services/
│   │   ├── wakelock_service.dart  # Quản lý giữ màn hình sáng
│   │   ├── storage_service.dart   # Đọc/ghi SharedPreferences
│   │   └── url_validator.dart     # Kiểm tra và parse URL Antigravity
│   └── widgets/
│       ├── vht_card.dart          # Component thẻ bo góc chuẩn VHT
│       └── status_badge.dart      # Chấm tròn & nhãn Online/Idle
├── models/
│   └── remote_session.dart        # Entity: id, url, title, lastActive, isPinned
├── screens/
│   ├── home/
│   │   ├── home_screen.dart       # Màn hình Hub quản lý các phiên
│   │   └── widgets/
│   │       ├── qr_hero_card.dart  # Thẻ hành động quét mã QR
│   │       └── session_item.dart  # Item hiển thị từng phiên làm việc
│   ├── scanner/
│   │   └── scanner_screen.dart    # Camera quét QR toàn màn hình
│   └── remote/
│       ├── remote_screen.dart     # WebView toàn màn hình
│       └── widgets/
│           └── floating_capsule.dart # Menu điều khiển nổi kéo thả
```

### 3.2 Các Thư viện Phụ thuộc (`pubspec.yaml`)
1. `flutter_inappwebview: ^6.1.5`: Engine WebView tiên tiến hỗ trợ đầy đủ WebStorage, CookieManager, cấu hình User-Agent, JavaScript bridge.
2. `mobile_scanner: ^5.2.3`: Thư viện quét mã QR tăng tốc phần cứng mượt mà trên cả iOS (AVFoundation) và Android (CameraX).
3. `wakelock_plus: ^1.2.8`: Điều khiển giữ sáng màn hình điện thoại khi đang remote.
4. `shared_preferences: ^2.3.2`: Lưu trữ danh sách lịch sử phiên và cài đặt người dùng.
5. `flutter_animate: ^4.5.0`: Tạo hiệu ứng micro-animations mượt mà, tia laser quét QR.

### 3.3 Chiến lược Vượt rào Google OAuth trong WebView
- **Nguyên nhân lỗi:** Google OAuth tự động chặn các embedded WebViews trên Android/iOS với thông báo `"403 disallowed_useragent"`.
- **Giải pháp:**
  - Cấu hình `InAppWebViewSettings`:
    - `userAgent`: Cung cấp User-Agent chuẩn của Google Chrome Mobile (Android) hoặc Mobile Safari (iOS).
    - `thirdPartyCookiesEnabled`: `true`
    - `domStorageEnabled`: `true`
    - `javaScriptEnabled`: `true`
    - `cacheEnabled`: `true`
  - Sau khi người dùng đăng nhập tài khoản Google lần đầu tiên, `CookieManager` lưu trữ toàn bộ session cookies vào sandbox của ứng dụng. Các phiên quét mã QR tiếp theo sẽ tự động chuyển hướng thẳng vào web điều khiển Antigravity mà không cần đăng nhập lại.

---

## 4. Đặc tả Chi tiết Màn hình (Screen Specifications)

### 4.1 Màn hình Home Hub (`HomeScreen`)
- **Header:**
  - Title: "Antigravity Hub" kèm subtitle "Remote 2.0 • VHT Edition".
  - Nút Action: Icon cài đặt / xóa bộ nhớ đệm cache WebView.
- **Hero Card (Quét QR):**
  - Card kích thước lớn với hiệu ứng gradient tím `7A5AF8` tinh tế.
  - Nút chính: **"Mở Camera Quét QR"** -> Điều hướng sang `ScannerScreen`.
  - Nút phụ: **"Dán link từ Clipboard"** -> Kiểm tra clipboard, nếu hợp lệ sẽ hỏi người dùng đặt tên và mở ngay.
- **Danh sách Phiên làm việc (Recent Sessions):**
  - Hiển thị danh sách các `RemoteSession` sắp xếp theo thời gian sử dụng gần nhất.
  - Mỗi thẻ hiển thị:
    - Dot trạng thái: Xanh lá `#10B981` (Gần đây) hoặc Xám `#64748B` (Cũ).
    - Tên máy tính (Có thể bấm giữ hoặc bấm menu để đổi tên, ví dụ: *"MacBook M1 - Cơ quan"*).
    - Session ID rút gọn (ví dụ: `328cc6cd...v2`).
    - Nút **"Vào lại"** (Primary Outline Violet) -> Mở trực tiếp `RemoteScreen`.
    - Menu ngữ cảnh: Đổi tên, Xóa khỏi danh sách, Ghim lên đầu.
  - Empty State: Hiển thị minh họa và hướng dẫn khi chưa có phiên nào được lưu.

### 4.2 Màn hình Quét mã QR (`ScannerScreen`)
- **Khung quét Viewfinder:**
  - Khung chữ nhật bo góc `18px`, viền đứt đoạn neon tím `#7A5AF8`.
  - Tia laser xanh Cyan `#0284C7` di chuyển quét dọc liên tục.
- **Controls trên thanh App Bar:**
  - Nút Back quay lại Home Hub.
  - Nút Bật/Tắt Flash (Đèn pin) trợ sáng.
  - Nút Đảo chiều Camera (Trước / Sau).
- **Xử lý URL (Validation Logic):**
  - Khi quét được mã, kiểm tra chuỗi có chứa `accounts.google.com` hoặc `antigravity.google.com/r/`.
  - Rung haptic feedback nhẹ (`HapticFeedback.mediumImpact()`).
  - Tự động bóc tách Session ID và lưu vào `SessionRepository`.
  - Chuyển tiếp ngay lập tức sang `RemoteScreen`.

### 4.3 Màn hình Điều khiển từ xa (`RemoteScreen` + `FloatingCapsule`)
- **Giao diện WebView:**
  - Chiếm 100% diện tích màn hình điện thoại (hiển thị trọn vẹn khu vực chat, input và approval buttons của Antigravity).
  - Thanh tiến trình tuyến tính mỏng 2px màu Cyan `#0284C7` ở mép trên cùng khi trang đang tải.
  - Kích hoạt `WakelockService.enable()` khi vào màn hình, tự động giải phóng `WakelockService.disable()` khi thoát màn hình.
- **Floating Capsule (Viên nang điều khiển mờ Glassmorphism):**
  - Vị trí: Mặc định ở góc dưới bên phải màn hình, trên vùng Safe Area.
  - Kéo thả tự do: Người dùng có thể chạm giữ và di chuyển tới bất kỳ vị trí nào, khi thả tay widget tự động hít vào cạnh trái hoặc phải gần nhất (`Draggable` / `GestureDetector`).
  - **Chế độ Mở rộng (Expanded Mode):**
    1. **💡 Keep Awake:** Nút chuyển đổi giữ màn hình sáng. Chuyển sang màu vàng `#FEBA00` khi đang bật.
    2. **🔄 Reload:** Tải lại trang web tức thì khi mạng chập chờn.
    3. **🏠 Home Hub:** Quay trở lại màn hình danh sách phiên.
    4. **📋 Copy Link:** Sao chép đường dẫn session hiện tại vào clipboard.
    5. **● Thu nhỏ (Mini):** Thu gọn thành chấm tròn mini 36x36px.
  - **Chế độ Mini (Mini Mode):**
    - Chấm tròn kính mờ nhỏ gọn với logo Antigravity phát sáng nhẹ, hoàn toàn không che nội dung. Chạm vào để bung to trở lại.

---

## 5. Xử lý Lỗi & Kịch bản Ngoại lệ (Error Handling)

1. **Mất kết nối mạng (Offline):**
   - Khi WebView không thể kết nối tới máy chủ Antigravity, hiển thị một banner thông báo tinh tế chuẩn VHT (màu vàng cảnh báo `#FEBA00` hoặc thẻ card retry) thay vì trang lỗi mặc định của hệ điều hành.
2. **URL quét được không hợp lệ:**
   - Nếu người dùng quét nhầm mã QR không phải của Antigravity, hiển thị SnackBar cảnh báo màu cam/vàng: *"Mã QR không hợp lệ. Vui lòng quét mã Remote Control từ Antigravity Desktop."* và tiếp tục camera scanner.
3. **Từ chối quyền Camera:**
   - Nếu người dùng từ chối quyền truy cập Camera trên iOS hoặc Android, hiển thị màn hình hướng dẫn thân thiện và nút bấm mở `Settings` hệ điều hành để cấp lại quyền.

---

## 6. Kế hoạch Kiểm thử & Xác minh (Verification Plan)

### 6.1 Automated / Static Analysis
- Chạy `flutter analyze` để đảm bảo code sạch sẽ, không có cảnh báo linter (`flutter_lints`).
- Chạy unit tests cho `url_validator_test.dart` và `session_repository_test.dart`.

### 6.2 Manual Verification
- Kiểm tra tính năng quét mã QR bằng link thực tế từ Antigravity Desktop.
- Kiểm tra cơ chế đăng nhập tài khoản Google qua WebView (User-Agent không bị lỗi 403).
- Kiểm tra tính năng giữ sáng màn hình (`WakelockPlus`).
- Kiểm tra tương tác kéo thả của Floating Capsule và thao tác thu nhỏ/phóng to.
- Kiểm tra tính kiên trì của danh sách phiên sau khi tắt app và mở lại.
