# Thiết Kế Chi Tiết: Gia Cố Bảo Mật Toàn Diện Ứng Dụng (Full-Spectrum Mobile Security Hardening)

- **Ngày ban hành:** 2026-09-04
- **Tiêu chuẩn áp dụng:** OWASP Mobile Application Security Verification Standard (MASVS) & Apple/Google Security Guidelines
- **Phạm vi tác động:** `RemoteScreen`, `InAppWebViewSettings`, `UrlParser`, `StorageService`, Android Manifest & Native Kotlin (`MainActivity.kt`), iOS Native Swift (`AppDelegate.swift`).

---

## 1. Mục tiêu & Bối cảnh

Ứng dụng **AG Remote Support** đóng vai trò là remote wrapper kết nối trực tiếp đến Antigravity 2.0 IDE trên nền tảng web (`antigravity.google.com`). Phiên làm việc chứa các thông tin cực kỳ nhạy cảm:
- Mã nguồn độc quyền của các dự án đang phát triển.
- Các token xác thực, cookies phiên đăng nhập Google Account.
- Lệnh thực thi trong terminal và kết quả sinh code từ AI engine.

Qua đợt kiểm toán mã nguồn toàn diện, đã phát hiện 4 nhóm nguy cơ bảo mật cần được gia cố lập tức:
1. **Lỗ hổng WebView Sandbox (OWASP M1/M8):** Bật quyền truy cập file hệ thống cục bộ (`allowFileAccessFromFileURLs: true`, `allowUniversalAccessFromFileURLs: true`), chấp nhận nội dung HTTP không mã hóa (`mixedContentMode: ALWAYS_ALLOW`), và chưa có bộ lọc điều hướng URL tin cậy.
2. **Nguy cơ rò rỉ dữ liệu hệ điều hành (OWASP M2):** Thiếu cờ cấm sao lưu `android:allowBackup="false"`, thiếu cấu hình `network_security_config.xml` ép buộc HTTPS, và để lộ hình ảnh màn hình phiên làm việc trên khay chuyển ứng dụng (Recent Apps / App Switcher).
3. **Lỗ hổng Logic Nhận dạng URL (OWASP M7):** Hàm `UrlParser.isAntigravityUrl` dùng `.contains(...)` lỏng lẻo, có thể bị vượt qua bằng tấn công Open Redirect hoặc giả mạo domain (ví dụ `https://evil.com?ref=antigravity.google.com`).
4. **Lưu trữ Dữ liệu Chưa Mã Hóa (OWASP M2):** URL và thông tin phiên lưu trữ dưới dạng plain JSON trong `SharedPreferences` / `NSUserDefaults`.

---

## 2. Kiến trúc & Giải pháp Chi tiết

```
+-----------------------------------------------------------------------------------+
|                        AG REMOTE SUPPORT HARDENING LAYERS                         |
+-----------------------------------------------------------------------------------+
| 1. NETWORK & INPUT LAYER                                                          |
|    - UrlParser: Strict HTTPS check + RFC 3986 Host Suffix (.google.com only)     |
|    - Android NetworkSecurityConfig: cleartextTrafficPermitted="false"             |
|    - iOS App Transport Security (ATS): 100% TLS 1.2+ enforce                      |
+-----------------------------------------------------------------------------------+
| 2. WEBVIEW SANDBOX LAYER                                                          |
|    - InAppWebViewSettings: allowFileAccess=false, allowUniversal=false            |
|    - mixedContentMode: MIXED_CONTENT_NEVER_ALLOW                                  |
|    - shouldOverrideUrlLoading: Whitelist Domain Filter (*.google.com, *.goog)    |
|    - Origin-Validation trên các JavaScript Handlers                               |
+-----------------------------------------------------------------------------------+
| 3. OS-LEVEL & SCREEN PRIVACY LAYER                                                |
|    - Android: android:allowBackup="false", android:fullBackupContent="false"      |
|    - Android Native: WindowManager.FLAG_SECURE on Lock / Background               |
|    - iOS Native: Privacy Shield (UIVisualEffectView Dark Blur on resign active)   |
+-----------------------------------------------------------------------------------+
| 4. DATA-AT-REST STORAGE LAYER                                                     |
|    - Obfuscated Encrypted Storage cho RemoteSession payload                       |
|    - Emergency Wipe (Xóa toàn bộ Cache, Cookies, Session khi cần)                 |
+-----------------------------------------------------------------------------------+
```

