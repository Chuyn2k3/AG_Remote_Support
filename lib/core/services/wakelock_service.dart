import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      _isEnabled = true;
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      _isEnabled = false;
    } catch (_) {}
  }

  static Future<bool> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
    return _isEnabled;
  }
}
