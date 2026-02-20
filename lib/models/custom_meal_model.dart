import 'dart:convert';

import 'recipe_model.dart';

class CustomMealFoodItem {
  const CustomMealFoodItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final String name;
  final int grams;
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  Map<String, Object?> toJson() => {
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  static CustomMealFoodItem? fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;

    int readInt(String key) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final grams = readInt('grams');
    final kcal = readInt('kcal');
    final proteinG = readInt('proteinG');
    final carbsG = readInt('carbsG');
    final fatG = readInt('fatG');

    return CustomMealFoodItem(
      name: name.trim(),
      grams: grams < 0 ? 0 : grams,
      kcal: kcal < 0 ? 0 : kcal,
      proteinG: proteinG < 0 ? 0 : proteinG,
      carbsG: carbsG < 0 ? 0 : carbsG,
      fatG: fatG < 0 ? 0 : fatG,
    );
  }
}

class CustomMealModel {
  const CustomMealModel({
    required this.id,
    required this.nombre,
    required this.listaAlimentos,
    required this.calorias,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  final String id;
  final String nombre;
  final List<CustomMealFoodItem> listaAlimentos;
  final int calorias;
  final int proteinas;
  final int carbohidratos;
  final int grasas;

  Map<String, Object?> toJson() => {
        'id': id,
        'nombre': nombre,
        'listaAlimentos': [for (final f in listaAlimentos) f.toJson()],
        'calorias': calorias,
        'proteinas': proteinas,
        'carbohidratos': carbohidratos,
        'grasas': grasas,
      };

  static CustomMealModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    if (id is! String || id.trim().isEmpty) return null;
    if (nombre is! String || nombre.trim().isEmpty) return null;

    int readInt(String key) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final alimentosRaw = json['listaAlimentos'];
    final alimentos = <CustomMealFoodItem>[];
    if (alimentosRaw is List) {
      for (final v in alimentosRaw) {
        if (v is Map) {
          final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
          final item = CustomMealFoodItem.fromJson(casted);
          if (item != null) alimentos.add(item);
        }
      }
    }

    return CustomMealModel(
      id: id.trim(),
      nombre: nombre.trim(),
      listaAlimentos: alimentos,
      calorias: readInt('calorias').clamp(0, 200000),
      proteinas: readInt('proteinas').clamp(0, 20000),
      carbohidratos: readInt('carbohidratos').clamp(0, 20000),
      grasas: readInt('grasas').clamp(0, 20000),
    );
  }
}

class CustomMealEntryModel {
  const CustomMealEntryModel({
    required this.id,
    required this.mealType,
    required this.meal,
    required this.addedAtMs,
  });

  final String id;
  final MealType mealType;
  final CustomMealModel meal;
  final int addedAtMs;

  Map<String, Object?> toJson() => {
        'id': id,
        'mealType': mealType.name,
        'meal': meal.toJson(),
        'addedAtMs': addedAtMs,
      };

  static CustomMealEntryModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final mealTypeRaw = json['mealType'];
    final mealRaw = json['meal'];
    final addedAtMs = json['addedAtMs'];

    if (id is! String || id.trim().isEmpty) return null;
    if (mealTypeRaw is! String || mealTypeRaw.trim().isEmpty) return null;
    if (mealRaw is! Map) return null;
    if (addedAtMs is! num) return null;

    final mt = MealType.values.where((e) => e.name == mealTypeRaw).cast<MealType?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );
    if (mt == null) return null;

    final castedMeal = mealRaw.map((k, v) => MapEntry(k.toString(), v));
    final meal = CustomMealModel.fromJson(castedMeal);
    if (meal == null) return null;

    return CustomMealEntryModel(
      id: id.trim(),
      mealType: mt,
      meal: meal,
      addedAtMs: addedAtMs.toInt(),
    );
  }

  static List<CustomMealEntryModel> decodeList(Object? raw) {
    if (raw is String) {
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      return decodeList(decoded);
    }

    if (raw is! List) return const [];

    final out = <CustomMealEntryModel>[];
    for (final v in raw) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final e = CustomMealEntryModel.fromJson(casted);
        if (e != null) out.add(e);
      }
    }
    out.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return out;
  }

  static Object encodeList(List<CustomMealEntryModel> items) {
    return [for (final e in items) e.toJson()];
  }
}
