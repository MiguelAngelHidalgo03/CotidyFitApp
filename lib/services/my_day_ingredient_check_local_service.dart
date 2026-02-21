import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MyDayIngredientCheckLocalService {
  static const _kPrefix = 'cf_my_day_have_ingredients_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  String _key({
    required String uidKey,
    required String dateKey,
    required String recipeId,
  }) {
    return '${_kPrefix}_${uidKey}_${dateKey}_$recipeId';
  }

  String normalizeIngredientKey(String name) {
    return name.trim().toLowerCase();
  }

  Future<Set<String>> getHaveIngredients({
    required String uidKey,
    required String dateKey,
    required String recipeId,
  }) async {
    final p = await _prefs();
    final raw = p.getString(_key(uidKey: uidKey, dateKey: dateKey, recipeId: recipeId));
    if (raw == null || raw.trim().isEmpty) return <String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      final out = <String>{};
      for (final v in decoded) {
        final s = v?.toString().trim().toLowerCase();
        if (s != null && s.isNotEmpty) out.add(s);
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setHaveIngredients({
    required String uidKey,
    required String dateKey,
    required String recipeId,
    required Set<String> haveKeys,
  }) async {
    final p = await _prefs();
    final list = haveKeys.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList()..sort();
    await p.setString(
      _key(uidKey: uidKey, dateKey: dateKey, recipeId: recipeId),
      jsonEncode(list),
    );
  }
}
