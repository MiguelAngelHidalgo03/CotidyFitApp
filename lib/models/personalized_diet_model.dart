import 'dart:convert';

import 'diet_template_model.dart';

class PersonalizedDietModel {
  const PersonalizedDietModel({
    required this.targetCalories,
    required this.macros,
    required this.preferences,
    required this.excludedIngredients,
    required this.createdAtMs,
  });

  final int targetCalories;
  final MacroSplit macros;
  final List<String> preferences;
  final List<String> excludedIngredients;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
        'targetCalories': targetCalories,
        'macros': macros.toJson(),
        'preferences': preferences,
        'excludedIngredients': excludedIngredients,
        'createdAtMs': createdAtMs,
      };

  factory PersonalizedDietModel.fromJson(Map<String, Object?> json) {
    int readInt(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.round();
      return fallback;
    }

    final macrosRaw = json['macros'];
    final macros = macrosRaw is Map
        ? MacroSplit.fromJson(macrosRaw.map((k, v) => MapEntry(k.toString(), v)) as Map<String, Object?>)
        : const MacroSplit(proteinPct: 30, carbsPct: 40, fatPct: 30);

    List<String> readStringList(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return PersonalizedDietModel(
      targetCalories: readInt('targetCalories', 2200),
      macros: macros,
      preferences: readStringList('preferences'),
      excludedIngredients: readStringList('excludedIngredients'),
      createdAtMs: readInt('createdAtMs', DateTime.now().millisecondsSinceEpoch),
    );
  }
}

PersonalizedDietModel? personalizedDietFromJsonString(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  return PersonalizedDietModel.fromJson(decoded.map((k, v) => MapEntry(k.toString(), v)) as Map<String, Object?>);
}

String personalizedDietToJsonString(PersonalizedDietModel model) {
  return jsonEncode(model.toJson());
}
