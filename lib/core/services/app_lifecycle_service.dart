import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service điều khiển trạng thái ứng dụng Android (đưa app xuống nền an toàn không bị kill,
/// và kéo app lên foreground từ bong bóng nổi / background isolate).
class AppLifecycleService {
  static const MethodChannel _channel = MethodChannel('dev.antigravity.remote/app_lifecycle');
  static const String overlayPortName = 'ag_remote_overlay_port';
  static ReceivePort? _receivePort;

  /// Đăng ký listener nhận tín hiệu từ Bong bóng nổi (Overlay Isolate)
  static void initOverlayCommunication() {
    try {
      _receivePort?.close();
      _receivePort = ReceivePort();
      IsolateNameServer.removePortNameMapping(overlayPortName);
      final registered = IsolateNameServer.registerPortWithName(_receivePort!.sendPort, overlayPortName);
      debugPrint('[AppLifecycleService] Registered overlay port: $registered');

      _receivePort!.listen((message) {
        debugPrint('[AppLifecycleService] Received message from overlay: $message');
        if (message == 'open_app') {
          bringToFront();
        }
      });
    } catch (e) {
      debugPrint('[AppLifecycleService] Error init overlay communication: $e');
    }
  }

  /// Đưa ứng dụng xuống chạy ngầm (tương đương phím Home vật lý trên Android).
  /// Đảm bảo KHÔNG làm chết Activity, giữ nguyên Flutter engine, WebView và WebSocket connection.
  static Future<bool> moveTaskToBack() async {
    try {
      final res = await _channel.invokeMethod<bool>('moveTaskToBack');
      return res ?? false;
    } catch (e) {
      debugPrint('[AppLifecycleService] moveTaskToBack error: $e');
      return false;
    }
  }

  /// Kéo ứng dụng trở lại màn hình chính từ background (khi người dùng chạm vào bubble)
  static Future<bool> bringToFront() async {
    try {
      final res = await _channel.invokeMethod<bool>('bringToFront');
      return res ?? false;
    } catch (e) {
      debugPrint('[AppLifecycleService] bringToFront error: $e');
      return false;
    }
  }

  /// Gửi tín hiệu từ Overlay Isolate về Main Isolate để mở lại ứng dụng
  static void requestOpenAppFromOverlay() {
    try {
      final sendPort = IsolateNameServer.lookupPortByName(overlayPortName);
      if (sendPort != null) {
        sendPort.send('open_app');
        debugPrint('[AppLifecycleService] Sent open_app to main isolate');
      } else {
        debugPrint('[AppLifecycleService] Overlay port not found, fallback to direct channel');
        bringToFront();
      }
    } catch (e) {
      debugPrint('[AppLifecycleService] requestOpenAppFromOverlay error: $e');
    }
  }

  static const MethodChannel _securityChannel = MethodChannel('dev.antigravity.remote/security');

  /// Bật/tắt cờ FLAG_SECURE trên Android (chống chụp màn hình và che Task Switcher snapshot)
  static Future<bool> setSecureFlag(bool enabled) async {
    try {
      final res = await _securityChannel.invokeMethod<bool>('setSecureFlag', {'enabled': enabled});
      return res ?? false;
    } catch (e) {
      debugPrint('[AppLifecycleService] setSecureFlag error: $e');
      return false;
    }
  }
}
