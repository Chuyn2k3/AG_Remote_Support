import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_support/core/services/storage_service.dart';
import 'package:antigravity_support/models/remote_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  test('Save and retrieve sessions list', () async {
    final session = RemoteSession(
      id: 'session-123',
      rawUrl: 'https://antigravity.google.com/r/session-123',
      title: 'Test Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await storageService.upsertSession(session);
    final sessions = storageService.getSessions();

    expect(sessions.length, 1);
    expect(sessions.first.id, 'session-123');
    expect(sessions.first.title, 'Test Session');
  });

  test('Delete session removes it from list', () async {
    final session = RemoteSession(
      id: 'session-123',
      rawUrl: 'https://antigravity.google.com/r/session-123',
      title: 'Test Session',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await storageService.upsertSession(session);
    await storageService.deleteSession('session-123');

    final sessions = storageService.getSessions();
    expect(sessions.isEmpty, isTrue);
  });
}
