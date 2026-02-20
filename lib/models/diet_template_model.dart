import 'dart:convert';

import 'price_tier.dart';
enum DietTemplateKind {
  fatLoss,
  maintenance,
  bulk;

  String get label => switch (this) {
        DietTemplateKind.fatLoss => 'Pérdida de grasa',
        DietTemplateKind.maintenance => 'Mantenimiento',
        DietTemplateKind.bulk => 'Volumen',
      };
}

class MacroSplit {
  const MacroSplit({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  final int proteinPct;
  final int carbsPct;
  final int fatPct;

  Map<String, Object?> toJson() => {
        'proteinPct': proteinPct,
        'carbsPct': carbsPct,
        'fatPct': fatPct,
      };

  factory MacroSplit.fromJson(Map<String, Object?> json) {
    int readInt(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.round();
      return fallback;
    }

    return MacroSplit(
      proteinPct: readInt('proteinPct', 30),
      carbsPct: readInt('carbsPct', 40),
      fatPct: readInt('fatPct', 30),
    );
  }
}

class DietExampleMeal {
  const DietExampleMeal({
    required this.meal,
    required this.example,
  });

  final String meal;
  final String example;

  Map<String, Object?> toJson() => {
        'meal': meal,
        'example': example,
      };

  factory DietExampleMeal.fromJson(Map<String, Object?> json) {
    return DietExampleMeal(
      meal: (json['meal'] as String?) ?? '',
      example: (json['example'] as String?) ?? '',
    );
  }
}

class DietTemplateModel {
  const DietTemplateModel({
    required this.id,
    required this.kind,
    required this.priceTier,
    required this.estimatedCalories,
    required this.macros,
    required this.exampleDay,
    required this.shoppingList,
  });

  final String id;
  final DietTemplateKind kind;
  final PriceTier priceTier;
  final int estimatedCalories;
  final MacroSplit macros;
  final List<DietExampleMeal> exampleDay;
  final List<String> shoppingList;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
      'priceTier': priceTier.name,
        'estimatedCalories': estimatedCalories,
        'macros': macros.toJson(),
        'exampleDay': exampleDay.map((e) => e.toJson()).toList(),
        'shoppingList': shoppingList,
      };

  factory DietTemplateModel.fromJson(Map<String, Object?> json) {
    final kindRaw = (json['kind'] as String?) ?? DietTemplateKind.maintenance.name;
    final kind = DietTemplateKind.values.where((e) => e.name == kindRaw).cast<DietTemplateKind?>().firstOrNull ?? DietTemplateKind.maintenance;

    final priceTierRaw = json['priceTier'];
    final priceTier = priceTierRaw is String
        ? PriceTier.values.where((e) => e.name == priceTierRaw).cast<PriceTier?>().firstOrNull
        : null;

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

    final exampleRaw = json['exampleDay'];
    final example = <DietExampleMeal>[];
    if (exampleRaw is List) {
      for (final e in exampleRaw) {
        if (e is Map) {
          example.add(DietExampleMeal.fromJson(e.map((k, v) => MapEntry(k.toString(), v)) as Map<String, Object?>));
        }
      }
    }

    final listRaw = json['shoppingList'];
    final shopping = <String>[];
    if (listRaw is List) {
      for (final i in listRaw) {
        if (i is String && i.trim().isNotEmpty) shopping.add(i);
      }
    }

    return DietTemplateModel(
      id: (json['id'] as String?) ?? '',
      kind: kind,
      priceTier: priceTier ?? PriceTier.medium,
      estimatedCalories: readInt('estimatedCalories', 2200),
      macros: macros,
      exampleDay: example,
      shoppingList: shopping,
    );
  }
}

List<DietTemplateModel> dietTemplatesFromJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];

  final out = <DietTemplateModel>[];
  for (final e in decoded) {
    if (e is Map) {
      out.add(DietTemplateModel.fromJson(e.map((k, v) => MapEntry(k.toString(), v)) as Map<String, Object?>));
    }
  }
  return out;
}

String dietTemplatesToJson(List<DietTemplateModel> templates) {
  return jsonEncode(templates.map((e) => e.toJson()).toList());
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
