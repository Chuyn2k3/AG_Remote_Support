# Full-Spectrum Mobile Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full-spectrum mobile application security hardening across 4 layers (Network/Input, WebView Sandbox, OS Anti-Snapshot/Backup, and Data-at-Rest Storage) in compliance with OWASP MASVS standards.

**Architecture:** 
- Network & Input Layer: Enforce HTTPS-only, RFC 3986 host validation in `UrlParser`, and OS-level cleartext ban via Android `network_security_config.xml`.
- WebView Sandbox Layer: Disable local file access (`allowFileAccess=false`, `allowUniversalAccess=false`), ban mixed content (`MIXED_CONTENT_NEVER_ALLOW`), and enforce strict domain whitelisting in `shouldOverrideUrlLoading`.
- OS & Privacy Layer: Disable `allowBackup` in `AndroidManifest.xml`, implement native `FLAG_SECURE` channel on Android, and Privacy Shield blur in iOS `AppDelegate.swift`.
- Storage Layer: Obfuscated AES/XOR cipher with device salt for `RemoteSession` storage in `StorageService`.

**Tech Stack:** Flutter 3.5.4, Dart, Android Native Kotlin (WindowManager.FLAG_SECURE), iOS Swift (UIVisualEffectView), InAppWebView, SharedPreferences.

---

### Task 1: Strict URL Parsing & Input Sanitization (`UrlParser`)

**Files:**
- Modify: `lib/core/utils/url_parser.dart`
- Test: `test/url_parser_test.dart`

- [ ] **Step 1: Write the failing tests for attack vectors**

Update `test/url_parser_test.dart` to include malicious inputs (HTTP downgrade, open redirect, subdomain poisoning, XSS payloads):

```dart
    test('isAntigravityUrl rejects http protocol downgrade', () {
      expect(UrlParser.isAntigravityUrl('http://antigravity.google.com/r/abc-123'), isFalse);
    });

    test('isAntigravityUrl rejects open redirect attacks on google domain', () {
      expect(UrlParser.isAntigravityUrl('https://evil.com?redirect=antigravity.google.com'), isFalse);
      expect(UrlParser.isAntigravityUrl('https://evil.com/r/antigravity.google.com'), isFalse);
    });

    test('isAntigravityUrl rejects spoofed subdomains', () {
      expect(UrlParser.isAntigravityUrl('https://antigravity.google.com.evil.com/r/abc-123'), isFalse);
    });

    test('isAntigravityUrl validates legitimate accounts.google.com only with valid antigravity continue', () {
      expect(
        UrlParser.isAntigravityUrl('https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F123'),
        isTrue,
      );
      expect(
        UrlParser.isAntigravityUrl('https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fevil.com'),
        isFalse,
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/url_parser_test.dart`
Expected: FAIL on HTTP downgrade and Open Redirect attacks.

- [ ] **Step 3: Implement strict URL parsing in `UrlParser`**

Edit `lib/core/utils/url_parser.dart`:

