import 'dart:convert';

import 'price_tier.dart';

enum DietType {
  vegetarian,
  vegan,
  pescatarian,
  noRestrictions,
  highProtein,
  lowCarb,
}

extension DietTypeLabel on DietType {
  String get label => switch (this) {
        DietType.vegetarian => 'Vegetariano',
        DietType.vegan => 'Vegano',
        DietType.pescatarian => 'Pescetariano',
        DietType.noRestrictions => 'Sin restricciones',
        DietType.highProtein => 'Alta proteína',
        DietType.lowCarb => 'Bajo carbohidrato',
      };
}

enum AllergenFree {
  glutenFree,
  lactoseFree,
  nutFree,
  eggFree,
  soyFree,
}

extension AllergenFreeLabel on AllergenFree {
  String get label => switch (this) {
        AllergenFree.glutenFree => 'Sin gluten',
        AllergenFree.lactoseFree => 'Sin lactosa',
        AllergenFree.nutFree => 'Sin frutos secos',
        AllergenFree.eggFree => 'Sin huevo',
        AllergenFree.soyFree => 'Sin soja',
      };
}

enum DurationRange {
  under10,
  min10to20,
  min20to40,
  over40,
}

extension DurationRangeLabel on DurationRange {
  String get label => switch (this) {
        DurationRange.under10 => '<10 min',
        DurationRange.min10to20 => '10–20 min',
        DurationRange.min20to40 => '20–40 min',
        DurationRange.over40 => '40+ min',
      };

  bool containsMinutes(int minutes) => switch (this) {
        DurationRange.under10 => minutes < 10,
        DurationRange.min10to20 => minutes >= 10 && minutes <= 20,
        DurationRange.min20to40 => minutes > 20 && minutes <= 40,
        DurationRange.over40 => minutes > 40,
      };
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  dessert,
  bite,
  starter,
}

extension MealTypeLabel on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Desayuno',
        MealType.lunch => 'Comida',
        MealType.dinner => 'Cena',
        MealType.snack => 'Merienda',
        MealType.dessert => 'Postre',
        MealType.bite => 'Tentempié',
        MealType.starter => 'Entrante',
      };
}

enum RecipeGoal {
  weightLoss,
  filling,
  highProtein,
  muscleGain,
  quickEnergy,
}

extension RecipeGoalLabel on RecipeGoal {
  String get label => switch (this) {
        RecipeGoal.weightLoss => 'Pérdida de peso',
        RecipeGoal.filling => 'Saciante',
        RecipeGoal.highProtein => 'Alta proteína',
        RecipeGoal.muscleGain => 'Ganancia muscular',
        RecipeGoal.quickEnergy => 'Energía rápida',
      };
}

enum DifficultyLevel {
  easy,
  medium,
  hard,
}

extension DifficultyLevelLabel on DifficultyLevel {
  String get label => switch (this) {
        DifficultyLevel.easy => 'Fácil',
        DifficultyLevel.medium => 'Medio',
        DifficultyLevel.hard => 'Difícil',
      };
}

class RecipeMacros {
  const RecipeMacros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;

  Map<String, dynamic> toJson() => {
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  static RecipeMacros? fromJson(Map<String, dynamic> json) {
    final p = json['proteinG'];
    final c = json['carbsG'];
    final f = json['fatG'];
    if (p is! num || c is! num || f is! num) return null;
    return RecipeMacros(proteinG: p.toInt(), carbsG: c.toInt(), fatG: f.toInt());
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.amount,
    this.unit,
  });

  final String name;
  final num? amount;
  final String? unit;

  String get display {
    final a = amount;
    final u = unit;
    if (a == null) return name;
    if (u == null || u.trim().isEmpty) return '$a $name';
    return '$a $u · $name';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };

  static RecipeIngredient? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final amount = json['amount'];
    final unit = json['unit'];
    return RecipeIngredient(
      name: name,
      amount: amount is num ? amount : null,
      unit: unit is String ? unit : null,
    );
  }
}

class RecipeStep {
  const RecipeStep({
    required this.text,
    this.videoUrl,
  });

  final String text;
  final String? videoUrl;

  Map<String, dynamic> toJson() => {
        'text': text,
        'videoUrl': videoUrl,
      };

  static RecipeStep? fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final url = json['videoUrl'];
    return RecipeStep(text: text, videoUrl: url is String ? url : null);
  }
}

