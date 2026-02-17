import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecipeRatingsLocalService {
  static const _kKey = 'cf_recipe_ratings_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Map<String, double>> _load() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <String, double>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, double>{};

    final out = <String, double>{};
    for (final entry in decoded.entries) {
      final k = entry.key.toString();
      final v = entry.value;
      if (v is num) out[k] = v.toDouble();
    }
    return out;
  }

  Future<void> _save(Map<String, double> map) async {
    final p = await _prefs();
    await p.setString(_kKey, jsonEncode(map));
  }

  Future<double?> getMyRating(String recipeId) async {
    final map = await _load();
    return map[recipeId];
  }

  Future<void> setMyRating(String recipeId, double rating) async {
    final r = rating.clamp(1, 5).toDouble();
    final map = await _load();
    map[recipeId] = r;
    await _save(map);
  }
}
