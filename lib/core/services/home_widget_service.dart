import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef WidgetActionCallback = void Function(String action);

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('dev.antigravity.remote/home_widget');

  WidgetActionCallback? _actionCallback;

  HomeWidgetService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onWidgetAction') {
      final args = call.arguments;
      final action = args is Map ? args['action']?.toString() : null;
      if (action != null) {
        handleActionFromPlatform(action);
      }
    }
  }

  @visibleForTesting
  void handleActionFromPlatform(String action) {
    _actionCallback?.call(action);
  }

  void registerActionListener(WidgetActionCallback callback) {
    _actionCallback = callback;
  }

  void unregisterActionListener() {
    _actionCallback = null;
  }

  Future<bool> updateWidgetFeed({
    required String sessionTitle,
    required String status,
    required String preview,
    String? updatedAt,
  }) async {
    try {
      String cleanPreview = preview.trim().replaceAll('\n', ' ');
      if (cleanPreview.length > 150) {
        cleanPreview = '${cleanPreview.substring(0, 147)}...';
      }

      final now = DateTime.now();
      final timeStr = updatedAt ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final result = await _channel.invokeMethod<bool>('updateWidgetData', {
        'sessionTitle': sessionTitle,
        'status': status,
        'preview': cleanPreview,
        'updatedAt': timeStr,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[HomeWidgetService] Error updating widget data: $e');
      return false;
    }
  }
}
