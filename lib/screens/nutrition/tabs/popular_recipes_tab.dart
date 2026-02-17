import 'package:flutter/material.dart';

import '../../../models/recipe_model.dart';
import '../../../services/recipes_local_service.dart';
import '../../../widgets/nutrition/recipe_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';

class PopularRecipesTab extends StatefulWidget {
  const PopularRecipesTab({super.key});

  @override
  State<PopularRecipesTab> createState() => _PopularRecipesTabState();
}

class _PopularRecipesTabState extends State<PopularRecipesTab> {
  final _recipes = RecipesLocalService();

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
    all.sort((a, b) => b.likes.compareTo(a.likes));

    if (!mounted) return;
    setState(() {
      _items = all;
      _loading = false;
    });
  }

  Future<void> _open(RecipeModel r) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgressSectionCard(
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Más populares',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final r in _items) ...[
            RecipeCard(recipe: r, onTap: () => _open(r)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
