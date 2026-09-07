import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef WidgetActionCallback = void Function(String action);

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('dev.antigravity.remote/home_widget');

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;

  final StreamController<String> _actionStreamController = StreamController<String>.broadcast();
  Stream<String> get actionStream => _actionStreamController.stream;

  WidgetActionCallback? _actionCallback;

  /// Cờ báo cho biết RemoteScreen có đang hiển thị trên foreground hay không.
  bool isRemoteScreenActive = false;

  HomeWidgetService._internal() {
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
    _actionStreamController.add(action);
  }

  void registerActionListener(WidgetActionCallback callback) {
    _actionCallback = callback;
  }

  void unregisterActionListener() {
    _actionCallback = null;
  }

  /// Kiểm tra xem Activity có intent ban đầu kích hoạt hành động từ widget không
  Future<void> checkInitialAction() async {
    try {
      final action = await _channel.invokeMethod<String>('getInitialAction');
      if (action != null && action.isNotEmpty) {
        handleActionFromPlatform(action);
      }
    } catch (e) {
      debugPrint('[HomeWidgetService] checkInitialAction error: $e');
    }
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
