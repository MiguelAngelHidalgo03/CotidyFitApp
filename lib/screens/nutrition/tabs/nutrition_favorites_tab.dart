import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'favorites_recipes_tab.dart';
import 'favorite_templates_tab.dart';

/// Unified "Favoritos" tab that shows two sub-tabs:
/// - Recetas (liked recipes)
/// - Plantillas (liked templates)
class NutritionFavoritesTab extends StatefulWidget {
  const NutritionFavoritesTab({super.key});

  @override
  State<NutritionFavoritesTab> createState() => NutritionFavoritesTabState();
}

class NutritionFavoritesTabState extends State<NutritionFavoritesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get hasNext => _tabController.index < _tabController.length - 1;
  bool get hasPrevious => _tabController.index > 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void moveNext() {
    if (hasNext) {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  void movePrevious() {
    if (hasPrevious) {
      _tabController.animateTo(_tabController.index - 1);
    }
  }

  void moveToStart() {
    if (_tabController.index != 0) {
      _tabController.index = 0;
    }
  }

  void moveToEnd() {
    final targetIndex = _tabController.length - 1;
    if (_tabController.index != targetIndex) {
      _tabController.index = targetIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: context.cfPrimary,
            unselectedLabelColor: context.cfTextSecondary,
            indicatorColor: context.cfPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Recetas'),
              Tab(text: 'Plantillas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [FavoritesRecipesTab(), FavoriteTemplatesTab()],
          ),
        ),
      ],
    );
  }
}
