import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_meal_model.dart';

/// Persists a library of reusable custom meals in SharedPreferences.
/// These can be added to any day via DailyDataService.
class SavedCustomMealsService {
  static const _kKey = 'cf_saved_custom_meals_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<CustomMealModel>> getAll() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return [
      for (final e in decoded)
        if (e is Map)
          ...[CustomMealModel.fromJson(
            e.map((k, v) => MapEntry(k.toString(), v)),
          )].whereType<CustomMealModel>(),
    ];
  }

  Future<void> save(CustomMealModel meal) async {
    final all = await getAll();
    // Avoid duplicate IDs.
    all.removeWhere((m) => m.id == meal.id);
    all.insert(0, meal);
    await _persist(all);
  }

  Future<void> remove(String mealId) async {
    final all = await getAll();
    all.removeWhere((m) => m.id == mealId);
    await _persist(all);
  }

  Future<void> _persist(List<CustomMealModel> meals) async {
    final p = await _prefs();
    final encoded = jsonEncode([for (final m in meals) m.toJson()]);
    await p.setString(_kKey, encoded);
  }
}
