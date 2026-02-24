import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/recipe_model.dart';
import 'recipe_repository.dart';
import 'recipes_firestore_service.dart';
import 'recipes_local_service.dart';

class RecipesRepositoryFactory {
  static RecipeRepository create() {
    if (Firebase.apps.isEmpty) return RecipesLocalService();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RecipesLocalService();
    return _HybridRecipesRepository(
      remote: RecipesFirestoreService(),
      local: RecipesLocalService(),
    );
  }
}

class _HybridRecipesRepository implements RecipeRepository {
  _HybridRecipesRepository({required this.remote, required this.local});

  final RecipesFirestoreService remote;
  final RecipesLocalService local;

  Future<bool> _isRemoteEnabled() async {
    if (Firebase.apps.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    return user != null;
  }

  @override
  Future<void> seedIfEmpty() async {
    await local.seedIfEmpty();
  }

  @override
  Future<List<RecipeModel>> getAllRecipes() async {
    final enabled = await _isRemoteEnabled();
    if (!enabled) return local.getAllRecipes();

    try {
      final remoteItems = await remote.getAllRecipes();
      if (remoteItems.isNotEmpty) return remoteItems;
    } catch (_) {
      // ignore
    }

    return local.getAllRecipes();
  }

  @override
  Future<RecipeModel?> getRecipeById(String id) async {
    final enabled = await _isRemoteEnabled();
    if (!enabled) return local.getRecipeById(id);

    try {
      final r = await remote.getRecipeById(id);
      if (r != null) return r;
    } catch (_) {
      // ignore
    }

    return local.getRecipeById(id);
  }
}
