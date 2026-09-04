import 'dart:async';
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

  /// Xác định trạng thái kết nối thực tế dựa trên cờ ngắt kết nối và thời gian truy cập gần nhất.
  /// Tuyệt đối không dùng HTTP HEAD 200 ảo vì máy chủ Google luôn trả về 200 cho bất kỳ link nào.
  static DeviceStatus evaluateSessionStatus(RemoteSession session) {
    // Nếu phiên đã được xác nhận là 'instance disconnected' từ WebView
    if (session.isDisconnected) {
      return DeviceStatus.offline;
    }

    // Nếu vừa được mở kết nối thành công trong vòng 20 phút trước
    final diff = DateTime.now().difference(session.lastAccessedAt);
    if (diff.inMinutes < 20) {
      return DeviceStatus.online;
    }

    return DeviceStatus.offline;
  }

  static Future<DeviceStatus> pingSession(
    RemoteSession session, {
    int timeoutMs = defaultTimeoutMs,
  }) async {
    return evaluateSessionStatus(session);
  }

  static Future<Map<String, DeviceStatus>> pingAll(
    List<RemoteSession> sessions, {
    int timeoutMs = defaultTimeoutMs,
  }) async {
    final results = <String, DeviceStatus>{};
    for (final session in sessions) {
      results[session.id] = evaluateSessionStatus(session);
    }
    return results;
  }
}
