import 'package:flutter/material.dart';

import '../../../models/recipe_model.dart';
import '../../../services/recipe_favorites_local_service.dart';
import '../../../services/recipes_local_service.dart';
import '../../../widgets/nutrition/recipe_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';

class FavoritesRecipesTab extends StatefulWidget {
  const FavoritesRecipesTab({super.key});

  @override
  State<FavoritesRecipesTab> createState() => _FavoritesRecipesTabState();
}

class _FavoritesRecipesTabState extends State<FavoritesRecipesTab> {
  final _recipes = RecipesLocalService();
  final _favorites = RecipeFavoritesLocalService();

  bool _loading = true;
  List<RecipeModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _recipes.getAllRecipes();
    final favIds = await _favorites.getFavoriteIds();

    final items = all.where((r) => favIds.contains(r.id)).toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(RecipeModel r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Favoritas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Guarda recetas para verlas aquí.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = _items[index];
          return RecipeCard(recipe: r, onTap: () => _open(r));
        },
      ),
    );
  }
}
