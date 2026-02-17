import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkoutHistoryService {
  // Must match WorkoutSessionService internal key.
  static const _kCompletedWorkoutsByDateKey = 'cf_completed_workouts_by_date_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Map<String, String>> getCompletedWorkoutsByDate() async {
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