```dart
class UrlParser {
  /// Kiểm tra xem URL có phải là đường link Antigravity hợp lệ hay không (chuẩn HTTPS + domain)
  static bool isAntigravityUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;

    // 1. Chỉ chấp nhận giao thức HTTPS an toàn
    if (uri.scheme != 'https') return false;

    final host = uri.host.toLowerCase();

    // 2. Miền chính thức Antigravity
    if (host == 'antigravity.google.com' && uri.path.contains('/r/')) {
      return true;
    }

    // 3. Miền đăng nhập Google Accounts (Chỉ chấp nhận khi target continue trỏ về antigravity.google.com)
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/url_parser_test.dart`
Expected: PASS (All tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/url_parser.dart test/url_parser_test.dart
git commit -m "security(url): enforce https and strict domain validation in UrlParser"
```

---

### Task 2: Data-at-Rest Storage Obfuscation & Emergency Wipe (`StorageService`)

**Files:**
- Modify: `lib/core/services/storage_service.dart`
- Test: `test/storage_service_test.dart`

- [ ] **Step 1: Write the failing test for obfuscation and wipe**

Add tests in `test/storage_service_test.dart`:

```dart
    test('StorageService saves sessions in obfuscated format instead of plaintext', () async {
      final session = RemoteSession(
        id: 'sec-1',
        title: 'Secure Session',
        url: 'https://antigravity.google.com/r/sec-1',
        lastAccessedAt: DateTime.now(),
      );

      await storageService.upsertSession(session);
      final rawList = prefs.getStringList('antigravity_remote_sessions')!;
      expect(rawList.first.startsWith('enc:v1:'), isTrue);
      expect(rawList.first.contains('https://antigravity.google.com'), isFalse);

      final retrieved = storageService.getSessions();
      expect(retrieved.first.url, equals('https://antigravity.google.com/r/sec-1'));
    });

    test('StorageService emergencyWipe clears all sessions and configs', () async {
      await storageService.emergencyWipe();
      expect(storageService.getSessions(), isEmpty);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_test.dart`
Expected: FAIL on `enc:v1:` check.

- [ ] **Step 3: Implement obfuscation & emergency wipe in `StorageService`**

Edit `lib/core/services/storage_service.dart`:
- Add `_obfuscate(String input)` and `_deobfuscate(String input)`.
- Use a persistent device salt with XOR + Base64 prefix `enc:v1:`.
- Provide backward compatibility: If input starts with `{` (plain json), parse directly and migrate upon next save.
- Implement `emergencyWipe()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/storage_service.dart test/storage_service_test.dart
git commit -m "security(storage): implement session obfuscation and emergency wipe"
```

---

### Task 3: Android OS Hardening (`network_security_config.xml` & `AndroidManifest.xml`)

**Files:**
- Create: `android/app/src/main/res/xml/network_security_config.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Create `network_security_config.xml`**

Create `android/app/src/main/res/xml/network_security_config.xml`:

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

- [ ] **Step 2: Update `AndroidManifest.xml`**

In `android/app/src/main/AndroidManifest.xml`:
- In `<application>`:
  - Add `android:allowBackup="false"`
  - Add `android:fullBackupContent="false"`
  - Add `android:networkSecurityConfig="@xml/network_security_config"`

- [ ] **Step 3: Verify Android configuration**

Run: `flutter build apk --debug`
Expected: SUCCESS (Gradle builds with new network config).

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/res/xml/network_security_config.xml android/app/src/main/AndroidManifest.xml
git commit -m "security(android): disable adb backup and enforce network security config"
```

---

### Task 4: Anti-Snapshot Protection (`FLAG_SECURE` on Android & Privacy Shield on iOS)

**Files:**
- Modify: `android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `lib/core/services/app_lifecycle_service.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Implement Security Channel in `MainActivity.kt`**

In `android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt`:
- Add `SECURITY_CHANNEL = "dev.antigravity.remote/security"`
- Handle `"setSecureFlag"`:
  ```kotlin
  val enabled = call.argument<Boolean>("enabled") ?: true
  if (enabled) {
      window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
  } else {
      window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
  }
  result.success(true)
  ```

- [ ] **Step 2: Implement Privacy Shield in `ios/Runner/AppDelegate.swift`**

In `ios/Runner/AppDelegate.swift`:
- Add `var privacyBlurView: UIVisualEffectView?`
- In `applicationWillResignActive`:
  Create `UIBlurEffect(style: .dark)` full screen overlay on `window`.
- In `applicationDidBecomeActive`:
  Remove `privacyBlurView` with fade animation.

- [ ] **Step 3: Connect security channel in `AppLifecycleService` / `main.dart`**

Add helper `SecurityService.setSecureFlag(bool enabled)`:
When `_isLocked == true` or `AppLifecycleState.paused` -> enable `FLAG_SECURE`.
When unlocked in foreground -> clear `FLAG_SECURE`.

- [ ] **Step 4: Verify flutter analyze and tests**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/dev/antigravity/remote/MainActivity.kt ios/Runner/AppDelegate.swift lib/core/services/app_lifecycle_service.dart lib/main.dart
git commit -m "security(native): implement FLAG_SECURE on Android and Privacy Shield on iOS"
```

---

### Task 5: WebView Sandbox Hardening & Navigation Whitelist (`RemoteScreen`)

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Update `InAppWebViewSettings` flags**

In `lib/screens/remote/remote_screen.dart`:
- Set `allowFileAccessFromFileURLs: false`
- Set `allowUniversalAccessFromFileURLs: false`
- Set `allowContentAccess: false`
- Set `mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW`
- Set `javaScriptCanOpenWindowsAutomatically: false`

- [ ] **Step 2: Implement Whitelist Domain Filter in `shouldOverrideUrlLoading`**

In `shouldOverrideUrlLoading`:
```dart
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.CANCEL;

        // Chỉ cho phép https
        if (uri.scheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }

        final host = uri.host.toLowerCase();
        final bool isAllowed = host == 'antigravity.google.com' ||
            host == 'accounts.google.com' ||
            host.endsWith('.google.com') ||
            host.endsWith('.usercontent.goog');

        if (!isAllowed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFE53935),
                content: Text('⚠️ Chặn điều hướng không an toàn tới: $host'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
```

- [ ] **Step 3: Add Origin validation on JS handlers**

Validate that controller current URL is an Antigravity host before processing `onAIResponseDone` and `onUserPromptSent`.

- [ ] **Step 4: Run full verification suite**

Run: `flutter analyze`
Run: `flutter test`
Run: `flutter build apk --debug`
Expected: 0 issues, 100% tests pass, APK builds successfully.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "security(webview): enforce sandbox, block file access, and add navigation whitelist"
```
