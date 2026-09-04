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
  authRequired,
}

class HeartbeatService {
  static const int defaultTimeoutMs = 3500;
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  static String getTargetUrl(RemoteSession session) {
    final sessionId = UrlParser.extractSessionId(session.rawUrl) ?? session.id;
    final cleanId = sessionId.endsWith('-v2') ? sessionId : '$sessionId-v2';
    final email = session.email ?? UrlParser.extractEmail(session.rawUrl);
    if (email != null && email.trim().isNotEmpty) {
      return 'https://antigravity.google.com/r/$cleanId?authuser=${Uri.encodeComponent(email.trim())}';
    }
    return 'https://antigravity.google.com/r/$cleanId';
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
    bool? confirmedDisconnected;

    try {
      final completer = Completer<DeviceStatus>();
      final targetUrl = getTargetUrl(session);

      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent: customUserAgent,
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          cacheEnabled: true,
          cacheMode: CacheMode.LOAD_DEFAULT,
          loadsImagesAutomatically: false,
          blockNetworkImage: true,
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
                    if (location.host.includes('accounts.google.com') ||
                        text.includes('sign in') ||
                        text.includes('đăng nhập') ||
                        text.includes('switch account') ||
                        text.includes('chuyển tài khoản') ||
                        text.includes('you need permission') ||
                        text.includes('không có quyền truy cập')) {
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

              if (res == 'disconnected') {
                confirmedDisconnected = true;
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.offline);
              } else if (res == 'auth_required') {
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.authRequired);
              } else if (res == 'online') {
                confirmedDisconnected = false;
                t.cancel();
                if (!completer.isCompleted) completer.complete(DeviceStatus.online);
              } else if (checks >= 6) {
                t.cancel();
                if (!completer.isCompleted) {
                  completer.complete(DeviceStatus.online);
                }
              }
            } catch (_) {
              if (checks >= 6) {
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
        onTimeout: () => evaluateSessionStatus(session),
      );

      // Cập nhật cờ dữ liệu thực tế và lưu vào storage:
      // CHỈ đánh dấu ngắt kết nối khi nhận diện rõ ràng tín hiệu 'disconnected' từ DOM!
      if (confirmedDisconnected == true) {
        session.isDisconnected = true;
      } else if (status == DeviceStatus.online) {
        session.isDisconnected = false;
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

    // Tuần tự probe từng session để tránh RAM spike và throttling
    for (final session in sessions) {
      final status = await probeSession(
        session,
        timeoutMs: timeoutMs,
        storageService: storageService,
      );
      results[session.id] = status;
    }
    return results;
  }
}
