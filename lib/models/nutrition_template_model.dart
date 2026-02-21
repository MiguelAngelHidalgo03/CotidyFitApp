import 'package:cloud_firestore/cloud_firestore.dart';

import 'price_tier.dart';

/// Dynamic nutrition template stored in Firestore.
///
/// Collection: templates
/// Fields (snake_case as per spec):
/// - name, description
/// - calories_total, protein_total, carbs_total, fats_total
/// - diet_type (vegetariano | vegano | sin_gluten | omnivoro)
/// - goal_tags (array or string)
/// - price_level (economico | medio | alto)
/// - created_at, updated_at
///
/// Aggregates (add-only, for ordering/perf):
/// - total_likes (number)
/// - rating_sum (number)
/// - rating_count (number)
/// - avg_rating (number)
class NutritionTemplateModel {
  const NutritionTemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.caloriesTotal,
    required this.proteinTotal,
    required this.carbsTotal,
    required this.fatsTotal,
    required this.dietType,
    required this.goalTags,
    required this.priceTier,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.totalLikes,
    required this.avgRating,
    required this.ratingCount,
  });

  final String id;
  final String name;
  final String description;

  final num caloriesTotal;
  final num proteinTotal;
  final num carbsTotal;
  final num fatsTotal;

  /// vegetariano | vegano | sin_gluten | omnivoro
  final String dietType;

  /// perdida_peso | alta_proteina | saciante | volumen | saludable
  final List<String> goalTags;

  final PriceTier priceTier;

  final int createdAtMs;
  final int updatedAtMs;

  final int totalLikes;
  final double avgRating;
  final int ratingCount;

  static NutritionTemplateModel? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    if (data == null) return null;

    T read<T>(String key, T fallback) {
      final v = data[key];
      if (v is T) return v;
      return fallback;
    }

    num readNum(String key, num fallback) {
      final v = data[key];
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? fallback;
      return fallback;
    }

    int readInt(String key, int fallback) {
      final v = data[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    double readDouble(String key, double fallback) {
      final v = data[key];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    final name = (data['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    final description = (data['description'] as String?)?.trim() ?? '';

    final priceRaw = (data['price_level'] as String?)?.trim().toLowerCase();
    final priceTier = switch (priceRaw) {
      'economico' => PriceTier.economical,
      'alto' => PriceTier.high,
      _ => PriceTier.medium,
    };

    final goalsRaw = data['goal_tags'];
    final goalTags = <String>[];
    if (goalsRaw is List) {
      for (final v in goalsRaw) {
        final s = v?.toString().trim();
        if (s != null && s.isNotEmpty) goalTags.add(s);
      }
    } else if (goalsRaw is String) {
      final s = goalsRaw.trim();
      if (s.isNotEmpty) goalTags.add(s);
    }

    final createdAt = data['created_at'];
    final updatedAt = data['updated_at'];
    final createdAtMs = createdAt is Timestamp
        ? createdAt.millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;
    final updatedAtMs = updatedAt is Timestamp
        ? updatedAt.millisecondsSinceEpoch
        : createdAtMs;

    return NutritionTemplateModel(
      id: snap.id,
      name: name,
      description: description,
      caloriesTotal: readNum('calories_total', 0),
      proteinTotal: readNum('protein_total', 0),
      carbsTotal: readNum('carbs_total', 0),
      fatsTotal: readNum('fats_total', 0),
      dietType: read('diet_type', '').toString().trim(),
      goalTags: goalTags,
      priceTier: priceTier,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
      totalLikes: readInt('total_likes', 0).clamp(0, 1 << 30),
      avgRating: readDouble('avg_rating', 0).clamp(0, 5),
      ratingCount: readInt('rating_count', 0).clamp(0, 1 << 30),
    );
  }
}
