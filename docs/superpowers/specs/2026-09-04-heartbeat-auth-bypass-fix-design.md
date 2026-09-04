# Design Spec: Live Heartbeat & Direct Session Navigation Fix

- **Date:** 2026-09-04
- **Topic:** Fix false-positive offline status, repeated Google Account Chooser prompts, and improve cookie persistence.
- **Status:** Approved by User

---

## 1. Problem Statement
1. **False-positive Offline Status:**
   - In `HeartbeatService.probeSession`, the probe loaded `session.rawUrl` instead of `getTargetUrl(session)`. Because `session.rawUrl` typically points to `https://accounts.google.com/AccountChooser?Email=...`, the headless WebView hit Google's auth page (`res == 'auth_required'`).
   - The code treated `auth_required` as `DeviceStatus.offline` and unconditionally set `session.isDisconnected = true`, writing it to persistent storage (`SharedPreferences`).
   - Subsequent reloads or app launches read `session.isDisconnected == true`, rendering the cards grey/offline even when desktop machines were active.
2. **Repeated Google Account Chooser Prompts:**
   - In `RemoteScreen`, the WebView was launched directly with `widget.session.rawUrl` (`accounts.google.com/AccountChooser?...`).
   - Even if the user had authenticated previously, navigating to `AccountChooser` forced Google to display the account picker on every single card tap.
   - Furthermore, `CookieManager.instance().flush()` was never invoked on `onLoadStop`, meaning OAuth cookies were kept in volatile memory and not reliably synced to SQLite storage.

---

## 2. Architecture & Design Solution

### 2.1 Direct Antigravity Session URL Routing
- Modify `RemoteScreen` (initial request & retry) to load `HeartbeatService.getTargetUrl(widget.session)` directly: `https://antigravity.google.com/r/<sessionId>-v2`.
- When already logged in, navigating directly to the Antigravity instance completely bypasses the Account Chooser.
- If not logged in, Google naturally performs standard OAuth 302 redirects to `accounts.google.com`, allowing normal one-time authentication.

### 2.2 Persistent Cookie Flushing
- In `RemoteScreen.onLoadStop`, execute `await CookieManager.instance().flush()`.
- Flushes session cookies from RAM to SQLite disk storage so that Google credentials persist across app restarts and can be read by `HeadlessInAppWebView`.

### 2.3 Heartbeat Service Refactoring
- In `HeartbeatService.probeSession`:
  - Probe `getTargetUrl(session)` rather than `session.rawUrl`.
  - Add `DeviceStatus.authRequired` to the `DeviceStatus` enum.
  - When `res == 'auth_required'`, complete with `DeviceStatus.authRequired`. NEVER mark `session.isDisconnected = true`.
  - Only mark `session.isDisconnected = true` when the DOM explicitly returns `'disconnected'`.
  - When `res == 'online'`, mark `session.isDisconnected = false` and update `lastAccessedAt = DateTime.now()`.
  - Increase `defaultTimeoutMs` to 6500ms and allow up to 10 poll intervals (4s after load stop) for reliable network response.
  - On timeout, do not flip `session.isDisconnected` to true.

### 2.4 UI Updates in SessionCard & StatusDot
- In `StatusDot`: Support custom color parameter (`Color? customColor`).
- In `SessionCard`:
  - Handle `DeviceStatus.authRequired`:
    - Status Label: `Cần xác thực`
    - Subtitle: `Chạm để đăng nhập Google`
    - Color: `AppColors.statusWarning` (Apple Orange `#FF9F0A`)
  - Handle `DeviceStatus.online`:
    - Status Label: `Active`
    - Subtitle: `Sẵn sàng kết nối`
    - Color: `AppColors.statusSuccess` (Apple Green)
  - Handle `DeviceStatus.offline`:
    - Status Label: `Offline`
    - Subtitle: `Chưa mở Antigravity 2.0`
    - Color: `AppColors.statusNeutral`

---

## 3. Verification & Testing
- Unit tests in `test/heartbeat_service_test.dart` and `test/url_parser_test.dart`.
- Verify `flutter analyze` and `flutter test` pass with 0 errors.
- Verify debug APK builds cleanly (`flutter build apk --debug`).
