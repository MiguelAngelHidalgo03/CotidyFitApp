import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';

class WorkoutPlanService {
  static const _kPlansByWeekKey = 'cf_workout_plans_by_week_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<WeekPlan?> getPlanForWeekKey(String weekStartKey) async {
    final map = await _getAllPlans();
    final raw = map[weekStartKey];
    if (raw == null || raw.trim().isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final obj = <String, Object?>{};
    for (final e in decoded.entries) {
      if (e.key is String) obj[e.key as String] = e.value;
    }

    return WeekPlan.fromJson(obj);
  }

  Future<void> upsertPlan(WeekPlan plan) async {
    final map = await _getAllPlans();
    map[plan.weekKey] = jsonEncode(plan.toJson());
    final p = await _prefs();
    await p.setString(_kPlansByWeekKey, jsonEncode(map));
  }

  Future<Map<String, String>> _getAllPlans() async {
    final p = await _prefs();
    final raw = p.getString(_kPlansByWeekKey);
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
