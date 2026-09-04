import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service quản lý Bong bóng nổi tròn (Chat Head 56x56 dp) và Foreground Watcher chuẩn Native Android.
class NativeBubbleService {
  static final NativeBubbleService _instance = NativeBubbleService._internal();
  factory NativeBubbleService() => _instance;
  NativeBubbleService._internal();

  static const MethodChannel _channel = MethodChannel('dev.antigravity.remote/floating_bubble');

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Kiểm tra xem ứng dụng đã có quyền "Hiển thị trên ứng dụng khác" chưa
  Future<bool> checkPermission() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] checkPermission error: $e');
      return false;
    }
  }

  /// Yêu cầu cấp quyền "Hiển thị trên ứng dụng khác" (mở Settings nếu chưa có)
  Future<bool> requestPermission() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] requestPermission error: $e');
      return false;
    }
  }

  /// Hiển thị bóng tròn Native Chat Head (56x56 dp kéo thả tự do, tự hút mép)
  Future<bool> showBubble({required String sessionTitle, String status = 'online'}) async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('showBubble', {
        'title': sessionTitle,
        'status': status,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] showBubble error: $e');
      return false;
    }
  }

  /// Cập nhật màu chấm trạng thái bóng tròn: 'online' (🟢), 'thinking' (🟡 nhấp nháy), 'offline' (🔴)
  Future<bool> updateBubbleStatus(String status) async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('updateBubbleStatus', {
        'status': status,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] updateBubbleStatus error: $e');
      return false;
    }
  }

  /// Ẩn / đóng bóng tròn
  Future<bool> hideBubble() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hideBubble');
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] hideBubble error: $e');
      return false;
    }
  }

  /// Kiểm tra xem bóng tròn có đang hiển thị hay không
  Future<bool> isBubbleShowing() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isBubbleShowing');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Khởi động Foreground Watcher Service ngăn Android đóng băng WebView khi ấn Home
  Future<bool> startForegroundWatcher({required String title}) async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startForegroundWatcher', {
        'title': title,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] startForegroundWatcher error: $e');
      return false;
    }
  }

  /// Dừng Foreground Watcher Service giải phóng tài nguyên sau khi AI trả lời xong
  Future<bool> stopForegroundWatcher() async {
    if (!isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('stopForegroundWatcher');
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeBubbleService] stopForegroundWatcher error: $e');
      return false;
    }
  }
}
