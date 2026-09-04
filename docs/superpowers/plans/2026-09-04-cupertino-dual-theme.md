# Kế Hoạch Triển Khai Apple Cupertino Dual Theme (Light & Dark)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi toàn diện giao diện Antigravity Remote Mobile App từ phong cách neon/sci-fi AI sang phong cách Apple Cupertino Clean Style (Human Interface Guidelines), hỗ trợ chuyển đổi mượt mà giữa chế độ Sáng (Light Mode) và Tối (Dark Mode).

**Architecture:** Xây dựng hệ thống design tokens kép (`lightTheme` & `darkTheme`) trong `AppColors` & `AppTheme`; quản lý trạng thái theme toàn cục qua `ValueNotifier<ThemeMode>` đồng bộ bền vững với `StorageService` (`SharedPreferences`); tái cấu trúc toàn bộ các màn hình (`HomeScreen`, `ScannerScreen`, `RemoteScreen`) và các component (`AppleCard`, `QrHeroCard`, `SessionCard`, `FloatingCapsule`) theo chuẩn tối giản Apple.

**Tech Stack:** Flutter 3.24.4, Dart 3.5.4, `flutter_inappwebview`, `mobile_scanner: 5.2.3`, `shared_preferences`, `flutter_animate`.

---

## Danh Sách Tệp (File Structure Map)

| Tệp | Trách nhiệm | Loại thay đổi |
|---|---|---|
| `lib/core/theme/app_colors.dart` | Định nghĩa toàn bộ color tokens cho Light Mode và Dark Mode chuẩn Apple | Sửa |
| `lib/core/theme/app_theme.dart` | Định nghĩa `ThemeData.lightTheme` và `ThemeData.darkTheme` | Sửa |
| `test/theme_test.dart` | Kiểm thử unit test cho theme tokens và quy tắc cấm màu đỏ Viettel | Mới |
| `lib/core/services/storage_service.dart` | Thêm persistence cho `ThemeMode` (`getThemeMode`, `saveThemeMode`) | Sửa |
| `test/storage_service_test.dart` | Kiểm thử unit test cho lưu trữ `ThemeMode` | Sửa |
| `lib/main.dart` | Cung cấp `themeNotifier` toàn cục, bọc `ValueListenableBuilder` cho `MaterialApp` | Sửa |
| `lib/core/widgets/apple_card.dart` | Widget thẻ chuẩn Apple (16px radius, viền 1px tinh tế, đổi màu theo theme) | Mới |
| `lib/core/widgets/vht_card.dart` | Tương thích ngược chuyển tiếp sang `AppleCard` | Sửa |
| `lib/screens/home/widgets/qr_hero_card.dart` | Thẻ Quét QR chuẩn Apple Grouped Card | Sửa |
| `lib/screens/home/widgets/session_card.dart` | Thẻ phiên làm việc tối giản với badge tài khoản Google và action menu | Sửa |
| `lib/screens/home/home_screen.dart` | Hub Trang chủ với nút toggle theme (☀️/🌙), layout Grouped List | Sửa |
| `lib/screens/scanner/scanner_screen.dart` | Khung ngắm Viewfinder 4 góc chuẩn Apple Camera (bỏ tia laser màu mè) | Sửa |
| `lib/screens/remote/widgets/floating_capsule.dart` | Viên thuốc Dynamic Island kính mờ `BackdropFilter` | Sửa |
| `lib/screens/remote/remote_screen.dart` | Thanh loading xanh Apple 2px và banner báo mất kết nối nhã nhặn | Sửa |

---

### Task 1: Hệ Thống Design Tokens & AppTheme Light / Dark

**Files:**
- Create: `test/theme_test.dart`
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Viết failing test kiểm tra theme tokens & quy tắc cấm màu đỏ Viettel**

Tạo tệp `test/theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/theme/app_colors.dart';
import 'package:antigravity_support/core/theme/app_theme.dart';

void main() {
  test('AppColors Light and Dark tokens must not contain Viettel red', () {
    const viettelRedPrimary = 0xFFEE0033;
    const viettelRedDark = 0xFF61000E;

    final allColors = [
      AppColors.lightBackground,
      AppColors.lightSurface,
      AppColors.lightPrimary,
      AppColors.darkBackground,
      AppColors.darkSurface,
      AppColors.darkPrimary,
      AppColors.statusSuccess,
      AppColors.statusSuccessDark,
    ];

    for (final color in allColors) {
      expect(color.value, isNot(equals(viettelRedPrimary)));
      expect(color.value, isNot(equals(viettelRedDark)));
    }
  });

  test('AppTheme provides valid lightTheme and darkTheme', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/theme_test.dart`  
Expected: FAIL với lỗi compilation `"The getter 'lightBackground' isn't defined"`.

