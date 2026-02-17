import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_entry.dart';

class LocalStorageService {
  static const _kLastCompletedDateKey = 'cf_last_completed_date';
  static const _kStreakKey = 'cf_streak_count';
  static const _kTodayEntryKey = 'cf_today_entry_json';
  static const _kCfHistoryKey = 'cf_history_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<int> getStreakCount() async {
    final p = await _prefs();
    return p.getInt(_kStreakKey) ?? 0;
  }

  Future<void> setStreakCount(int value) async {
    final p = await _prefs();
    await p.setInt(_kStreakKey, value);
  }

  Future<String?> getLastCompletedDateKey() async {
    final p = await _prefs();
    return p.getString(_kLastCompletedDateKey);
  }

  Future<void> setLastCompletedDateKey(String? dateKey) async {
    final p = await _prefs();
    if (dateKey == null) {
      await p.remove(_kLastCompletedDateKey);
      return;
    }
    await p.setString(_kLastCompletedDateKey, dateKey);
  }

  Future<DailyEntry?> getTodayEntry() async {
    final p = await _prefs();
    final raw = p.getString(_kTodayEntryKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final map = <String, Object?>{};
    for (final e in decoded.entries) {
      if (e.key is String) {
        map[e.key as String] = e.value;
      }
    }

    return DailyEntry.fromJson(map);
  }

  Future<void> setTodayEntry(DailyEntry? entry) async {
    final p = await _prefs();
    if (entry == null) {
      await p.remove(_kTodayEntryKey);
      return;
    }

    final raw = jsonEncode(entry.toJson());
    await p.setString(_kTodayEntryKey, raw);
  }

  Future<Map<String, int>> getCfHistory() async {
    final p = await _prefs();
    final raw = p.getString(_kCfHistoryKey);
    if (raw == null || raw.trim().isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final out = <String, int>{};
    for (final e in decoded.entries) {
      if (e.key is! String) continue;
      final v = e.value;
      if (v is int) {
        out[e.key as String] = v.clamp(0, 100);
      } else if (v is num) {
        out[e.key as String] = v.round().clamp(0, 100);
      }
    }
    return out;
  }

  Future<void> upsertCfForDate({required String dateKey, required int cf}) async {
    final history = await getCfHistory();
    history[dateKey] = cf.clamp(0, 100);
    final p = await _prefs();
    await p.setString(_kCfHistoryKey, jsonEncode(history));
  }

  Future<void> clearAll() async {
    final p = await _prefs();
    await p.remove(_kLastCompletedDateKey);
    await p.remove(_kStreakKey);
    await p.remove(_kTodayEntryKey);
    await p.remove(_kCfHistoryKey);
  }
}
