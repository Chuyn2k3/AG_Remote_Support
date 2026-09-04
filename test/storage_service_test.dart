import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:antigravity_support/core/services/storage_service.dart';
import 'package:antigravity_support/models/remote_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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

  test('Save and retrieve ThemeMode', () async {
    expect(storageService.getThemeMode(), ThemeMode.system);

    await storageService.saveThemeMode(ThemeMode.light);
    expect(storageService.getThemeMode(), ThemeMode.light);

    await storageService.saveThemeMode(ThemeMode.dark);
    expect(storageService.getThemeMode(), ThemeMode.dark);

    await storageService.saveThemeMode(ThemeMode.system);
    expect(storageService.getThemeMode(), ThemeMode.system);
  });

  test('Save and retrieve Biometric security setting', () async {
    // Defaults to true so protection is enabled out of the box
    expect(storageService.isBiometricEnabled(), isTrue);

    await storageService.setBiometricEnabled(false);
    expect(storageService.isBiometricEnabled(), isFalse);

    await storageService.setBiometricEnabled(true);
    expect(storageService.isBiometricEnabled(), isTrue);
  });

  // --- SECURITY TESTS ---
  test('StorageService saves sessions in obfuscated format instead of plaintext', () async {
    final session = RemoteSession(
      id: 'sec-123',
      rawUrl: 'https://antigravity.google.com/r/sec-123',
      title: 'Secret Project',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await storageService.upsertSession(session);
    final rawList = prefs.getStringList('antigravity_remote_sessions')!;
    expect(rawList.first.startsWith('enc:v1:'), isTrue);
    expect(rawList.first.contains('https://antigravity.google.com'), isFalse);

    final retrieved = storageService.getSessions();
    expect(retrieved.first.rawUrl, equals('https://antigravity.google.com/r/sec-123'));
    expect(retrieved.first.title, equals('Secret Project'));
  });

  test('StorageService backward compatibility with legacy plaintext sessions', () async {
    // Giả lập dữ liệu cũ lưu dạng JSON trần chưa mã hóa
    const legacyJson = '''{"id":"legacy-1","rawUrl":"https://antigravity.google.com/r/legacy-1","title":"Legacy Session","createdAt":"2026-09-01T10:00:00.000Z","lastAccessedAt":"2026-09-01T10:00:00.000Z"}''';
    await prefs.setStringList('antigravity_remote_sessions', [legacyJson]);

    final sessions = storageService.getSessions();
    expect(sessions.length, 1);
    expect(sessions.first.id, 'legacy-1');
    expect(sessions.first.rawUrl, 'https://antigravity.google.com/r/legacy-1');
  });

  test('StorageService emergencyWipe clears all sessions and configs', () async {
    final session = RemoteSession(
      id: 'wipe-1',
      rawUrl: 'https://antigravity.google.com/r/wipe-1',
      title: 'To Be Wiped',
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );
    await storageService.upsertSession(session);
    await storageService.saveThemeMode(ThemeMode.dark);

    await storageService.emergencyWipe();
    expect(storageService.getSessions(), isEmpty);
    expect(storageService.getThemeMode(), ThemeMode.system);
  });
}
