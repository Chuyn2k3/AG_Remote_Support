import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/remote_session.dart';
import '../utils/url_parser.dart';
import 'storage_service.dart';

enum DeviceStatus {
  online,
  offline,
  checking,
}

class HeartbeatService {
  static const int defaultTimeoutMs = 4500;
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  static String getTargetUrl(RemoteSession session) {
    final sessionId = UrlParser.extractSessionId(session.rawUrl) ?? session.id;
    if (sessionId.endsWith('-v2')) {
      return 'https://antigravity.google.com/r/$sessionId';
    }
    return 'https://antigravity.google.com/r/$sessionId-v2';
  }

  /// Đánh giá trạng thái nhanh (fallback) dựa trên cờ ngắt kết nối và thời gian truy cập gần nhất.
  static DeviceStatus evaluateSessionStatus(RemoteSession session) {
    if (session.isDisconnected) {
      return DeviceStatus.offline;
    }
    final diff = DateTime.now().difference(session.lastAccessedAt);
    if (diff.inMinutes < 20) {
      return DeviceStatus.online;
    }
    return DeviceStatus.offline;
  }

  /// Thực hiện probe thực tế tới máy chủ Google và phiên WebSocket thông qua HeadlessInAppWebView
  static Future<DeviceStatus> probeSession(
    RemoteSession session, {
    int timeoutMs = defaultTimeoutMs,
    StorageService? storageService,
  }) async {
    HeadlessInAppWebView? headless;
    Timer? pollTimer;

    try {
      final completer = Completer<DeviceStatus>();

      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(session.rawUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent: customUserAgent,
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          cacheEnabled: true,
          supportMultipleWindows: false,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          requestedWithHeaderOriginAllowList: <String>{},
        ),
        onLoadStop: (controller, url) async {
          int checks = 0;
          pollTimer = Timer.periodic(const Duration(milliseconds: 400), (t) async {
            checks++;
            if (completer.isCompleted) {
              t.cancel();
              return;
            }

            try {
              final dynamic res = await controller.evaluateJavascript(source: '''
                (function() {
                  try {
                    const body = document.body;
                    if (!body) return 'loading';
                    const text = (body.innerText || '').toLowerCase();
                    if (text.includes('instance disconnected') ||
                        text.includes('disconnected from instance') ||
                        text.includes('no instance') ||
                        text.includes('instance offline') ||
                        text.includes('session ended') ||
                        text.includes('connection lost') ||
                        document.querySelector('.disconnect-card, .no-instance-card, [data-status="disconnected"]') !== null) {
                      return 'disconnected';
                    }
                    if (location.host.includes('accounts.google.com') || text.includes('sign in')) {
                      return 'auth_required';
                    }
                    if (text.length > 30 && document.querySelector('button, mwc-button, textarea, input, [role="main"]') !== null) {
                      return 'online';
                    }
                    return 'loading';
                  } catch(e) {
                    return 'error';
                  }
                })()
              ''');

              if (res == 'disconnected' || res == 'auth_required') {
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.offline);
              } else if (res == 'online') {
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.online);
              } else if (checks >= 7) {
                t.cancel();
                if (!completer.isCompleted) {
                  completer.complete(DeviceStatus.online);
                }
              }
            } catch (_) {
              if (checks >= 7) {
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.offline);
              }
            }
          });
        },
        onReceivedError: (controller, request, error) {
          if (!error.description.contains('net::ERR_ABORTED') && !completer.isCompleted) {
            completer.complete(DeviceStatus.offline);
          }
        },
      );

      await headless.run();

      final status = await completer.future.timeout(
        Duration(milliseconds: timeoutMs),
        onTimeout: () => session.isDisconnected ? DeviceStatus.offline : evaluateSessionStatus(session),
      );

      // Cập nhật cờ dữ liệu thực tế và lưu vào storage
      final bool isDisconn = (status == DeviceStatus.offline);
      session.isDisconnected = isDisconn;
      if (!isDisconn) {
        session.lastAccessedAt = DateTime.now();
      }
      if (storageService != null) {
        await storageService.upsertSession(session);
      }

      return status;
    } catch (e) {
      debugPrint('Headless probe fallback: $e');
      return evaluateSessionStatus(session);
    } finally {
      pollTimer?.cancel();
      try {
        await headless?.dispose();
      } catch (_) {}
    }
  }

  static Future<DeviceStatus> pingSession(
    RemoteSession session, {
    int timeoutMs = defaultTimeoutMs,
    StorageService? storageService,
  }) async {
    return probeSession(session, timeoutMs: timeoutMs, storageService: storageService);
  }

  static Future<Map<String, DeviceStatus>> pingAll(
    List<RemoteSession> sessions, {
    int timeoutMs = defaultTimeoutMs,
    StorageService? storageService,
  }) async {
    final results = <String, DeviceStatus>{};
    if (sessions.isEmpty) return results;

    final futures = sessions.map((session) async {
      final status = await probeSession(
        session,
        timeoutMs: timeoutMs,
        storageService: storageService,
      );
      return MapEntry(session.id, status);
    });

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }
    return results;
  }
}
