import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeWidgetService service;
  final List<MethodCall> log = [];

  setUp(() {
    log.clear();
    service = HomeWidgetService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.antigravity.remote/home_widget'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'updateWidgetData') {
          return true;
        }
        return null;
      },
    );
  });

  test('updateWidgetFeed dispatches updateWidgetData method call with formatted arguments', () async {
    final result = await service.updateWidgetFeed(
      sessionTitle: 'MacBook Pro',
      status: 'generating',
      preview: 'Đang sửa file index.html',
    );

    expect(result, isTrue);
    expect(log.length, 1);
    expect(log.first.method, 'updateWidgetData');
    expect(log.first.arguments['sessionTitle'], 'MacBook Pro');
    expect(log.first.arguments['status'], 'generating');
    expect(log.first.arguments['preview'], 'Đang sửa file index.html');
  });

  test('updateWidgetFeed truncates preview text if longer than 150 characters', () async {
    final longText = 'A' * 200;
    await service.updateWidgetFeed(
      sessionTitle: 'Test Session',
      status: 'idle',
      preview: longText,
    );

    final String sentPreview = log.first.arguments['preview'] as String;
    expect(sentPreview.length, lessThanOrEqualTo(153));
    expect(sentPreview.endsWith('...'), isTrue);
  });

  test('registerActionListener triggers listener callback on onWidgetAction call', () {
    String? capturedAction;
    service.registerActionListener((action) {
      capturedAction = action;
    });

    service.handleActionFromPlatform('approve');
    expect(capturedAction, 'approve');
  });
}