- [ ] **Step 3: Triển khai mã nguồn đầy đủ cho AppColors và AppTheme**

Cập nhật `lib/core/theme/app_colors.dart`:
```dart
import 'package:flutter/material.dart';

/// Hệ thống bảng màu Apple Cupertino Clean Style (HIG)
/// Hỗ trợ cả 2 giao diện Light Mode và Dark Mode.
/// Tuyệt đối không sử dụng bất kỳ sắc thái nào của màu đỏ Viettel (#EE0033, #61000E).
class AppColors {
  // --- LIGHT MODE PALETTE (Apple iOS Standard) ---
  static const Color lightBackground = Color(0xFFF2F2F7);       // System Grouped Background
  static const Color lightSurface = Color(0xFFFFFFFF);          // Card/Elevated White
  static const Color lightSurfaceSecondary = Color(0xFFE5E5EA); // Secondary Fill Gray
  static const Color lightPrimary = Color(0xFF007AFF);          // Apple System Blue
  static const Color lightPrimaryLight = Color(0xFFEBF5FF);     // Soft Blue Tint for Badges
  static const Color lightBorder = Color(0xFFE5E5EA);           // Subtle 1px Divider/Border
  static const Color lightTextPrimary = Color(0xFF000000);      // Pure Black
  static const Color lightTextSecondary = Color(0xFF8E8E93);    // System Gray (Secondary)
  static const Color lightTextMuted = Color(0xFFAEAEB2);        // System Gray 2

  // --- DARK MODE PALETTE (Apple OLED Dark) ---
  static const Color darkBackground = Color(0xFF000000);        // True OLED Black
  static const Color darkSurface = Color(0xFF1C1C1E);           // Apple Dark Elevated Card
  static const Color darkSurfaceSecondary = Color(0xFF2C2C2E);  // Secondary Dark Fill
  static const Color darkPrimary = Color(0xFF0A84FF);           // Apple Dark System Blue
  static const Color darkPrimaryLight = Color(0x260A84FF);      // 15% opacity Dark Blue
  static const Color darkBorder = Color(0xFF2C2C2E);            // Subtle 1px Dark Border
  static const Color darkTextPrimary = Color(0xFFFFFFFF);       // Pure White
  static const Color darkTextSecondary = Color(0xFF8E8E93);     // System Gray
  static const Color darkTextMuted = Color(0xFF636366);         // System Gray 3

  // --- SEMANTIC STATUS COLORS ---
  static const Color statusSuccess = Color(0xFF34C759);         // Apple System Green Light
  static const Color statusSuccessDark = Color(0xFF30D158);     // Apple System Green Dark
  static const Color statusWarning = Color(0xFFFF9F0A);         // Apple System Orange
  static const Color statusNeutral = Color(0xFF8E8E93);         // Apple Neutral Gray

  // --- BACKWARD COMPATIBILITY ALIASES ---
  static const Color brandPrimary = lightPrimary;
  static const Color brandPrimaryLight = Color(0xFF5AC8FA);
  static const Color accentCyan = Color(0xFF007AFF);
  static const Color stateSuccess = statusSuccess;
  static const Color stateWarning = statusWarning;
  static const Color stateNeutral = statusNeutral;
  static const Color bgDark = darkBackground;
  static const Color surfaceDark = darkSurface;
  static const Color surfaceDarkElevated = darkSurfaceSecondary;
  static const Color borderSubtle = darkBorder;
  static const Color borderHighlight = Color(0xFF3A3A3C);
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
}
```

Cập nhật `lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: 'SF Pro Text',
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightPrimary,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.statusWarning,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'SF Pro Text',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkPrimary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.statusWarning,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Chạy lại test để xác nhận test vượt qua thành công**

Run: `flutter test test/theme_test.dart`  
Expected: All tests pass (0 failures).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/core/theme/app_theme.dart test/theme_test.dart
git commit -m "feat(theme): add Apple Cupertino light and dark theme tokens"
```

---

### Task 2: Lưu Trữ ThemeMode & Bộ Điều Khiển Giao Diện Toàn Cục

