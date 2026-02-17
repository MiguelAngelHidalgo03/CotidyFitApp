import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe_model.dart';
import 'recipe_repository.dart';

class RecipesLocalService implements RecipeRepository {
  static const _kKey = 'cf_recipes_json_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<void> seedIfEmpty() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw != null && raw.trim().isNotEmpty) return;

    final recipes = _seedRecipes();
    await p.setString(_kKey, RecipeModel.encodeList(recipes));
  }

  @override
  Future<List<RecipeModel>> getAllRecipes() async {
    await seedIfEmpty();
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return RecipeModel.decodeList(raw);
  }

  @override
  Future<RecipeModel?> getRecipeById(String id) async {
    final list = await getAllRecipes();
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<RecipeModel> _seedRecipes() {
    // Mock catalog: enough variety to exercise filters/search.
    return const [
      RecipeModel(
        id: 'r_overnight_oats',
        name: 'Overnight oats proteicos',
        country: 'EE.UU.',
        ratingAvg: 4.6,
        ratingCount: 842,
        likes: 12140,
        kcalPerServing: 420,
        gramsPerServing: 350,
        servings: 1,
        durationMinutes: 8,
        macrosPerServing: RecipeMacros(proteinG: 33, carbsG: 45, fatG: 12),
        dietTypes: [DietType.vegetarian, DietType.highProtein, DietType.noRestrictions],
        allergenFree: [AllergenFree.eggFree, AllergenFree.soyFree],
        mealTypes: [MealType.breakfast, MealType.snack],
        goals: [RecipeGoal.highProtein, RecipeGoal.quickEnergy, RecipeGoal.filling],
        difficulty: DifficultyLevel.easy,
        utensils: ['Bol', 'Cuchara'],
        ingredients: [
          RecipeIngredient(name: 'Avena', amount: 60, unit: 'g'),
          RecipeIngredient(name: 'Yogur griego', amount: 200, unit: 'g'),
          RecipeIngredient(name: 'Leche', amount: 120, unit: 'ml'),
          RecipeIngredient(name: 'Proteína en polvo', amount: 25, unit: 'g'),
          RecipeIngredient(name: 'Plátano', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Canela'),
        ],
        steps: [
          RecipeStep(text: 'Mezcla avena, yogur, leche y proteína.'),
          RecipeStep(text: 'Añade canela al gusto y remueve.'),
          RecipeStep(text: 'Deja reposar 10 min (o en nevera para el día siguiente).'),
          RecipeStep(text: 'Sirve con plátano en rodajas.'),
        ],
      ),
      RecipeModel(
        id: 'r_tofu_stir_fry',
        name: 'Salteado vegano de tofu',
        country: 'China',
        ratingAvg: 4.4,
        ratingCount: 1250,
        likes: 9830,
        kcalPerServing: 520,
        gramsPerServing: 420,
        servings: 2,
        durationMinutes: 18,
        macrosPerServing: RecipeMacros(proteinG: 28, carbsG: 38, fatG: 26),
        dietTypes: [DietType.vegan, DietType.lowCarb],
        allergenFree: [AllergenFree.lactoseFree, AllergenFree.eggFree, AllergenFree.glutenFree],
        mealTypes: [MealType.lunch, MealType.dinner],
        goals: [RecipeGoal.filling, RecipeGoal.weightLoss],
        difficulty: DifficultyLevel.medium,
        utensils: ['Sartén', 'Cuchillo'],
        ingredients: [
          RecipeIngredient(name: 'Tofu firme', amount: 250, unit: 'g'),
          RecipeIngredient(name: 'Brócoli', amount: 150, unit: 'g'),
          RecipeIngredient(name: 'Pimiento', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Salsa tamari'),
          RecipeIngredient(name: 'Ajo', amount: 1, unit: 'diente'),
          RecipeIngredient(name: 'Aceite de oliva', amount: 1, unit: 'cda'),
        ],
        steps: [
          RecipeStep(text: 'Dora el tofu en la sartén con un poco de aceite.'),
          RecipeStep(text: 'Añade verduras y saltea 6–8 min.'),
          RecipeStep(text: 'Agrega tamari y ajo, cocina 2 min más.'),
          RecipeStep(text: 'Sirve caliente.'),
        ],
      ),
      RecipeModel(
        id: 'r_salmon_bowl',
        name: 'Bowl pescetariano de salmón',
        country: 'Noruega',
        ratingAvg: 4.7,
        ratingCount: 2101,
        likes: 16890,
        kcalPerServing: 610,
        gramsPerServing: 480,
        servings: 1,
        durationMinutes: 20,
        macrosPerServing: RecipeMacros(proteinG: 42, carbsG: 55, fatG: 22),
        dietTypes: [DietType.pescatarian, DietType.highProtein],
        allergenFree: [AllergenFree.eggFree, AllergenFree.lactoseFree],
        mealTypes: [MealType.lunch, MealType.dinner],
        goals: [RecipeGoal.muscleGain, RecipeGoal.highProtein],
        difficulty: DifficultyLevel.easy,
        utensils: ['Sartén', 'Bol'],
        ingredients: [
          RecipeIngredient(name: 'Salmón', amount: 160, unit: 'g'),
          RecipeIngredient(name: 'Arroz cocido', amount: 180, unit: 'g'),
          RecipeIngredient(name: 'Aguacate', amount: 0.5, unit: 'ud'),
          RecipeIngredient(name: 'Pepino', amount: 0.5, unit: 'ud'),
          RecipeIngredient(name: 'Sésamo'),
          RecipeIngredient(name: 'Limón'),
        ],
        steps: [
          RecipeStep(text: 'Cocina el salmón 3–4 min por lado.'),
          RecipeStep(text: 'Monta el bol con arroz y vegetales.'),
          RecipeStep(text: 'Añade el salmón y termina con limón y sésamo.'),
        ],
      ),
      RecipeModel(
        id: 'r_chicken_wrap',
        name: 'Wrap alto en proteína',
        country: 'España',
        ratingAvg: 4.5,
        ratingCount: 650,
        likes: 7620,
        kcalPerServing: 540,
        gramsPerServing: 420,
        servings: 1,
        durationMinutes: 12,
        macrosPerServing: RecipeMacros(proteinG: 45, carbsG: 48, fatG: 16),
        dietTypes: [DietType.highProtein, DietType.noRestrictions],
        allergenFree: [AllergenFree.nutFree, AllergenFree.soyFree],
        mealTypes: [MealType.lunch, MealType.dinner, MealType.bite],
        goals: [RecipeGoal.highProtein, RecipeGoal.quickEnergy],
        difficulty: DifficultyLevel.easy,
        utensils: ['Sartén', 'Cuchillo'],
        ingredients: [
          RecipeIngredient(name: 'Tortilla de trigo', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Pollo cocido', amount: 160, unit: 'g'),
          RecipeIngredient(name: 'Lechuga', amount: 60, unit: 'g'),
          RecipeIngredient(name: 'Tomate', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Yogur natural', amount: 60, unit: 'g'),
          RecipeIngredient(name: 'Mostaza'),
        ],
        steps: [
          RecipeStep(text: 'Mezcla yogur con mostaza para una salsa rápida.'),
          RecipeStep(text: 'Rellena la tortilla con pollo y vegetales.'),
          RecipeStep(text: 'Añade la salsa, enrolla y dora 1 min por lado.'),
        ],
      ),
      RecipeModel(
        id: 'r_shakshuka',
        name: 'Shakshuka (huevos con tomate)',
        country: 'Marruecos',
        ratingAvg: 4.3,
        ratingCount: 930,
        likes: 5310,
        kcalPerServing: 470,
        gramsPerServing: 400,
        servings: 2,
        durationMinutes: 35,
        macrosPerServing: RecipeMacros(proteinG: 22, carbsG: 28, fatG: 28),
        dietTypes: [DietType.vegetarian, DietType.lowCarb],
        allergenFree: [AllergenFree.glutenFree, AllergenFree.lactoseFree, AllergenFree.nutFree, AllergenFree.soyFree],
        mealTypes: [MealType.breakfast, MealType.lunch, MealType.dinner],
        goals: [RecipeGoal.filling, RecipeGoal.weightLoss],
        difficulty: DifficultyLevel.medium,
        utensils: ['Sartén'],
        ingredients: [
          RecipeIngredient(name: 'Tomate triturado', amount: 400, unit: 'g'),
          RecipeIngredient(name: 'Huevos', amount: 4, unit: 'ud'),
          RecipeIngredient(name: 'Cebolla', amount: 0.5, unit: 'ud'),
          RecipeIngredient(name: 'Pimentón'),
          RecipeIngredient(name: 'Comino'),
        ],
        steps: [
          RecipeStep(text: 'Pocha cebolla y especias 3 min.'),
          RecipeStep(text: 'Añade tomate y cocina 15–20 min.'),
          RecipeStep(text: 'Haz huecos y cocina los huevos 5–7 min.'),
        ],
      ),
      RecipeModel(
        id: 'r_greek_salad',
        name: 'Ensalada griega saciante',
        country: 'Grecia',
        ratingAvg: 4.2,
        ratingCount: 410,
        likes: 4020,
        kcalPerServing: 390,
        gramsPerServing: 380,
        servings: 2,
        durationMinutes: 10,
        macrosPerServing: RecipeMacros(proteinG: 16, carbsG: 18, fatG: 26),
        dietTypes: [DietType.vegetarian, DietType.lowCarb],
        allergenFree: [AllergenFree.glutenFree, AllergenFree.eggFree, AllergenFree.soyFree],
        mealTypes: [MealType.lunch, MealType.dinner, MealType.starter],
        goals: [RecipeGoal.weightLoss, RecipeGoal.filling],
        difficulty: DifficultyLevel.easy,
        utensils: ['Bol', 'Cuchillo'],
        ingredients: [
          RecipeIngredient(name: 'Pepino', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Tomate', amount: 2, unit: 'ud'),
          RecipeIngredient(name: 'Aceitunas', amount: 60, unit: 'g'),
          RecipeIngredient(name: 'Queso feta', amount: 80, unit: 'g'),
          RecipeIngredient(name: 'Aceite de oliva', amount: 1, unit: 'cda'),
        ],
        steps: [
          RecipeStep(text: 'Corta verduras en dados.'),
          RecipeStep(text: 'Mezcla con aceitunas, feta y aceite.'),
        ],
      ),
      RecipeModel(
        id: 'r_banana_pancakes',
        name: 'Pancakes de plátano sin gluten',
        country: 'Argentina',
        ratingAvg: 4.1,
        ratingCount: 300,
        likes: 2850,
        kcalPerServing: 360,
        gramsPerServing: 280,
        servings: 1,
        durationMinutes: 15,
        macrosPerServing: RecipeMacros(proteinG: 18, carbsG: 42, fatG: 12),
        dietTypes: [DietType.vegetarian],
        allergenFree: [AllergenFree.glutenFree, AllergenFree.nutFree, AllergenFree.soyFree],
        mealTypes: [MealType.breakfast, MealType.dessert],
        goals: [RecipeGoal.quickEnergy],
        difficulty: DifficultyLevel.easy,
        utensils: ['Sartén', 'Bol'],
        ingredients: [
          RecipeIngredient(name: 'Plátano', amount: 1, unit: 'ud'),
          RecipeIngredient(name: 'Huevos', amount: 2, unit: 'ud'),
          RecipeIngredient(name: 'Copos de avena sin gluten', amount: 30, unit: 'g'),
        ],
        steps: [
          RecipeStep(text: 'Tritura plátano con huevos y avena.'),
          RecipeStep(text: 'Cocina en sartén antiadherente 2 min por lado.'),
        ],
      ),
    ];
  }
}
