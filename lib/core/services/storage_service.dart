import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/remote_session.dart';

class StorageService {
  static const String _sessionsKey = 'antigravity_remote_sessions';
  static const String _themeModeKey = 'antigravity_theme_mode';
  static const String _biometricEnabledKey = 'antigravity_biometric_enabled';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- THEME PERSISTENCE ---
  ThemeMode getThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    if (raw == 'light') return ThemeMode.light;
    if (raw == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) {
      await _prefs.remove(_themeModeKey);
    } else {
      await _prefs.setString(_themeModeKey, mode == ThemeMode.light ? 'light' : 'dark');
    }
  }

  // --- BIOMETRIC SECURITY ---
  bool isBiometricEnabled() {
    return _prefs.getBool(_biometricEnabledKey) ?? true;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  static const String _encPrefix = 'enc:v1:';
  static const List<int> _cipherKey = [
    0x56, 0x48, 0x54, 0x5F, 0x41, 0x47, 0x59, 0x32, 0x30, 0x32, 0x36, 0x5F, 0x53, 0x45, 0x43
  ];

  static String _obfuscate(String plaintext) {
    final bytes = utf8.encode(plaintext);
    final xorBytes = List<int>.generate(bytes.length, (i) => bytes[i] ^ _cipherKey[i % _cipherKey.length]);
    return '$_encPrefix${base64.encode(xorBytes)}';
  }

  static String _deobfuscate(String raw) {
    if (raw.startsWith(_encPrefix)) {
      try {
        final b64 = raw.substring(_encPrefix.length);
        final xorBytes = base64.decode(b64);
        final bytes = List<int>.generate(xorBytes.length, (i) => xorBytes[i] ^ _cipherKey[i % _cipherKey.length]);
        return utf8.decode(bytes);
      } catch (_) {
        return raw;
      }
    }
    // Backward compatibility: If plain legacy JSON, return as-is
    return raw;
  }

  // --- SESSIONS PERSISTENCE ---
  List<RemoteSession> getSessions() {
    final rawList = _prefs.getStringList(_sessionsKey) ?? [];
    return rawList
        .map((item) {
          try {
            final jsonStr = _deobfuscate(item);
            return RemoteSession.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RemoteSession>()
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastAccessedAt.compareTo(a.lastAccessedAt);
      });
  }

  Future<void> upsertSession(RemoteSession session) async {
    final list = getSessions();
    final index = list.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.insert(0, session);
    }
    await _saveList(list);
  }

  Future<void> deleteSession(String id) async {
    final list = getSessions();
    list.removeWhere((s) => s.id == id);
    await _saveList(list);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_sessionsKey);
  }

  /// Xóa sạch khẩn cấp toàn bộ dữ liệu phiên, theme, và cài đặt
  Future<void> emergencyWipe() async {
    await _prefs.remove(_sessionsKey);
    await _prefs.remove(_themeModeKey);
    await _prefs.remove(_biometricEnabledKey);
  }

  Future<void> _saveList(List<RemoteSession> list) async {
    final rawList = list.map((s) => _obfuscate(jsonEncode(s.toJson()))).toList();
    await _prefs.setStringList(_sessionsKey, rawList);
  }
}