**Files:**
- Modify: `lib/core/services/storage_service.dart`
- Modify: `test/storage_service_test.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Viết test cho `saveThemeMode` và `getThemeMode` trong StorageService**

Bổ sung test vào `test/storage_service_test.dart`:
```dart
  test('Save and retrieve ThemeMode', () async {
    expect(storageService.getThemeMode(), ThemeMode.system);

    await storageService.saveThemeMode(ThemeMode.light);
    expect(storageService.getThemeMode(), ThemeMode.light);

    await storageService.saveThemeMode(ThemeMode.dark);
    expect(storageService.getThemeMode(), ThemeMode.dark);

    await storageService.saveThemeMode(ThemeMode.system);
    expect(storageService.getThemeMode(), ThemeMode.system);
  });
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/storage_service_test.dart`  
Expected: FAIL với lỗi `"The method 'getThemeMode' isn't defined"`.

- [ ] **Step 3: Triển khai lưu trữ ThemeMode trong StorageService và cấu hình main.dart**

Cập nhật `lib/core/services/storage_service.dart`:
```dart
  static const String _themeModeKey = 'antigravity_theme_mode';

  ThemeMode getThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    if (raw == 'light') return ThemeMode.light;
    if (raw == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) {
      await _prefs.remove(_themeModeKey);
    } else {
      await _prefs.setString(_themeModeKey, mode == ThemeMode.light ? 'light' : 'dark');
    }
  }
```

Cập nhật `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.init();
  appThemeNotifier.value = storageService.getThemeMode();

  runApp(AntigravityApp(storageService: storageService));
}

class AntigravityApp extends StatelessWidget {
  final StorageService storageService;

  const AntigravityApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Antigravity Remote',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: HomeScreen(
            storageService: storageService,
            themeNotifier: appThemeNotifier,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Chạy lại test xác nhận vượt qua**

Run: `flutter test test/storage_service_test.dart`  
Expected: PASS all tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage_service.dart test/storage_service_test.dart lib/main.dart
git commit -m "feat(theme): add persistent ThemeMode controller in main and StorageService"
```

---

### Task 3: Widget Thẻ AppleCard & Thẻ Quét QR QrHeroCard Chuẩn Cupertino

**Files:**
- Create: `lib/core/widgets/apple_card.dart`
- Modify: `lib/core/widgets/vht_card.dart`
- Modify: `lib/screens/home/widgets/qr_hero_card.dart`

- [ ] **Step 1: Tạo widget AppleCard thích ứng động với Light và Dark Theme**

Tạo tệp `lib/core/widgets/apple_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderSide? border;

  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final defaultBorderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(
          border ?? BorderSide(color: defaultBorderColor, width: 1),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
```

Cập nhật `lib/core/widgets/vht_card.dart` để tái sử dụng `AppleCard` (duy trì tương thích):
```dart
import 'package:flutter/material.dart';
import 'apple_card.dart';

class VhtCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderSide? border;

  const VhtCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return AppleCard(
      padding: padding,
      onTap: onTap,
      border: border,
      child: child,
    );
  }
}
```

- [ ] **Step 2: Tái thiết kế QrHeroCard theo phong cách Apple Grouped Card**

Cập nhật `lib/screens/home/widgets/qr_hero_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/apple_card.dart';

class QrHeroCard extends StatelessWidget {
  final VoidCallback onOpenScanner;
  final VoidCallback onPasteLink;

