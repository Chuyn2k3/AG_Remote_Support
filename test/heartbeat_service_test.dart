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
