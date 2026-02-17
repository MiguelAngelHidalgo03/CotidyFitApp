import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecipeFavoritesLocalService {
  static const _kKey = 'cf_recipe_favorites_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<Set<String>> getFavoriteIds() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};

    return {
      for (final v in decoded)
        if (v is String && v.trim().isNotEmpty) v,
    };
  }

  Future<bool> isFavorite(String recipeId) async {
    final ids = await getFavoriteIds();
    return ids.contains(recipeId);
  }

  Future<bool> toggleFavorite(String recipeId) async {
    final ids = await getFavoriteIds();
    final nowFav = !ids.contains(recipeId);
    if (nowFav) {
      ids.add(recipeId);
    } else {
      ids.remove(recipeId);
    }

    final p = await _prefs();
    await p.setString(_kKey, jsonEncode(ids.toList()));
    return nowFav;
  }
}
