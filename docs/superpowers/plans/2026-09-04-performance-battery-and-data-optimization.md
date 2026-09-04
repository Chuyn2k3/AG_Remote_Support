# Performance, Battery & Data Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate battery drain, CPU wakeups, and UI stutter by removing polling timers, isolating render layers with `RepaintBoundary`, scoping progress updates with `ValueNotifier`, and enabling Chromium disk caching.

**Architecture:**
- Battery & Thermals: 100% Event-Driven architecture (Console `[TTFT]` + UserScript callbacks); delete 1.5s and 2.5s DOM polling timers.
- Rendering & Rebuilds: `ValueNotifier` for webview load progress (0 rebuilds on `RemoteScreen`); `RepaintBoundary` on `InAppWebView`, `FloatingCapsule`, and `SessionTabBar` to prevent expensive platform-view raster invalidation during drag.
- Data & Memory: Enable Chromium HTTP disk cache (`CacheMode.LOAD_DEFAULT`); replace mass Headless WebView probing on startup with smart zero-network cache-first status.

**Tech Stack:** Flutter, Dart, InAppWebView, ValueNotifier, RepaintBoundary.

---

### Task 1: Event-Driven Battery & Thermal Optimization (Kill Polling Timers)

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Locate and remove periodic polling timers**

In `lib/screens/remote/remote_screen.dart`:
- Remove `Timer? _aiResponsePollingTimer;`
- Remove `Timer? _disconnectCheckTimer;`
- Remove `_pollAIResponseStatus()` and its invocation from `initState()`.
- Remove `_startPolling()` and `_disconnectCheckTimer = Timer.periodic(...)`.

- [ ] **Step 2: Connect disconnection check to concrete events**

Keep `_checkInstanceDisconnection()` but call it only on:
1. `onLoadStop`
2. `onReceivedError`
3. `onReload`

- [ ] **Step 3: Verify clean timer cancellation in `dispose()`**

Ensure `dispose()` cancels only remaining active timers (debounce timer) without dangling references.

- [ ] **Step 4: Run flutter analyze & test**

Run: `flutter analyze && flutter test`
Expected: 0 issues, 31/31 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "perf(remote): eliminate DOM polling timers and switch to 100% event-driven architecture"
```

---

### Task 2: Rebuild Scope Minimization with `ValueNotifier` (`RemoteScreen`)

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`

- [ ] **Step 1: Upgrade `RemoteTabItem` with `ValueNotifier`**

In `lib/screens/remote/remote_screen.dart`:
```dart
class RemoteTabItem {
  final RemoteSession session;
  InAppWebViewController? controller;
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  String? errorMessage;
  bool isStreaming = false;

  RemoteTabItem({required this.session});

  void dispose() {
    progressNotifier.dispose();
    loadingNotifier.dispose();
  }
}
```

- [ ] **Step 2: Update `onProgressChanged` and `onLoadStop` without calling `setState`**

In `InAppWebView`:
```dart
      onProgressChanged: (controller, progress) {
        final double val = progress / 100.0;
        tab.progressNotifier.value = val;
        if (progress >= 95) {
          tab.loadingNotifier.value = false;
        }
      },
      onLoadStop: (controller, url) {
        tab.progressNotifier.value = 1.0;
        tab.loadingNotifier.value = false;
        ...
      },
```

- [ ] **Step 3: Wrap Progress Bar in `ValueListenableBuilder`**

In `_buildWebViewArea()`:
```dart
            ValueListenableBuilder<bool>(
              valueListenable: _activeTab.loadingNotifier,
              builder: (context, isLoading, _) {
                if (!isLoading) return const SizedBox.shrink();
                return ValueListenableBuilder<double>(
                  valueListenable: _activeTab.progressNotifier,
                  builder: (context, progress, _) {
                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                    );
                  },
                );
              },
            ),
```

- [ ] **Step 4: Dispose tab notifiers in `dispose()` and `_closeTab()`**

In `_closeTab(int index)` and `_RemoteScreenState.dispose()`:
Call `tab.dispose()`.

- [ ] **Step 5: Run flutter analyze & test**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/remote/remote_screen.dart
git commit -m "perf(ui): scope webview progress bar rebuilds with ValueNotifier"
```

---

### Task 3: Render Tree Layer Isolation (`RepaintBoundary`)

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`
- Modify: `lib/screens/remote/widgets/floating_capsule.dart`

- [ ] **Step 1: Wrap `InAppWebView` in `RepaintBoundary`**

In `_buildTabWebView(...)` in `remote_screen.dart`:
```dart
RepaintBoundary(
  child: InAppWebView(
    ...
  ),
)
```

- [ ] **Step 2: Wrap `FloatingCapsule` in `RepaintBoundary`**

In `remote_screen.dart`:
```dart
RepaintBoundary(
  child: FloatingCapsule(
    ...
  ),
)
```

- [ ] **Step 3: Wrap `SessionTabBar` in `RepaintBoundary`**

In `remote_screen.dart`:
```dart
RepaintBoundary(
  child: SessionTabBar(
    ...
  ),
)
```

- [ ] **Step 4: Run flutter analyze & test**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/remote/remote_screen.dart lib/screens/remote/widgets/floating_capsule.dart
git commit -m "perf(render): add RepaintBoundary isolation around WebView, Capsule, and TabBar"
```

---

### Task 4: Data & RAM Optimization (Chromium Disk Cache & Lightweight Heartbeat)

**Files:**
- Modify: `lib/screens/remote/remote_screen.dart`
- Modify: `lib/core/services/heartbeat_service.dart`
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Configure Chromium Disk Cache in `InAppWebViewSettings`**

In `lib/screens/remote/remote_screen.dart`:
- Set `cacheMode: CacheMode.LOAD_DEFAULT`
- Set `clearCache: false`
- Set `domStorageEnabled: true`
- Set `databaseEnabled: true`

- [ ] **Step 2: Optimize `HomeScreen` startup heartbeat to Cache-First**

In `lib/screens/home/home_screen.dart`:
In `_refreshDeviceStatuses()`:
First populate `_deviceStatuses[s.id] = HeartbeatService.evaluateSessionStatus(s)` immediately.
Only probe with network if user triggers pull-to-refresh or taps status.

- [ ] **Step 3: Optimize `HeartbeatService.probeSession` for minimal network & RAM**

In `lib/core/services/heartbeat_service.dart`:
- Add `loadsImagesAutomatically: false` to headless settings.
- Lower timeout to 3500ms.
- Ensure `headless?.dispose()` in `finally`.

- [ ] **Step 4: Run full verification suite**

Run: `flutter analyze`
Run: `flutter test`
Run: `flutter build apk --debug`
Expected: 0 issues, 100% tests pass, APK builds cleanly.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/remote/remote_screen.dart lib/core/services/heartbeat_service.dart lib/screens/home/home_screen.dart
git commit -m "perf(cache): enable Chromium disk cache and implement lightweight zero-startup-data heartbeat"
```