---

## 3. Quy cách Kỹ thuật từng Thành phần

### 3.1. WebView Sandbox Hardening (`lib/screens/remote/remote_screen.dart`)

1. **Khóa chặt các tham số cấu hình (`InAppWebViewSettings`):**
   - `allowFileAccessFromFileURLs: false` (chống script đọc file `/data/data/...`).
   - `allowUniversalAccessFromFileURLs: false` (chặn vượt qua SOP - Same Origin Policy).
   - `allowContentAccess: false` (chặn truy cập Android Content Providers).
   - `mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW` (chặn mọi tài nguyên không mã hóa).
   - `javaScriptCanOpenWindowsAutomatically: false` (chống popup lừa đảo).

2. **Bộ lọc điều hướng nghiêm ngặt (`shouldOverrideUrlLoading`):**
   ```dart
   shouldOverrideUrlLoading: (controller, navigationAction) async {
     final uri = navigationAction.request.url;
     if (uri == null) return NavigationActionPolicy.CANCEL;

     // 1. Chỉ chấp nhận giao thức HTTPS an toàn
     if (uri.scheme != 'https') {
       return NavigationActionPolicy.CANCEL;
     }

     // 2. Kiểm tra danh sách miền được phép (Domain Whitelist)
     final host = uri.host.toLowerCase();
     final bool isAllowedHost = host == 'antigravity.google.com' ||
         host == 'accounts.google.com' ||
         host.endsWith('.google.com') ||
         host.endsWith('.usercontent.goog');

     if (!isAllowedHost) {
       _showSecurityWarning('Cảnh báo: Yêu cầu điều hướng đến tên miền lạ ($host) đã bị chặn.');
       return NavigationActionPolicy.CANCEL;
     }

     return NavigationActionPolicy.ALLOW;
   }
   ```

3. **Bảo vệ Origin của JavaScript Handlers:**
   - Khi `onAIResponseDone` hoặc `onUserPromptSent` được gọi từ webview, kiểm tra URL hiện tại của webview controller phải thuộc miền Antigravity trước khi thực thi nghiệp vụ thông báo.

---

### 3.2. Cấu hình Hệ điều hành Android (`android/`)

1. **Tắt sao lưu nguy hiểm trong `AndroidManifest.xml`:**
   - Thêm `android:allowBackup="false"` và `android:fullBackupContent="false"` vào thẻ `<application>`.
   - Ngăn chặn kẻ xấu dùng cáp USB và lệnh `adb backup` để đọc toàn bộ dữ liệu ứng dụng.

