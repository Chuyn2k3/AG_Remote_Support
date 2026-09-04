# Kế Hoạch Triển Khai Tính Năng Live Desktop Heartbeat Monitor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bổ sung tính năng kiểm tra trực tiếp trạng thái sống của máy tính (Live Desktop Heartbeat Monitor) vào màn hình chính thông qua thao tác vuốt kéo xuống (Pull-to-refresh) và tự động kiểm tra khi mở app, hiển thị trực quan máy tính nào đang Online (🟢) và máy tính nào đang Offline (⚪).

**Architecture:** Xây dựng `HeartbeatService` sử dụng `HttpClient` hệ thống (`dart:io`) gửi HTTP HEAD request với timeout 3.5 giây tới tunnel Google `/r/<sessionId>-v2`; tích hợp `RefreshIndicator` trên `HomeScreen`; nâng cấp `SessionCard` để hiển thị huy hiệu và chấm trạng thái tương ứng.

**Tech Stack:** Flutter 3.24.4, Dart 3.5.4, `dart:io` HttpClient, SharedPreferences.

---

## Danh Sách Tệp (File Structure Map)

| Tệp | Trách nhiệm | Loại thay đổi |
|---|---|---|
| `lib/core/services/heartbeat_service.dart` | Định nghĩa enum `DeviceStatus` và logic ping máy tính (`pingSession`, `pingAll`) | Mới |
| `test/heartbeat_service_test.dart` | Unit test cho `HeartbeatService` và xử lý timeout | Mới |
| `lib/screens/home/widgets/session_card.dart` | Hiển thị badge trạng thái Online / Offline / Checking và thông tin hướng dẫn | Sửa |
| `lib/screens/home/home_screen.dart` | Tích hợp `RefreshIndicator` (Pull-to-refresh) và quản lý `_deviceStatuses` | Sửa |

---

### Task 1: Xây Dựng HeartbeatService & Bộ Unit Test

**Files:**
- Create: `test/heartbeat_service_test.dart`
- Create: `lib/core/services/heartbeat_service.dart`

- [ ] **Step 1: Viết failing unit test cho HeartbeatService**

Tạo tệp `test/heartbeat_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/heartbeat_service.dart';
import 'package:antigravity_support/models/remote_session.dart';

void main() {
  test('HeartbeatService extracts valid target URL and handles pingSession', () async {
    final session = RemoteSession(
      id: 'mock-session-id',
      rawUrl: 'https://antigravity.google.com/r/mock-session-id-v2',
      title: 'Mock Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    expect(HeartbeatService.getTargetUrl(session), 'https://antigravity.google.com/r/mock-session-id-v2');

    // Test pingSession returns a valid DeviceStatus (online or offline) without throwing exception
    final status = await HeartbeatService.pingSession(session, timeoutMs: 800);
    expect(status, isA<DeviceStatus>());
  });

  test('DeviceStatus enum has all 3 required states', () {
    expect(DeviceStatus.values, contains(DeviceStatus.online));
    expect(DeviceStatus.values, contains(DeviceStatus.offline));
    expect(DeviceStatus.values, contains(DeviceStatus.checking));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/heartbeat_service_test.dart`  
Expected: FAIL do chưa có tệp `heartbeat_service.dart`.

- [ ] **Step 3: Triển khai HeartbeatService**

Tạo tệp `lib/core/services/heartbeat_service.dart`:
```dart
import 'dart:async';
import 'dart:io';
import '../../models/remote_session.dart';
import '../utils/url_parser.dart';

enum DeviceStatus {
  online,
  offline,
  checking,
}

class HeartbeatService {
  static const int defaultTimeoutMs = 3500;

  static String getTargetUrl(RemoteSession session) {
    final sessionId = UrlParser.extractSessionId(session.rawUrl) ?? session.id;
    return 'https://antigravity.google.com/r/$sessionId-v2';
  }

  static Future<DeviceStatus> pingSession(
    RemoteSession session, {
    int timeoutMs = defaultTimeoutMs,
  }) async {
    final urlStr = getTargetUrl(session);
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return DeviceStatus.offline;

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = Duration(milliseconds: timeoutMs);

      final request = await client.headUrl(uri).timeout(Duration(milliseconds: timeoutMs));
      // Tắt tự động redirect để nhận diện ngay cả khi máy chủ trả về 302
      request.followRedirects = false;

      final response = await request.close().timeout(Duration(milliseconds: timeoutMs));

      // 200, 302, 401, 403 chứng tỏ Google tunnel endpoint đang hoạt động
      if (response.statusCode >= 200 && response.statusCode < 404) {
        return DeviceStatus.online;
      }
      return DeviceStatus.offline;
    } catch (_) {
      return DeviceStatus.offline;
    } finally {
      client?.close(force: true);
    }
  }

  static Future<Map<String, DeviceStatus>> pingAll(
    List<RemoteSession> sessions, {
    int timeoutMs = defaultTimeoutMs,
  }) async {
    final results = <String, DeviceStatus>{};
    if (sessions.isEmpty) return results;

    final futures = sessions.map((session) async {
      final status = await pingSession(session, timeoutMs: timeoutMs);
      return MapEntry(session.id, status);
    });

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }
    return results;
  }
}
```

