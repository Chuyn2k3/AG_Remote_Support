import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_support/core/services/storage_service.dart';
import 'package:antigravity_support/models/remote_session.dart';
import 'package:antigravity_support/screens/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.init();
  });

  testWidgets('HomeScreen displays Active status immediately on initial load for active session (>20m old)',
      (WidgetTester tester) async {
    // Session accessed 2 hours ago, but isDisconnected is false
    final session = RemoteSession(
      id: 'active-session-1',
      rawUrl: 'https://antigravity.google.com/r/active-session-1-v2',
      title: 'Active Workstation',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastAccessedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isDisconnected: false,
    );
    await storageService.upsertSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          storageService: storageService,
        ),
      ),
    );

    // Initial render before any manual pull-to-refresh
    await tester.pump();

    // Verify Active text is shown, NOT Offline
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });
}
