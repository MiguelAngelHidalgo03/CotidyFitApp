import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../models/food_model.dart';
import '../../../models/recipe_model.dart';
import '../../../services/custom_foods_firestore_service.dart';
import '../../../services/recipe_interactions_firestore_service.dart';
import '../../../services/recipes_repository_factory.dart';
import '../../../widgets/nutrition/recipe_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';

class FavoritesRecipesTab extends StatefulWidget {
  const FavoritesRecipesTab({super.key});

  @override
  State<FavoritesRecipesTab> createState() => _FavoritesRecipesTabState();
}

class _FavoritesRecipesTabState extends State<FavoritesRecipesTab> {
  final _interactions = RecipeInteractionsFirestoreService();
  final _customFoods = CustomFoodsFirestoreService();

  bool _loading = true;
  String? _error;
  List<RecipeModel> _items = const [];
  List<FoodModel> _myFoods = const [];

  bool get _firebaseReady =>
      Firebase.apps.isNotEmpty &&
      FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // Guard: skip Firestore queries when not authenticated.
    if (!_firebaseReady) {
      if (mounted) {
        setState(() {
          _items = const [];
          _myFoods = const [];
          _loading = false;
        });
      }
      return;
    }

    try {
      final recipes = RecipesRepositoryFactory.create();
      final all = await recipes
          .getAllRecipes()
          .timeout(const Duration(seconds: 10));
      final favIds = await _interactions
          .getLikedRecipeIds()
          .timeout(const Duration(seconds: 10));

      List<FoodModel> foods = const [];
      try {
        foods = await _customFoods
            .getAll()
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Custom foods are optional; ignore failures.
      }

      final items = all.where((r) => favIds.contains(r.id)).toList();
      items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _items = items;
        _myFoods = foods;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error al cargar favoritas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(RecipeModel r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)),
    );
    await _load();
  }

  Future<void> _deleteCustomFood(FoodModel food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alimento'),
        content: Text('¿Eliminar "${food.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _customFoods.delete(food.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (!_firebaseReady) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Favoritas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Inicia sesión para ver tus recetas favoritas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final hasRecipes = _items.isNotEmpty;
    final hasFoods = _myFoods.isNotEmpty;

    if (!hasRecipes && !hasFoods) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Favoritas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Guarda recetas o crea alimentos personalizados para verlos aquí.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasRecipes) ...[
            Text(
              'Recetas favoritas',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _items.length; i++) ...[
              RecipeCard(
                recipe: _items[i],
                onTap: () => _open(_items[i]),
              ),
              if (i < _items.length - 1) const SizedBox(height: 12),
            ],
          ],
          if (hasFoods) ...[
            if (hasRecipes) const SizedBox(height: 20),
            Text(
              'Mis alimentos personalizados',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _myFoods.length; i++) ...[
              _CustomFoodTile(
                food: _myFoods[i],
                onDelete: () => _deleteCustomFood(_myFoods[i]),
              ),
              if (i < _myFoods.length - 1) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _CustomFoodTile extends StatelessWidget {
  const _CustomFoodTile({required this.food, required this.onDelete});

  final FoodModel food;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: CFColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Por 100g · ${food.kcalPer100g} kcal · P ${food.proteinPer100g}g · C ${food.carbsPer100g}g · G ${food.fatPer100g}g',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: CFColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
