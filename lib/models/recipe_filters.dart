import 'recipe_model.dart';
import 'price_tier.dart';

class RecipeFilters {
  const RecipeFilters({
    this.dietTypes = const {},
    this.allergenFree = const {},
    this.durationRanges = const {},
    this.mealTypes = const {},
    this.goals = const {},
    this.priceTiers = const {},
    this.countries = const {},
    this.utensils = const {},
    this.difficulties = const {},
  });

  final Set<DietType> dietTypes;
  final Set<AllergenFree> allergenFree;
  final Set<DurationRange> durationRanges;
  final Set<MealType> mealTypes;
  final Set<RecipeGoal> goals;
  final Set<PriceTier> priceTiers;
  final Set<String> countries;
  final Set<String> utensils;
  final Set<DifficultyLevel> difficulties;

  RecipeFilters copyWith({
    Set<DietType>? dietTypes,
    Set<AllergenFree>? allergenFree,
    Set<DurationRange>? durationRanges,
    Set<MealType>? mealTypes,
    Set<RecipeGoal>? goals,
    Set<PriceTier>? priceTiers,
    Set<String>? countries,
    Set<String>? utensils,
    Set<DifficultyLevel>? difficulties,
  }) {
    return RecipeFilters(
      dietTypes: dietTypes ?? this.dietTypes,
      allergenFree: allergenFree ?? this.allergenFree,
      durationRanges: durationRanges ?? this.durationRanges,
      mealTypes: mealTypes ?? this.mealTypes,
      goals: goals ?? this.goals,
      priceTiers: priceTiers ?? this.priceTiers,
      countries: countries ?? this.countries,
      utensils: utensils ?? this.utensils,
      difficulties: difficulties ?? this.difficulties,
    );
  }

  bool get isEmpty =>
      dietTypes.isEmpty &&
      allergenFree.isEmpty &&
      durationRanges.isEmpty &&
      mealTypes.isEmpty &&
      goals.isEmpty &&
      priceTiers.isEmpty &&
      countries.isEmpty &&
      utensils.isEmpty &&
      difficulties.isEmpty;

  bool matches(RecipeModel recipe, String query) {
    if (dietTypes.isNotEmpty && !recipe.dietTypes.any(dietTypes.contains)) {
      return false;
    }

    if (allergenFree.isNotEmpty) {
      for (final a in allergenFree) {
        if (!recipe.allergenFree.contains(a)) return false;
      }
    }

    if (durationRanges.isNotEmpty && !durationRanges.any((r) => r.containsMinutes(recipe.durationMinutes))) {
      return false;
    }

    if (mealTypes.isNotEmpty && !recipe.mealTypes.any(mealTypes.contains)) {
      return false;
    }

    if (goals.isNotEmpty && !recipe.goals.any(goals.contains)) {
      return false;
    }

    if (priceTiers.isNotEmpty && !priceTiers.contains(recipe.priceTier)) {
      return false;
    }

    if (countries.isNotEmpty && !countries.contains(recipe.country)) {
      return false;
    }

    if (utensils.isNotEmpty) {
      final r = recipe.utensils.map((e) => e.toLowerCase()).toSet();
      for (final u in utensils) {
        if (!r.contains(u.toLowerCase())) return false;
      }
    }

    if (difficulties.isNotEmpty && !difficulties.contains(recipe.difficulty)) {
      return false;
    }

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final name = recipe.name.toLowerCase();
    final ingredientNames = recipe.ingredientNamesLower;

    for (final t in tokens) {
      final inName = name.contains(t);
      final inIngredients = ingredientNames.any((i) => i.contains(t));
      if (!inName && !inIngredients) return false;
    }

    return true;
  }

  static RecipeFilters empty() => const RecipeFilters();
}
