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
    if (sessionId.endsWith('-v2')) {
      return 'https://antigravity.google.com/r/$sessionId';
    }
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
      // Không tự động redirect để bắt phản hồi nhanh 302/200 của tunnel Google
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
