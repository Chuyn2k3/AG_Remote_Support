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

  test('HeartbeatService evaluateSessionStatus returns offline if isDisconnected is true', () {
    final session = RemoteSession(
      id: 'disconnected-session',
      rawUrl: 'https://antigravity.google.com/r/disconnected-session-v2',
      title: 'Disconnected Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(), // accessed right now
      isDisconnected: true,
    );

    final status = HeartbeatService.evaluateSessionStatus(session);
    expect(status, DeviceStatus.offline);
  });

  test('HeartbeatService evaluateSessionStatus returns online if recent and not disconnected', () {
    final session = RemoteSession(
      id: 'online-session',
      rawUrl: 'https://antigravity.google.com/r/online-session-v2',
      title: 'Online Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isDisconnected: false,
    );

    final status = HeartbeatService.evaluateSessionStatus(session);
    expect(status, DeviceStatus.online);
  });

  test('HeartbeatService evaluateSessionStatus returns online if isDisconnected is false even if accessed long ago', () {
    final session = RemoteSession(
      id: 'active-session',
      rawUrl: 'https://antigravity.google.com/r/active-session-v2',
      title: 'Active Session',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      lastAccessedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      isDisconnected: false,
    );

    final status = HeartbeatService.evaluateSessionStatus(session);
    expect(status, DeviceStatus.online);
  });

  test('DeviceStatus enum has all required states', () {
    expect(DeviceStatus.values, contains(DeviceStatus.online));
    expect(DeviceStatus.values, contains(DeviceStatus.offline));
    expect(DeviceStatus.values, contains(DeviceStatus.checking));
    expect(DeviceStatus.values, contains(DeviceStatus.authRequired));
  });

  test('HeartbeatService getTargetUrl converts AccountChooser URL to direct Antigravity URL with authuser', () {
    final session = RemoteSession(
      id: 'mock-account-chooser',
      rawUrl:
          'https://accounts.google.com/AccountChooser?Email=test%40gmail.com&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2Fmy-session-uuid-v2',
      title: 'Chooser Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    expect(
      HeartbeatService.getTargetUrl(session),
      'https://antigravity.google.com/r/my-session-uuid-v2?authuser=test%40gmail.com',
    );
  });

  test('HeartbeatService getTargetUrl handles session without email', () {
    final session = RemoteSession(
      id: 'mock-no-email',
      rawUrl: 'https://antigravity.google.com/r/my-session-uuid-v2',
      title: 'Direct Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    expect(
      HeartbeatService.getTargetUrl(session),
      'https://antigravity.google.com/r/my-session-uuid-v2',
    );
  });
}

