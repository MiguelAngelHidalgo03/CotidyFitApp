import 'package:flutter/material.dart';

import 'nutrition/tabs/diet_templates_tab.dart';
import 'nutrition/tabs/explore_recipes_tab.dart';
import 'nutrition/tabs/favorites_recipes_tab.dart';
import 'nutrition/tabs/my_day_tab.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Plantillas'),
              Tab(text: 'Explorar recetas'),
              Tab(text: 'Recetas favoritas'),
              Tab(text: 'Mi día'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DietTemplatesTab(),
            ExploreRecipesTab(),
            FavoritesRecipesTab(),
            MyDayTab(),
          ],
        ),
      ),
    );
  }
}