- [ ] **Step 4: Chạy lại test để xác nhận test vượt qua**

Run: `flutter test test/heartbeat_service_test.dart`  
Expected: PASS 100%.

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/core/services/heartbeat_service.dart test/heartbeat_service_test.dart
git commit -m "feat(heartbeat): implement HeartbeatService with HTTP HEAD ping and unit tests"
```

---

### Task 2: Nâng Cấp SessionCard Hiển Thị Trực Quan Trạng Thái Máy Tính

**Files:**
- Modify: `lib/screens/home/widgets/session_card.dart`

- [ ] **Step 1: Bổ sung tham số `status` và giao diện trạng thái vào SessionCard**

Cập nhật `lib/screens/home/widgets/session_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../core/services/heartbeat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/widgets/apple_card.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../models/remote_session.dart';

class SessionCard extends StatelessWidget {
  final RemoteSession session;
  final DeviceStatus status;
  final VoidCallback onConnect;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const SessionCard({
    super.key,
    required this.session,
    this.status = DeviceStatus.checking,
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

    // Status styling
    Color statusColor;
    String statusLabel;
    String statusSubtitle;
    if (status == DeviceStatus.online) {
      statusColor = isDark ? AppColors.statusSuccessDark : AppColors.statusSuccess;
      statusLabel = 'Active';
      statusSubtitle = 'Sẵn sàng kết nối';
    } else if (status == DeviceStatus.offline) {
      statusColor = textSecondary;
      statusLabel = 'Offline';
      statusSubtitle = 'Chưa mở Antigravity 2.0';
    } else {
      statusColor = primaryColor;
      statusLabel = 'Kiểm tra';
      statusSubtitle = 'Đang kiểm tra kết nối...';
    }

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onConnect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(
                isOnline: status == DeviceStatus.online,
                size: 8,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
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

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$statusSubtitle • ${_formatTime(session.lastAccessedAt)}',
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

- [ ] **Step 2: Phân tích cú pháp**

Run: `flutter analyze`  
Expected: No issues found.

- [ ] **Step 3: Commit Task 2**

```bash
git add lib/screens/home/widgets/session_card.dart
git commit -m "feat(ui): update SessionCard to display dynamic DeviceStatus and status badges"
```

---

### Task 3: Tích Hợp RefreshIndicator & Quản Lý Trạng Thái Ping Tại HomeScreen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Tích hợp `RefreshIndicator` và `_refreshDeviceStatuses`**

Cập nhật `lib/screens/home/home_screen.dart`:
- Khởi tạo `Map<String, DeviceStatus> _deviceStatuses = {}`.
- Hàm `_refreshDeviceStatuses()`:
  ```dart
  Future<void> _refreshDeviceStatuses() async {
    if (_sessions.isEmpty) return;
    setState(() {
      for (final s in _sessions) {
        _deviceStatuses[s.id] = DeviceStatus.checking;
      }
    });
    final statuses = await HeartbeatService.pingAll(_sessions);
    if (mounted) {
      setState(() {
        _deviceStatuses = statuses;
      });
    }
  }
  ```
- Gọi `_refreshDeviceStatuses()` trong `initState()`, sau khi thêm phiên mới hoặc xóa phiên.
- Bọc `ListView` trong `RefreshIndicator`:
  ```dart
  RefreshIndicator(
    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    onRefresh: _refreshDeviceStatuses,
    child: ListView(...),
  )
  ```
- Truyền `status: _deviceStatuses[s.id] ?? DeviceStatus.checking` vào `SessionCard`.

- [ ] **Step 2: Kiểm tra cú pháp và chạy test**

Run: `flutter analyze && flutter test`  
Expected: 0 errors, all tests pass.

- [ ] **Step 3: Commit Task 3**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): integrate pull-to-refresh and automatic desktop heartbeat monitoring"
```

---

### Task 4: Kiểm Thử Toàn Diện & Xác Thực Biên Dịch APK

- [ ] **Step 1: Chạy toàn bộ test suites**

Run: `flutter test`  
Expected: 100% tests pass.

- [ ] **Step 2: Phân tích cú pháp toàn dự án**

Run: `flutter analyze`  
Expected: No issues found!

- [ ] **Step 3: Biên dịch kiểm tra APK Debug**

Run: `flutter build apk --debug`  
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Commit hoàn tất**

```bash
git commit --allow-empty -m "chore: complete live desktop heartbeat monitor integration and verification"
```
