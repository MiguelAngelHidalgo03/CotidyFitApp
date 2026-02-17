import 'dart:convert';

import 'recipe_model.dart';

class MyDayEntryModel {
  const MyDayEntryModel({
    required this.id,
    required this.dateKey,
    required this.mealType,
    required this.recipeId,
    required this.addedAtMs,
  });

  final String id;
  /// yyyy-MM-dd (local)
  final String dateKey;
  final MealType mealType;
  final String recipeId;
  final int addedAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'mealType': mealType.name,
        'recipeId': recipeId,
        'addedAtMs': addedAtMs,
      };

  static MyDayEntryModel? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final dateKey = json['dateKey'];
    final mealType = json['mealType'];
    final recipeId = json['recipeId'];
    final addedAtMs = json['addedAtMs'];

    if (id is! String || id.trim().isEmpty) return null;
    if (dateKey is! String || dateKey.trim().isEmpty) return null;
    if (mealType is! String || mealType.trim().isEmpty) return null;
    if (recipeId is! String || recipeId.trim().isEmpty) return null;
    if (addedAtMs is! num) return null;

    final mt = MealType.values.where((e) => e.name == mealType).toList();
    if (mt.isEmpty) return null;

    return MyDayEntryModel(
      id: id,
      dateKey: dateKey,
      mealType: mt.first,
      recipeId: recipeId,
      addedAtMs: addedAtMs.toInt(),
    );
  }

  static String encodeList(List<MyDayEntryModel> items) => jsonEncode([for (final e in items) e.toJson()]);

  static List<MyDayEntryModel> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <MyDayEntryModel>[];
    for (final v in decoded) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final e = MyDayEntryModel.fromJson(casted);
        if (e != null) out.add(e);
      }
    }
    return out;
  }
}

String dateKeyFromDate(DateTime dt) {
  final d = DateTime(dt.year, dt.month, dt.day);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