2. **Tạo `res/xml/network_security_config.xml`:**
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <network-security-config>
       <base-config cleartextTrafficPermitted="false">
           <trust-anchors>
               <certificates src="system" />
           </trust-anchors>
       </base-config>
       <domain-config cleartextTrafficPermitted="false">
           <domain includeSubdomains="true">google.com</domain>
           <domain includeSubdomains="true">usercontent.goog</domain>
       </domain-config>
   </network-security-config>
   ```
   - Khai báo trong Manifest: `android:networkSecurityConfig="@xml/network_security_config"`.

3. **Chống rò rỉ chụp màn hình trên Android (`FLAG_SECURE`):**
   - Trong `MainActivity.kt`, bổ sung method channel `dev.antigravity.remote/security`:
     - `enableSecure()`: `window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)`.
     - `disableSecure()`: `window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)`.
   - Tự động bật `FLAG_SECURE` khi ứng dụng hiển thị màn hình khóa sinh trắc học hoặc khi app chuyển xuống background (`AppLifecycleState.paused`), đảm bảo Recent Apps switcher không chụp được mã nguồn và token.

---

### 3.3. Cấu hình Hệ điều hành iOS (`ios/`)

1. **Privacy Shield trên App Switcher (`AppDelegate.swift`):**
   - Trong `AppDelegate.swift`, cài đặt biến `blurView: UIVisualEffectView?`.
   - Sự kiện `applicationWillResignActive`:
     - Tạo một `UIBlurEffect(style: .dark)` phủ kín toàn bộ `window`.
     - Đảm bảo iOS App Switcher chụp ảnh lưu snapshot chỉ nhìn thấy một màn hình mờ đen bảo mật.
   - Sự kiện `applicationDidBecomeActive`:
     - Xóa bỏ `blurView` với animation mượt mà (fade out 150ms).

2. **Apple App Transport Security (ATS) trong `Info.plist`:**
   - Đảm bảo không chứa khóa `NSAllowsArbitraryLoads: true`.
   - Giữ nguyên cấu hình phân quyền người dùng tối giản, rõ ràng.

---

### 3.4. Logic Xác thực & Làm sạch URL (`lib/core/utils/url_parser.dart`)

1. **Tái cấu trúc `isAntigravityUrl` loại bỏ hoàn toàn `.contains(...)` sơ hở:**
   ```dart
   static bool isAntigravityUrl(String url) {
     if (url.trim().isEmpty) return false;
     final uri = Uri.tryParse(url.trim());
     if (uri == null) return false;

     // 1. Ép buộc HTTPS
     if (uri.scheme != 'https') return false;

     final host = uri.host.toLowerCase();

     // 2. Miền chính thức Antigravity
     if (host == 'antigravity.google.com' && uri.path.startsWith('/r/')) {
       return true;
     }

     // 3. Miền đăng nhập Google Accounts (Chỉ hợp lệ khi target trỏ về antigravity.google.com)
     if (host == 'accounts.google.com') {
       final continueParam = uri.queryParameters['continue'] ?? uri.queryParameters['service'] ?? '';
       if (continueParam.isNotEmpty) {
         final continueUri = Uri.tryParse(continueParam);
         if (continueUri != null && continueUri.host.toLowerCase() == 'antigravity.google.com') {
           return true;
         }
       }
     }

     return false;
   }
   ```
2. **Làm sạch Session ID và Email:** Bổ sung regex sanitize lọc sạch các ký tự đặc biệt nguy hiểm trước khi gắn vào bộ nhớ.

---

### 3.5. Bảo vệ Dữ liệu Lưu trữ Cục bộ (`lib/core/services/storage_service.dart`)

1. **Mã hóa chuỗi lưu trữ Session:**
   - Sử dụng thuật toán mã hóa xáo trộn bảo mật kết hợp khóa định danh thiết bị (Base64 + XOR Cipher với muối thiết bị riêng biệt) cho chuỗi JSON của `RemoteSession`.
   - Tự động tương thích ngược: Nếu phát hiện dữ liệu cũ chưa mã hóa (valid JSON format), tự động chuyển đổi sang định dạng mã hóa an toàn.
2. **Tính năng Emergency Wipe (Xóa khẩn cấp):**
   - Cung cấp phương thức `Future<void> emergencyWipe()`: Xóa sạch `_sessionsKey`, `_themeModeKey`, cookie jar và local storage của WebView.

---

## 4. Kế hoạch Kiểm thử & Xác minh (Verification Plan)

### 4.1. Unit Tests (Kiểm tra tự động)
- `test/url_parser_test.dart`:
  - Thêm các test case mô phỏng tấn công:
    - URL dùng `http://` thay vì `https://` -> `false`.
    - URL tấn công Open Redirect: `https://attacker.com?redirect=antigravity.google.com` -> `false`.
    - Subdomain giả mạo: `https://antigravity.google.com.evil.com/r/123` -> `false`.
    - URL chứa mã độc script: `https://antigravity.google.com/r/<script>alert(1)</script>` -> bị sanitize.
- `test/storage_service_test.dart`:
  - Kiểm tra dữ liệu session khi ghi vào SharedPreferences không còn ở dạng raw text.
  - Kiểm tra giải mã chính xác và khả năng tương thích ngược (backward compatibility).

### 4.2. Static Code Analysis & Build
- Chạy `flutter analyze` đảm bảo 0 warning, 0 error.
- Chạy `flutter test` đảm bảo 100% test cases passed.
- Chạy `flutter build apk --debug` đảm bảo `network_security_config.xml` và `MainActivity.kt` biên dịch hoàn hảo.

### 4.3. Kiểm thử Thủ công (Manual Security Testing)
- Kiểm tra `adb backup` từ máy tính: Hệ thống báo từ chối (`Backup not allowed`).
- Kiểm tra mở Recent Apps: Màn hình WebView bị che đen bởi `FLAG_SECURE`.
- Kiểm tra điều hướng: Thử mở một link ngoài, xác nhận WebView chặn lại và hiển thị cảnh báo an toàn.