  const QrHeroCard({
    super.key,
    required this.onOpenScanner,
    required this.onPasteLink,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final iconBgColor = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final secondaryBtnBg = isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary;

    return AppleCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quét mã QR Desktop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kết nối tức thì tới Antigravity 2.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Mở Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: onOpenScanner,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  backgroundColor: secondaryBtnBg,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: Icon(Icons.link, size: 18, color: textSecondary),
                label: const Text('Dán link', style: TextStyle(fontWeight: FontWeight.w500)),
                onPressed: onPasteLink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Phân tích cú pháp và kiểm thử**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/apple_card.dart lib/core/widgets/vht_card.dart lib/screens/home/widgets/qr_hero_card.dart
git commit -m "feat(ui): add AppleCard and redesign QrHeroCard in Cupertino clean style"
```

---

### Task 4: Thẻ Phiên Làm Việc SessionCard & Hub HomeScreen với Nút Toggle Theme

**Files:**
- Modify: `lib/screens/home/widgets/session_card.dart`
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Tái thiết kế SessionCard với Account Badge chuẩn Cupertino**

Cập nhật `lib/screens/home/widgets/session_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/widgets/apple_card.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../models/remote_session.dart';

class SessionCard extends StatelessWidget {
  final RemoteSession session;
  final VoidCallback onConnect;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const SessionCard({
    super.key,
    required this.session,
    required this.onConnect,
    required this.onOpenInBrowser,
    required this.onRename,
    required this.onDelete,
    required this.onTogglePin,
  });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa kết nối';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final badgeBg = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;
    final isRecent = DateTime.now().difference(session.lastAccessedAt).inHours < 2;

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onConnect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(isOnline: isRecent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 14, color: primaryColor),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 20, color: textSecondary),
                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'browser') onOpenInBrowser();
                  if (val == 'rename') onRename();
                  if (val == 'delete') onDelete();
                  if (val == 'pin') onTogglePin();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(session.isPinned ? 'Bỏ ghim' : 'Ghim lên đầu'),
                  ),
                  const PopupMenuItem(
                    value: 'browser',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_browser, size: 16),
                        SizedBox(width: 8),
                        Text('Mở trình duyệt ngoài'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Đổi tên thiết bị'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa phiên này', style: TextStyle(color: AppColors.statusWarning)),
                  ),
                ],
              ),
            ],
          ),

          if (session.email != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alternate_email, size: 11, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    session.email!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${UrlParser.getShortSessionId(session.id)} • ${_formatTime(session.lastAccessedAt)}',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
              InkWell(
                onTap: onConnect,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Vào lại',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 10, color: primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Nâng cấp HomeScreen với nút Theme Toggle (☀️/🌙) và Grouped Apple Layout**

Cập nhật `lib/screens/home/home_screen.dart`:
- Nhận `ValueNotifier<ThemeMode>? themeNotifier`.
- Thêm action button trên AppBar cho phép chuyển nhanh giữa Light, Dark và System.
- Cập nhật section header chuẩn Apple Settings: `THIẾT BỊ GẦN ĐÂY` (uppercase 11px, màu `textSecondary`).
- Trạng thái rỗng (Empty state) với icon máy tính tối giản.

- [ ] **Step 3: Chạy test & kiểm tra phân tích**

Run: `flutter analyze && flutter test`  
Expected: 0 issues, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/widgets/session_card.dart lib/screens/home/home_screen.dart
git commit -m "feat(ui): update HomeScreen and SessionCard with Apple Cupertino styling and theme toggle"
```

---

### Task 5: Màn Hình Quét Camera Viewfinder Chuẩn Apple Tối Giản

**Files:**
- Modify: `lib/screens/scanner/scanner_screen.dart`

- [ ] **Step 1: Tái cấu trúc ScannerScreen với khung ngắm Viewfinder 4 góc (bỏ tia laser màu mè)**

Cập nhật `lib/screens/scanner/scanner_screen.dart`:
- Khung ngắm 260x260px với 4 góc bo trắng (Corner brackets) dày 3px, bo góc 16px.
- Xung quanh là lớp phủ bán trong suốt màu đen dịu mắt (`Colors.black54`).
- Nút Bật/Tắt Flash (⚡️) và nút Đóng (✕) dạng hình tròn kính mờ.
- Nút "Dán link từ Clipboard" tinh giản ở chân màn hình.

- [ ] **Step 2: Chạy kiểm tra phân tích tĩnh**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/screens/scanner/scanner_screen.dart
git commit -m "feat(scanner): redesign camera viewfinder to Apple minimalist style"
```

---

### Task 6: Viên Thuốc Điều Khiển Dynamic Island Capsule & Trình Xem Remote

**Files:**
- Modify: `lib/screens/remote/widgets/floating_capsule.dart`
- Modify: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Tái cấu trúc FloatingCapsule thành Dynamic Island kính mờ**

Cập nhật `lib/screens/remote/widgets/floating_capsule.dart`:
- Kính mờ `BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))`.
- Nền đen bán trong suốt `rgba(28, 28, 30, 0.85)` cùng viền mảnh tinh tế 1px.
- Trạng thái thu gọn: Viên thuốc nhỏ gọn 36px hiển thị icon trạng thái.
- Trạng thái mở rộng: Menu điều khiển trực quan (Đổi tài khoản, Wakelock, Reload, Copy URL, Mở trình duyệt ngoài, Về trang chủ).

- [ ] **Step 2: Hoàn thiện thanh tải và banner kết nối trong RemoteScreen**

Cập nhật `lib/screens/remote/remote_screen.dart`:
- Thanh tải tiến trình (LinearProgressIndicator) màu xanh Apple mỏng 2px ở mép trên.
- Banner mất kết nối xám mờ tinh tế, không dùng viền đỏ gay gắt.

- [ ] **Step 3: Chạy kiểm tra phân tích tĩnh**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 4: Commit**

```bash
git add lib/screens/remote/widgets/floating_capsule.dart lib/screens/remote/remote_screen.dart
git commit -m "feat(remote): polish FloatingCapsule to Apple Dynamic Island and refine remote viewer"
```

---

### Task 7: Xác Minh Toàn Diện & Kiểm Tra Biên Dịch APK

**Files:**
- Test: `test/`

- [ ] **Step 1: Chạy toàn bộ test tự động**

Run: `flutter test`  
Expected: PASS 100% tất cả test suites.

- [ ] **Step 2: Chạy phân tích lint toàn bộ dự án**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Chạy biên dịch APK Debug trên môi trường máy tính**

Run: `flutter build apk --debug`  
Expected: Build thành công tạo ra file APK tại `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Commit hoàn tất**

```bash
git commit --allow-empty -m "chore: complete Apple Cupertino clean dual theme overhaul and verification"
```
