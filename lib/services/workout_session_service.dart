import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';

class WorkoutSessionService {
  static const _kCompletedWorkoutsByDateKey = 'cf_completed_workouts_by_date_json';
  static const int cfBonus = 20;

  WorkoutSessionService({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<bool> isWorkoutCompletedForDate(String dateKey) async {
    final map = await _getCompletedMap();
    return map.containsKey(dateKey);
  }

  Future<void> markWorkoutCompleted({required String dateKey, required String workoutName}) async {
    final map = await _getCompletedMap();
    map[dateKey] = workoutName;
    final p = await _prefs();
    await p.setString(_kCompletedWorkoutsByDateKey, jsonEncode(map));
  }

  Future<String?> getCompletedWorkoutName(String dateKey) async {
    final map = await _getCompletedMap();
    return map[dateKey];
  }

  Future<void> completeWorkoutAndApplyBonus({required Workout workout}) async {
    final now = DateTime.now();
    final dateKey = DateUtilsCF.toKey(now);

    // Mark completion.
    await markWorkoutCompleted(dateKey: dateKey, workoutName: workout.name);

    // Compute today's base CF.
    final entry = await _storage.getTodayEntry();
    final baseCf = (entry != null && entry.dateKey == dateKey) ? entry.cfIndex : 0;

    // Apply bonus on top of existing history (if any) and base CF.
    final history = await _storage.getCfHistory();
    final existing = history[dateKey] ?? baseCf;

    // Ensure bonus is present exactly once by using (base + bonus) as target,
    // and never decreasing an already higher value.
    final target = (baseCf + cfBonus).clamp(0, 100);
    final finalCf = (existing > target ? existing : target).clamp(0, 100);

    await _storage.upsertCfForDate(dateKey: dateKey, cf: finalCf);
  }

  Future<Map<String, String>> _getCompletedMap() async {
    final p = await _prefs();
    final raw = p.getString(_kCompletedWorkoutsByDateKey);
    if (raw == null || raw.trim().isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final out = <String, String>{};
    for (final e in decoded.entries) {
      final k = e.key;
      final v = e.value;
      if (k is String && v is String) out[k] = v;
    }
    return out;
  }
}
