import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';

class SettingsService {
  static const _kKey = 'cf_user_settings_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<UserSettings> getSettings() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return UserSettings.defaults();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return UserSettings.defaults();
      final map = <String, Object?>{};
      for (final e in decoded.entries) {
        map[e.key.toString()] = e.value;
      }
      return UserSettings.fromJson(map);
    } catch (_) {
      return UserSettings.defaults();
    }
  }

  Future<void> saveSettings(UserSettings settings) async {
    final p = await _prefs();
    await p.setString(_kKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final p = await _prefs();
    await p.remove(_kKey);
  }
}
