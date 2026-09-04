import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/native_bubble_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.antigravity.remote/floating_bubble');
  final service = NativeBubbleService();
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'checkPermission':
          return true;
        case 'requestPermission':
          return true;
        case 'showBubble':
          return true;
        case 'updateBubbleStatus':
          return true;
        case 'hideBubble':
          return true;
        case 'isBubbleShowing':
          return true;
        case 'startForegroundWatcher':
          return true;
        case 'stopForegroundWatcher':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('NativeBubbleService checkPermission calls channel', () async {
    final result = await service.checkPermission();
    // On non-Android test runner, isAndroid is false so it returns false directly
    if (service.isAndroid) {
      expect(result, isTrue);
      expect(log.last.method, 'checkPermission');
    } else {
      expect(result, isFalse);
    }
  });

  test('NativeBubbleService service is singleton', () {
    final s1 = NativeBubbleService();
    final s2 = NativeBubbleService();
    expect(identical(s1, s2), isTrue);
  });
}