class RecipeModel {
  const RecipeModel({
    required this.id,
    required this.name,
    required this.country,
    required this.priceTier,
    required this.ratingAvg,
    required this.ratingCount,
    required this.likes,
    required this.kcalPerServing,
    required this.gramsPerServing,
    required this.servings,
    required this.durationMinutes,
    required this.macrosPerServing,
    required this.dietTypes,
    required this.allergenFree,
    required this.mealTypes,
    required this.goals,
    required this.difficulty,
    required this.utensils,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String name;
  final String country;

  final PriceTier priceTier;

  final double ratingAvg;
  final int ratingCount;
  final int likes;

  final int kcalPerServing;
  final int gramsPerServing;
  final int servings;

  final int durationMinutes;
  final RecipeMacros macrosPerServing;

  final List<DietType> dietTypes;
  final List<AllergenFree> allergenFree;
  final List<MealType> mealTypes;
  final List<RecipeGoal> goals;
  final DifficultyLevel difficulty;

  final List<String> utensils;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  int get kcalPer100g {
    if (gramsPerServing <= 0) return kcalPerServing;
    return ((kcalPerServing / gramsPerServing) * 100).round();
  }

  List<String> get ingredientNamesLower => [for (final i in ingredients) i.name.toLowerCase()];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
      'priceTier': priceTier.name,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'likes': likes,
        'kcalPerServing': kcalPerServing,
        'gramsPerServing': gramsPerServing,
        'servings': servings,
        'durationMinutes': durationMinutes,
        'macrosPerServing': macrosPerServing.toJson(),
        'dietTypes': [for (final d in dietTypes) d.name],
        'allergenFree': [for (final a in allergenFree) a.name],
        'mealTypes': [for (final m in mealTypes) m.name],
        'goals': [for (final g in goals) g.name],
        'difficulty': difficulty.name,
        'utensils': utensils,
        'ingredients': [for (final i in ingredients) i.toJson()],
        'steps': [for (final s in steps) s.toJson()],
      };

  static RecipeModel? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final country = json['country'];
    final priceTierRaw = json['priceTier'];
    final ratingAvg = json['ratingAvg'];
    final ratingCount = json['ratingCount'];
    final likes = json['likes'];
    final kcalPerServing = json['kcalPerServing'];
    final gramsPerServing = json['gramsPerServing'];
    final servings = json['servings'];
    final durationMinutes = json['durationMinutes'];
    final macros = json['macrosPerServing'];

    if (id is! String || id.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (country is! String || country.trim().isEmpty) return null;
    if (ratingAvg is! num) return null;
    if (ratingCount is! num) return null;
    if (likes is! num) return null;
    if (kcalPerServing is! num) return null;
    if (gramsPerServing is! num) return null;
    if (servings is! num) return null;
    if (durationMinutes is! num) return null;
    if (macros is! Map) return null;

    final macrosCasted = macros.map((k, v) => MapEntry(k.toString(), v));
    final macrosObj = RecipeMacros.fromJson(macrosCasted);
    if (macrosObj == null) return null;

    final priceTier = priceTierRaw is String
      ? PriceTier.values.where((e) => e.name == priceTierRaw).cast<PriceTier?>().firstOrNull
      : null;

    List<T> parseEnumList<T extends Enum>(
      Object? raw,
      List<T> values,
    ) {
      if (raw is! List) return const [];
      final out = <T>[];
      for (final v in raw) {
        if (v is! String) continue;
        final found = values.where((e) => e.name == v).toList();
        if (found.isNotEmpty) out.add(found.first);
      }
      return out;
    }

    final dietTypes = parseEnumList(json['dietTypes'], DietType.values);
    final allergenFree = parseEnumList(json['allergenFree'], AllergenFree.values);
    final mealTypes = parseEnumList(json['mealTypes'], MealType.values);
    final goals = parseEnumList(json['goals'], RecipeGoal.values);

    final diff = json['difficulty'];
    final difficulty = diff is String
        ? DifficultyLevel.values.where((e) => e.name == diff).cast<DifficultyLevel?>().firstOrNull
        : null;

    final utensilsRaw = json['utensils'];
    final utensils = <String>[];
    if (utensilsRaw is List) {
      for (final u in utensilsRaw) {
        if (u is String && u.trim().isNotEmpty) utensils.add(u);
      }
    }

    final ingredientsRaw = json['ingredients'];
    final ingredients = <RecipeIngredient>[];
    if (ingredientsRaw is List) {
      for (final i in ingredientsRaw) {
        if (i is Map) {
          final casted = i.map((k, v) => MapEntry(k.toString(), v));
          final obj = RecipeIngredient.fromJson(casted);
          if (obj != null) ingredients.add(obj);
        }
      }
    }

    final stepsRaw = json['steps'];
    final steps = <RecipeStep>[];
    if (stepsRaw is List) {
      for (final s in stepsRaw) {
        if (s is Map) {
          final casted = s.map((k, v) => MapEntry(k.toString(), v));
          final obj = RecipeStep.fromJson(casted);
          if (obj != null) steps.add(obj);
        }
      }
    }

    if (difficulty == null) return null;

    return RecipeModel(
      id: id,
      name: name,
      country: country,
      priceTier: priceTier ?? PriceTier.medium,
      ratingAvg: ratingAvg.toDouble(),
      ratingCount: ratingCount.toInt(),
      likes: likes.toInt(),
      kcalPerServing: kcalPerServing.toInt(),
      gramsPerServing: gramsPerServing.toInt(),
      servings: servings.toInt(),
      durationMinutes: durationMinutes.toInt(),
      macrosPerServing: macrosObj,
      dietTypes: dietTypes,
      allergenFree: allergenFree,
      mealTypes: mealTypes,
      goals: goals,
      difficulty: difficulty,
      utensils: utensils,
      ingredients: ingredients,
      steps: steps,
    );
  }

  static String encodeList(List<RecipeModel> recipes) => jsonEncode([for (final r in recipes) r.toJson()]);

  static List<RecipeModel> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <RecipeModel>[];
    for (final v in decoded) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final r = RecipeModel.fromJson(casted);
        if (r != null) out.add(r);
      }
    }
    return out;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
