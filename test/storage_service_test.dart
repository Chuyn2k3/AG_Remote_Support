import 'package:flutter/material.dart';
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
}
