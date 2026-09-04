# Antigravity 2.0 Remote Wrapper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng ứng dụng mobile Flutter hoàn chỉnh bọc web remote control của Antigravity 2.0 theo chuẩn thiết kế VHT Modern Minimalism (không dùng màu đỏ, font Roboto), tích hợp Quét mã QR, Full-screen WebView với cơ chế vượt lỗi Google OAuth, Giữ sáng màn hình (Wakelock) và Floating Capsule menu.

**Architecture:** Áp dụng Clean Layered Architecture trong Flutter: tầng Presentation tách biệt (HomeScreen Hub, ScannerScreen, RemoteScreen, FloatingCapsuleWidget), tầng Services (WakelockService, StorageService, UrlParser), tầng Model (RemoteSession), tuân thủ chặt chẽ Design Tokens chuẩn VHT.

**Tech Stack:** Flutter 3.24.4 / Dart 3.5.4, `flutter_inappwebview: ^6.1.5`, `mobile_scanner: ^6.0.11`, `wakelock_plus: ^1.4.0`, `shared_preferences: ^2.5.3`, `flutter_animate: ^4.5.2`.

---

## File Structure Map

```
antigravity_support/
├── android/app/src/main/AndroidManifest.xml   # Cấu hình quyền Internet & Camera
├── ios/Runner/Info.plist                      # Cấu hình NSCameraUsageDescription
├── pubspec.yaml                               # Khai báo các dependencies
├── lib/
│   ├── main.dart                              # Khởi tạo App & System UI overlays
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_colors.dart                # Bảng màu VHT chuẩn (Không màu đỏ)
│   │   │   └── app_theme.dart                 # ThemeData Dark Mode & Typography Roboto
│   │   ├── utils/
│   │   │   └── url_parser.dart                # Bóc tách Session ID, validate link Antigravity
│   │   ├── services/
│   │   │   ├── storage_service.dart           # Đọc/ghi lịch sử phiên (SharedPreferences)
│   │   │   └── wakelock_service.dart          # Điều khiển giữ sáng màn hình
│   │   └── widgets/
│   │       ├── vht_card.dart                  # Thẻ bo góc 12px chuẩn VHT
│   │       └── status_dot.dart                # Chấm tròn Online/Idle
│   ├── models/
│   │   └── remote_session.dart                # Entity Session (id, url, title, lastActive)
│   └── screens/
│       ├── home/
│       │   ├── home_screen.dart               # Màn hình Hub chính
│       │   └── widgets/
│       │       ├── qr_hero_card.dart          # Thẻ quét QR nổi bật
│       │       └── session_card.dart          # Item từng phiên làm việc
│       ├── scanner/
│       │   └── scanner_screen.dart            # Camera quét QR với tia laser
│       └── remote/
│           ├── remote_screen.dart             # InAppWebView full-screen + Google OAuth setup
│           └── widgets/
│               └── floating_capsule.dart      # Menu kính mờ kéo thả
└── test/
    ├── url_parser_test.dart                   # Unit test cho logic parse URL Antigravity
    └── storage_service_test.dart              # Unit test cho StorageService
```

---

## Tasks

### Task 1: Thiết lập Dependencies & Cấu hình Quyền Nền tảng (Platform Permissions)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Cập nhật pubspec.yaml với các thư viện cần thiết**

Thêm các package: `flutter_inappwebview`, `mobile_scanner`, `wakelock_plus`, `shared_preferences`, `flutter_animate`.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview: ^6.1.5
  mobile_scanner: ^6.0.11
  wakelock_plus: ^1.4.0
  shared_preferences: ^2.5.3
  flutter_animate: ^4.5.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

- [ ] **Step 2: Chạy `flutter pub get`**

Run: `flutter pub get`
Expected output: `Process finished with exit code 0`

- [ ] **Step 3: Cấu hình Android Permissions trong AndroidManifest.xml**

