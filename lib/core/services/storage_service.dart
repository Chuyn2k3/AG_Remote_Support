import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/remote_session.dart';

class StorageService {
  static const String _sessionsKey = 'antigravity_remote_sessions';
  static const String _themeModeKey = 'antigravity_theme_mode';
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

  // --- SESSIONS PERSISTENCE ---
  List<RemoteSession> getSessions() {
    final rawList = _prefs.getStringList(_sessionsKey) ?? [];
    return rawList
        .map((item) => RemoteSession.fromJson(jsonDecode(item) as Map<String, dynamic>))
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

  Future<void> _saveList(List<RemoteSession> list) async {
    final rawList = list.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_sessionsKey, rawList);
  }
}
