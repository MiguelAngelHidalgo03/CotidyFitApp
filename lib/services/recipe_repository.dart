import '../models/recipe_model.dart';

abstract class RecipeRepository {
  Future<void> seedIfEmpty();
  Future<List<RecipeModel>> getAllRecipes();
  Future<RecipeModel?> getRecipeById(String id);
}