File: `android/app/src/main/AndroidManifest.xml`
Thêm các thẻ quyền ngay trước `<application>`:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
```

- [ ] **Step 4: Cấu hình iOS Camera Description trong Info.plist**

File: `ios/Runner/Info.plist`
Thêm permission string trước `</dict>`:
```xml
	<key>NSCameraUsageDescription</key>
	<string>Ứng dụng cần quyền truy cập Camera để quét mã QR kết nối Antigravity Remote.</string>
```

- [ ] **Step 5: Commit changes**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: setup dependencies and native camera/internet permissions"
```

---

### Task 2: Xây dựng Design System & Theme chuẩn VHT Minimalism (Non-Red)

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Tạo `lib/core/theme/app_colors.dart`**

Tập trung đầy đủ bảng màu chuẩn VHT, loại bỏ hoàn toàn màu đỏ:
```dart
import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors (Thay thế màu đỏ bằng Tím AI & Cyan)
  static const Color brandPrimary = Color(0xFF7A5AF8);    // Modern AI Violet
  static const Color brandPrimaryLight = Color(0xFF9B82F9);
  static const Color accentCyan = Color(0xFF0284C7);       // Tech Blue / In-Progress

  // Trạng thái chuẩn VHT (Trang 8 & 10 tài liệu VHT)
  static const Color stateSuccess = Color(0xFF10B981);     // Xanh lá Online / Hoàn thành
  static const Color stateWarning = Color(0xFFFEBA00);     // Vàng Cảnh báo / Keep Awake
  static const Color stateNeutral = Color(0xFF64748B);     // Xám trạng thái Idle

  // Surfaces & Backgrounds
  static const Color bgDark = Color(0xFF0F1012);           // Nền chính tối sâu
  static const Color surfaceDark = Color(0xFF18191B);      // Nền thẻ card
  static const Color surfaceDarkElevated = Color(0xFF222428);
  static const Color borderSubtle = Color(0xFF2F3033);     // Viền ngăn cách 1px
  static const Color borderHighlight = Color(0xFF383A40);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);      // Trắng ngà
  static const Color textSecondary = Color(0xFF94A3B8);    // Xám bạc
  static const Color textMuted = Color(0xFF64748B);        // Xám tối
}
```

- [ ] **Step 2: Tạo `lib/core/theme/app_theme.dart`**

Cấu hình `ThemeData.dark()` với font `Roboto` và các shape bo góc 12px:
```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimary,
        secondary: AppColors.accentCyan,
        surface: AppColors.surfaceDark,
        error: AppColors.stateWarning,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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

- [ ] **Step 3: Chạy `flutter analyze` để kiểm tra cú pháp**

Run: `flutter analyze`
Expected output: `No issues found!`

- [ ] **Step 4: Commit changes**

```bash
git add lib/core/theme/
git commit -m "feat(theme): add VHT minimalist design tokens and dark theme"
```

---

### Task 3: Data Model & UrlParser Logic (với TDD)

**Files:**
- Create: `lib/models/remote_session.dart`
- Create: `lib/core/utils/url_parser.dart`
- Test: `test/url_parser_test.dart`

- [ ] **Step 1: Viết failing test `test/url_parser_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/utils/url_parser.dart';

