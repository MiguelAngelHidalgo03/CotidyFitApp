import '../models/nutrition_template_model.dart';
import '../models/recipe_model.dart';
import '../models/user_profile.dart';

class NutritionPersonalizationService {
  static double recipeRecommendationScore(
    UserProfile? profile,
    RecipeModel recipe, {
    bool isPeriodActive = false,
  }) {
    final popularity = (recipe.ratingAvg * 12) + (recipe.likes.clamp(0, 500) * 0.06);
    final periodBonus = isPeriodActive
        ? _periodSupportBonus(
            friendly: recipe.periodFriendly,
            tags: recipe.periodSupportTags,
            benefits: recipe.periodBenefits,
          )
        : 0.0;
    if (profile == null) return popularity + periodBonus;

    final targetMealKcal = _targetMealKcal(profile);
    final kcalPenalty = (recipe.kcalPerServing - targetMealKcal).abs();
    final kcalScore = (40 - (kcalPenalty / 20)).clamp(0, 40);

    final goalScore = _goalMatchScore(
      goal: profile.goal,
      recipeGoals: recipe.goals.map((g) => g.name).toList(),
    );

    final levelBonus = switch (profile.level) {
      UserLevel.principiante => recipe.difficulty == DifficultyLevel.easy ? 8.0 : 0.0,
      UserLevel.intermedio => recipe.difficulty == DifficultyLevel.medium ? 6.0 : 2.0,
      UserLevel.avanzado => recipe.difficulty == DifficultyLevel.hard ? 6.0 : 2.0,
    };

    return popularity + kcalScore + goalScore + levelBonus + periodBonus;
  }

  static double templateRecommendationScore(
    UserProfile? profile,
    NutritionTemplateModel template, {
    bool isPeriodActive = false,
  }) {
    final popularity = (template.avgRating * 12) + (template.totalLikes.clamp(0, 500) * 0.06);
    final periodBonus = isPeriodActive
        ? _periodSupportBonus(
            friendly: template.periodFriendly,
            tags: template.periodSupportTags,
            benefits: template.periodBenefits,
          )
        : 0.0;
    if (profile == null) return popularity + periodBonus;

    final targetDailyKcal = _targetDailyKcal(profile);
    final kcalPenalty = (template.caloriesTotal.toDouble() - targetDailyKcal).abs();
    final kcalScore = (40 - (kcalPenalty / 50)).clamp(0, 40);

    final goalScore = _goalMatchScore(
      goal: profile.goal,
      recipeGoals: template.goalTags,
    );

    return popularity + kcalScore + goalScore + periodBonus;
  }

  static double suggestedRecipeServingFactor(UserProfile? profile, RecipeModel recipe) {
    if (profile == null) return 1.0;
    if (recipe.kcalPerServing <= 0) return 1.0;

    final targetMealKcal = _targetMealKcal(profile);
    final ratio = targetMealKcal / recipe.kcalPerServing;
    return ratio.clamp(0.6, 1.8);
  }

  static double _targetDailyKcal(UserProfile profile) {
    final weight = profile.currentWeightKg;
    final height = profile.heightCm;
    final age = profile.age;

    // Fallback when physical data is missing.
    if (weight == null || height == null || age == null) {
      final base = weight == null ? 2200.0 : weight * 30;
      return _applyGoal(base, profile.goal);
    }

    final sexOffset = switch (profile.sex) {
      UserSex.hombre => 5.0,
      UserSex.mujer => -161.0,
      UserSex.otro || null => -80.0,
    };

    final bmr = (10 * weight) + (6.25 * height) - (5 * age) + sexOffset;

    final activity = switch (profile.level) {
      UserLevel.principiante => 1.35,
      UserLevel.intermedio => 1.5,
      UserLevel.avanzado => 1.65,
    };

    final maintenance = bmr * activity;
    return _applyGoal(maintenance, profile.goal);
  }

  static double _targetMealKcal(UserProfile profile) {
    final daily = _targetDailyKcal(profile);
    return (daily / 4).clamp(250, 950);
  }

  static double _applyGoal(double maintenance, String goal) {
    final g = goal.trim().toLowerCase();
    if (g.contains('perder') || g.contains('grasa') || g.contains('defin')) {
      return maintenance * 0.82;
    }
    if (g.contains('ganar') || g.contains('masa') || g.contains('volumen')) {
      return maintenance * 1.12;
    }
    return maintenance;
  }

  static double _goalMatchScore({required String goal, required List<String> recipeGoals}) {
    final g = goal.trim().toLowerCase();
    final tags = recipeGoals.map((e) => e.trim().toLowerCase()).toSet();

    var score = 0.0;
    if ((g.contains('perder') || g.contains('grasa') || g.contains('defin')) &&
        (tags.contains('weightloss') || tags.contains('fatloss') || tags.contains('perdida_peso'))) {
      score += 18;
    }
    if ((g.contains('ganar') || g.contains('masa') || g.contains('volumen')) &&
        (tags.contains('musclegain') || tags.contains('volumen') || tags.contains('ganancia_muscular'))) {
      score += 18;
    }
    if (g.contains('hábito') || g.contains('salud')) {
      if (tags.contains('saludable') || tags.contains('filling') || tags.contains('saciante')) {
        score += 12;
      }
    }
    if (tags.contains('highprotein') || tags.contains('alta_proteina')) {
      score += 6;
    }
    return score;
  }

  static double _periodSupportBonus({
    required bool friendly,
    required List<String> tags,
    required List<String> benefits,
  }) {
    final normalizedTags = {
      ...tags.map(_normalizeTag),
      ...benefits.map(_normalizeTag),
    };

    if (!friendly && normalizedTags.isEmpty) return 0;

    var score = friendly ? 26.0 : 18.0;
    if (normalizedTags.any((e) => e.contains('dolor') || e.contains('pain') || e.contains('cramp'))) {
      score += 4;
    }
    if (normalizedTags.any((e) => e.contains('hinch') || e.contains('bloat'))) {
      score += 3;
    }
    if (normalizedTags.any((e) => e.contains('energia') || e.contains('fatiga') || e.contains('iron'))) {
      score += 3;
    }
    return score;
  }

  static String _normalizeTag(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
  }
}
