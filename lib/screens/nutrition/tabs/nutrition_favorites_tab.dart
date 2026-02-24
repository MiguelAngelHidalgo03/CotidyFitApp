import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'favorites_recipes_tab.dart';
import 'favorite_templates_tab.dart';

/// Unified "Favoritos" tab that shows two sub-tabs:
/// - Recetas (liked recipes)
/// - Plantillas (liked templates)
class NutritionFavoritesTab extends StatelessWidget {
  const NutritionFavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: CFColors.primary,
              unselectedLabelColor: CFColors.textSecondary,
              indicatorColor: CFColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Recetas'),
                Tab(text: 'Plantillas'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                FavoritesRecipesTab(),
                FavoriteTemplatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