void main() {
  group('UrlParser Tests', () {
    const validGoogleUrl =
        'https://accounts.google.com/AccountChooser?Email=phamdoan060801%40gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F328cc6cd-005f-4647-b021-17c7681f6407-v2';
    const validDirectUrl =
        'https://antigravity.google.com/r/328cc6cd-005f-4647-b021-17c7681f6407-v2';
    const invalidUrl = 'https://google.com/search?q=test';

    test('isAntigravityUrl returns true for valid URLs', () {
      expect(UrlParser.isAntigravityUrl(validGoogleUrl), isTrue);
      expect(UrlParser.isAntigravityUrl(validDirectUrl), isTrue);
      expect(UrlParser.isAntigravityUrl(invalidUrl), isFalse);
    });

    test('extractSessionId extracts correct ID', () {
      expect(UrlParser.extractSessionId(validGoogleUrl),
          '328cc6cd-005f-4647-b021-17c7681f6407-v2');
      expect(UrlParser.extractSessionId(validDirectUrl),
          '328cc6cd-005f-4647-b021-17c7681f6407-v2');
      expect(UrlParser.extractSessionId(invalidUrl), isNull);
    });

    test('getShortSessionId truncates properly', () {
      expect(UrlParser.getShortSessionId('328cc6cd-005f-4647-b021-17c7681f6407-v2'),
          '328cc6cd...v2');
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test FAIL**

Run: `flutter test test/url_parser_test.dart`
Expected: Compile failure / file not found `url_parser.dart`.

- [ ] **Step 3: Tạo `lib/models/remote_session.dart`**

```dart
class RemoteSession {
  final String id;
  final String rawUrl;
  String title;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  bool isPinned;

  RemoteSession({
    required this.id,
    required this.rawUrl,
    required this.title,
    required this.createdAt,
    required this.lastAccessedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawUrl': rawUrl,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory RemoteSession.fromJson(Map<String, dynamic> json) => RemoteSession(
        id: json['id'] as String,
        rawUrl: json['rawUrl'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
        isPinned: json['isPinned'] as bool? ?? false,
      );
}
```

- [ ] **Step 4: Tạo `lib/core/utils/url_parser.dart`**

```dart
class UrlParser {
  static bool isAntigravityUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (uri.host == 'antigravity.google.com' && uri.path.contains('/r/')) {
      return true;
    }

    if (uri.host == 'accounts.google.com' &&
        (url.contains('antigravity.google.com') || url.contains('%2Fantigravity.google.com'))) {
      return true;
    }

    return false;
  }

  static String? extractSessionId(String url) {
    if (!isAntigravityUrl(url)) return null;

    final regExp = RegExp(r'\/r\/([a-zA-Z0-9\-_]+)');
    final match = regExp.firstMatch(Uri.decodeFull(url));
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  static String getShortSessionId(String sessionId) {
    if (sessionId.length <= 12) return sessionId;
    final prefix = sessionId.substring(0, 8);
    final suffix = sessionId.contains('-v') ? sessionId.split('-').last : sessionId.substring(sessionId.length - 4);
    return '$prefix...$suffix';
  }
}
```

- [ ] **Step 5: Chạy test để xác nhận PASS**

Run: `flutter test test/url_parser_test.dart`
Expected output: `All tests passed!`

- [ ] **Step 6: Commit changes**

```bash
git add lib/models/ lib/core/utils/ test/url_parser_test.dart
git commit -m "feat(core): add RemoteSession model and UrlParser with unit tests"
```

---

### Task 4: StorageService & WakelockService (với TDD)

**Files:**
- Create: `lib/core/services/storage_service.dart`
- Create: `lib/core/services/wakelock_service.dart`
- Test: `test/storage_service_test.dart`

- [ ] **Step 1: Viết test `test/storage_service_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_support/core/services/storage_service.dart';
import 'package:antigravity_support/models/remote_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  test('Save and retrieve sessions list', () async {
    final session = RemoteSession(
      id: 'session-123',
      rawUrl: 'https://antigravity.google.com/r/session-123',
      title: 'Test Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await storageService.upsertSession(session);
    final sessions = storageService.getSessions();

    expect(sessions.length, 1);
    expect(sessions.first.id, 'session-123');
    expect(sessions.first.title, 'Test Session');
  });

  test('Delete session removes it from list', () async {
    final session = RemoteSession(
      id: 'session-123',
      rawUrl: 'https://antigravity.google.com/r/session-123',
      title: 'Test Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await storageService.upsertSession(session);
    await storageService.deleteSession('session-123');

    final sessions = storageService.getSessions();
    expect(sessions.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

Run: `flutter test test/storage_service_test.dart`
Expected: Compile failure.

- [ ] **Step 3: Tạo `lib/core/services/storage_service.dart`**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/remote_session.dart';

class StorageService {
  static const String _sessionsKey = 'antigravity_remote_sessions';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  List<RemoteSession> getSessions() {
    final rawList = _prefs.getStringList(_sessionsKey) ?? [];
    return rawList
        .map((item) => RemoteSession.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastAccessedAt.compareTo(a.lastAccessedAt);
      });
  }

  Future<void> upsertSession(RemoteSession session) async {
    final list = getSessions();
    final index = list.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.insert(0, session);
    }
    await _saveList(list);
  }

  Future<void> deleteSession(String id) async {
    final list = getSessions();
    list.removeWhere((s) => s.id == id);
    await _saveList(list);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_sessionsKey);
  }

  Future<void> _saveList(List<RemoteSession> list) async {
    final rawList = list.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_sessionsKey, rawList);
  }
}
```

- [ ] **Step 4: Tạo `lib/core/services/wakelock_service.dart`**

```dart
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      _isEnabled = true;
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      _isEnabled = false;
    } catch (_) {}
  }

  static Future<bool> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
    return _isEnabled;
  }
}
```

- [ ] **Step 5: Chạy test để xác nhận PASS**

Run: `flutter test test/storage_service_test.dart`
Expected output: `All tests passed!`

- [ ] **Step 6: Commit changes**

```bash
git add lib/core/services/ test/storage_service_test.dart
git commit -m "feat(services): implement StorageService and WakelockService"
```

---

### Task 5: Xây dựng Reusable UI Components (VHT Card & Status Dot)

**Files:**
- Create: `lib/core/widgets/vht_card.dart`
- Create: `lib/core/widgets/status_dot.dart`

- [ ] **Step 1: Tạo `lib/core/widgets/status_dot.dart`**

Hiển thị chấm trạng thái phát sáng chuẩn VHT (`#10B981` cho Online, `#64748B` cho Idle):
```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const StatusDot({
    super.key,
    required this.isOnline,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.stateSuccess : AppColors.stateNeutral;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}
```

- [ ] **Step 2: Tạo `lib/core/widgets/vht_card.dart`**

Component Card bo góc 12px, nền surface tối, viền subtle 1px chuẩn VHT Minimalism:
```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    final cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(
          border ?? const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
```

- [ ] **Step 3: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit changes**

```bash
git add lib/core/widgets/
git commit -m "feat(ui): add VHT card and status dot widgets"
```

---

### Task 6: Xây dựng Màn hình Quét QR (`ScannerScreen`)

**Files:**
- Create: `lib/screens/scanner/scanner_screen.dart`

- [ ] **Step 1: Tạo `lib/screens/scanner/scanner_screen.dart`**

Tích hợp `MobileScanner` controller, hiệu ứng tia laser quét di chuyển lên xuống bằng `flutter_animate`, các nút bật tắt Flash, đảo camera và dán link từ Clipboard:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && UrlParser.isAntigravityUrl(rawValue)) {
        _isProcessing = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, rawValue);
        break;
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (UrlParser.isAntigravityUrl(text)) {
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              'Link trong clipboard không phải link Antigravity hợp lệ',
              style: TextStyle(color: AppColors.stateWarning),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout
          SafeArea(
            child: Column(
              children: [
                // Top Bar Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Quét mã QR IDE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                            ),
                            icon: ValueListenableBuilder(
                              valueListenable: _controller,
                              builder: (context, state, child) {
                                return Icon(
                                  state.torchState == TorchState.on
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: state.torchState == TorchState.on
                                      ? AppColors.stateWarning
                                      : Colors.white,
                                );
                              },
                            ),
                            onPressed: () => _controller.toggleTorch(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                            ),
                            icon: const Icon(Icons.cameraswitch, color: Colors.white),
                            onPressed: () => _controller.switchCamera(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Central Viewfinder with Laser
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.brandPrimary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      color: AppColors.brandPrimary.withOpacity(0.04),
                    ),
                    child: Stack(
                      children: [
                        // Animated Scanning Laser
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.accentCyan,
                                AppColors.brandPrimary,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimary.withOpacity(0.8),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        )
                            .animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            )
                            .moveY(begin: 10, end: 220, duration: 1800.ms),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Manual Paste Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      const Text(
                        'Hướng camera vào mã QR Remote trên Antigravity Desktop',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.black50,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('Dán link từ Clipboard'),
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit changes**

```bash
git add lib/screens/scanner/
git commit -m "feat(scanner): implement ScannerScreen with laser animation and controls"
```

---

### Task 7: Xây dựng Floating Capsule & Remote Screen (InAppWebView Engine)

**Files:**
- Create: `lib/screens/remote/widgets/floating_capsule.dart`
- Create: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Tạo `lib/screens/remote/widgets/floating_capsule.dart`**

Menu kính mờ Glassmorphism kéo thả tự do, có 2 chế độ: Expanded (đầy đủ nút tiện ích) và Mini (chấm tròn nhỏ 38x38px không che nội dung):
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FloatingCapsule extends StatefulWidget {
  final bool isWakelockEnabled;
  final VoidCallback onToggleWakelock;
  final VoidCallback onReload;
  final VoidCallback onExit;
  final VoidCallback onCopyUrl;

  const FloatingCapsule({
    super.key,
    required this.isWakelockEnabled,
    required this.onToggleWakelock,
    required this.onReload,
    required this.onExit,
    required this.onCopyUrl,
  });

  @override
  State<FloatingCapsule> createState() => _FloatingCapsuleState();
}

class _FloatingCapsuleState extends State<FloatingCapsule> {
  bool _isMini = false;
  Offset _offset = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _offset.dx.clamp(10.0, screenSize.width - (_isMini ? 60.0 : 270.0)),
      top: _offset.dy.clamp(50.0, screenSize.height - 120.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isMini ? 20 : 30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: _isMini ? 8 : 14,
                vertical: _isMini ? 8 : 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.85),
                borderRadius: BorderRadius.circular(_isMini ? 20 : 30),
                border: Border.all(
                  color: AppColors.brandPrimary.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isMini ? _buildMiniView() : _buildExpandedView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniView() {
    return InkWell(
      onTap: () => setState(() => _isMini = false),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: const Icon(
          Icons.rocket_launch,
          size: 20,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keep Awake Toggle
        _buildActionButton(
          icon: widget.isWakelockEnabled ? Icons.lightbulb : Icons.lightbulb_outline,
          label: 'Sáng',
          color: widget.isWakelockEnabled ? AppColors.stateWarning : AppColors.textPrimary,
          onTap: widget.onToggleWakelock,
        ),
        _buildDivider(),
        // Reload Button
        _buildActionButton(
          icon: Icons.refresh,
          label: 'Tải lại',
          onTap: widget.onReload,
        ),
        _buildDivider(),
        // Copy URL
        _buildActionButton(
          icon: Icons.copy,
          label: 'Copy',
          onTap: widget.onCopyUrl,
        ),
        _buildDivider(),
        // Exit to Hub
        _buildActionButton(
          icon: Icons.home_outlined,
          label: 'Hub',
          onTap: widget.onExit,
        ),
        _buildDivider(),
        // Minimize Button
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          icon: const Icon(Icons.remove, size: 16, color: AppColors.textMuted),
          onPressed: () => setState(() => _isMini = true),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.textPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      color: AppColors.borderSubtle,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
```

- [ ] **Step 2: Tạo `lib/screens/remote/remote_screen.dart`**

Cấu hình InAppWebView với Custom User Agent vượt lỗi Google OAuth, lưu cookie tự động, thanh loading tuyến tính màu Cyan và kích hoạt Wakelock:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/wakelock_service.dart';
import '../../models/remote_session.dart';
import 'widgets/floating_capsule.dart';

class RemoteScreen extends StatefulWidget {
  final RemoteSession session;

  const RemoteScreen({super.key, required this.session});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isWakelock = false;

  // Custom User-Agent giả lập Chrome Mobile chuẩn để vượt 403 disallowed_useragent của Google OAuth
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initWakelock();
  }

  Future<void> _initWakelock() async {
    await WakelockService.enable();
    setState(() {
      _isWakelock = true;
    });
  }

  @override
  void dispose() {
    WakelockService.disable();
    super.dispose();
  }

  void _toggleWakelock() async {
    final status = await WakelockService.toggle();
    setState(() {
      _isWakelock = status;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.surfaceDark,
          content: Text(
            status ? '💡 Giữ sáng màn hình: ĐÃ BẬT' : '💡 Giữ sáng màn hình: ĐÃ TẮT',
            style: TextStyle(
              color: status ? AppColors.stateWarning : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.session.rawUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.surfaceDark,
        content: Text('📋 Đã sao chép link session', style: TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canGoBack = await _webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          _webViewController?.goBack();
        } else {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // InAppWebView
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.session.rawUrl)),
                initialSettings: InAppWebViewSettings(
                  userAgent: customUserAgent,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  cacheEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnLoadResource: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100.0;
                  });
                },
              ),

              // Thin Linear Progress Indicator (Tech Cyan)
              if (_progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    minHeight: 2.5,
                  ),
                ),

              // Floating Capsule Assistant
              FloatingCapsule(
                isWakelockEnabled: _isWakelock,
                onToggleWakelock: _toggleWakelock,
                onReload: () => _webViewController?.reload(),
                onCopyUrl: _copyUrl,
                onExit: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit changes**

```bash
git add lib/screens/remote/
git commit -m "feat(remote): implement RemoteScreen with InAppWebView and FloatingCapsule"
```

---

### Task 8: Xây dựng HomeScreen (Workspace Hub) & Widgets

**Files:**
- Create: `lib/screens/home/widgets/qr_hero_card.dart`
- Create: `lib/screens/home/widgets/session_card.dart`
- Create: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Tạo `lib/screens/home/widgets/qr_hero_card.dart`**

Thẻ quét mã QR với màu tím `#7A5AF8` tinh tế, nút mở camera và dán link:
```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B1926),
            Color(0xFF14151A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandPrimary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPrimary.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quét mã QR IDE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kết nối tức thì từ Antigravity Desktop',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderHighlight),
                  backgroundColor: AppColors.surfaceDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Dán link'),
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

- [ ] **Step 2: Tạo `lib/screens/home/widgets/session_card.dart`**

Hiển thị từng phiên kết nối gần đây kèm tên máy, status dot, session ID, nút vào lại và menu tùy chọn:
```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../core/widgets/vht_card.dart';
import '../../../models/remote_session.dart';

class SessionCard extends StatelessWidget {
  final RemoteSession session;
  final VoidCallback onConnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const SessionCard({
    super.key,
    required this.session,
    required this.onConnect,
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
    final shortId = UrlParser.getShortSessionId(session.id);
    final isRecent = DateTime.now().difference(session.lastAccessedAt).inHours < 2;

    return VhtCard(
      padding: const EdgeInsets.all(12),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 14, color: AppColors.brandPrimary),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                color: AppColors.surfaceDarkElevated,
                onSelected: (val) {
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
                    value: 'rename',
                    child: Text('Đổi tên gợi nhớ'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa phiên này', style: TextStyle(color: AppColors.stateWarning)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: $shortId • ${_formatTime(session.lastAccessedAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onConnect,
                child: const Text('Vào lại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Tạo `lib/screens/home/home_screen.dart`**

Màn hình chính điều phối danh sách phiên từ `StorageService`, tích hợp popup đổi tên, chuyển tiếp sang `ScannerScreen` và `RemoteScreen`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';
import '../../core/services/storage_service.dart';
import '../../models/remote_session.dart';
import '../scanner/scanner_screen.dart';
import '../remote/remote_screen.dart';
import 'widgets/qr_hero_card.dart';
import 'widgets/session_card.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<RemoteSession> _sessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _sessions = widget.storageService.getSessions();
    });
  }

  Future<void> _handleScannedUrl(String url) async {
    final sessionId = UrlParser.extractSessionId(url);
    if (sessionId == null) return;

    final existingIndex = _sessions.indexWhere((s) => s.id == sessionId);
    RemoteSession session;

    if (existingIndex >= 0) {
      session = _sessions[existingIndex];
      session.lastAccessedAt = DateTime.now();
    } else {
      session = RemoteSession(
        id: sessionId,
        rawUrl: url,
        title: 'Desktop • ${UrlParser.getShortSessionId(sessionId)}',
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
    }

    await widget.storageService.upsertSession(session);
    _loadSessions();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RemoteScreen(session: session)),
      ).then((_) => _loadSessions());
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null && mounted) {
      _handleScannedUrl(result);
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (UrlParser.isAntigravityUrl(text)) {
      _handleScannedUrl(text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              'Clipboard không chứa link Antigravity hợp lệ',
              style: TextStyle(color: AppColors.stateWarning),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(RemoteSession session) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkElevated,
        title: const Text('Đổi tên phiên làm việc', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Ví dụ: MacBook Công Ty',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.brandPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      session.title = newTitle;
      await widget.storageService.upsertSession(session);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.brandPrimary.withOpacity(0.4)),
              ),
              child: const Text(
                'REMOTE 2.0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Antigravity Hub'),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // QR Scan Card
            QrHeroCard(
              onOpenScanner: _openScanner,
              onPasteLink: _pasteLink,
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHIÊN GẦN ĐÂY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                if (_sessions.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await widget.storageService.clearAll();
                      _loadSessions();
                    },
                    child: const Text(
                      'Xóa tất cả',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Sessions List or Empty State
            if (_sessions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.devices_other, size: 36, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Chưa có phiên làm việc nào',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quét mã QR trên Antigravity Desktop để bắt đầu điều khiển.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._sessions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SessionCard(
                      session: s,
                      onConnect: () {
                        s.lastAccessedAt = DateTime.now();
                        widget.storageService.upsertSession(s);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RemoteScreen(session: s)),
                        ).then((_) => _loadSessions());
                      },
                      onRename: () => _showRenameDialog(s),
                      onDelete: () async {
                        await widget.storageService.deleteSession(s.id);
                        _loadSessions();
                      },
                      onTogglePin: () async {
                        s.isPinned = !s.isPinned;
                        await widget.storageService.upsertSession(s);
                        _loadSessions();
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit changes**

```bash
git add lib/screens/home/
git commit -m "feat(home): implement HomeScreen hub with QR hero and session card list"
```

---

### Task 9: Hoàn thiện `lib/main.dart` & Khởi chạy Toàn diện

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Cập nhật `lib/main.dart`**

Khởi tạo StorageService, cấu hình System UI overlay màu tối đồng bộ và chạy MaterialApp:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đặt màu status bar và navigation bar trong suốt / màu tối chuẩn VHT
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.init();

  runApp(AntigravityApp(storageService: storageService));
}

class AntigravityApp extends StatelessWidget {
  final StorageService storageService;

  const AntigravityApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Remote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(storageService: storageService),
    );
  }
}
```

- [ ] **Step 2: Chạy toàn bộ test suite**

Run: `flutter test`
Expected output: `All tests passed!`

- [ ] **Step 3: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected output: `No issues found!`

- [ ] **Step 4: Commit changes**

```bash
git add lib/main.dart
git commit -m "feat: complete application bootstrap in main.dart"
```

---

### Task 10: Kiểm thử Tổng thể & Nghiệm thu (Verification & Walkthrough)

**Files:**
- Create: Walkthrough documentation & verification log

- [ ] **Step 1: Chạy `flutter test`**

Run: `flutter test`
Expected output: `00:01 +2: All tests passed!`

- [ ] **Step 2: Chạy `flutter analyze`**

Run: `flutter analyze`
Expected output: `No issues found!`

- [ ] **Step 3: Kiểm tra link thực tế từ yêu cầu người dùng**

Kiểm tra với URL mẫu từ prompt:
`https://accounts.google.com/AccountChooser?Email=phamdoan060801%40gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F328cc6cd-005f-4647-b021-17c7681f6407-v2`
Xác nhận bóc tách chính xác Session ID: `328cc6cd-005f-4647-b021-17c7681f6407-v2`.

- [ ] **Step 4: Commit và hoàn tất**

```bash
git add .
git commit -m "chore: complete end-to-end implementation and verification"
```
