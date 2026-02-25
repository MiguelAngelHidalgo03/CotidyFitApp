import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/recipe_filters.dart';
import '../../../models/recipe_model.dart';
import '../../../models/user_profile.dart';
import '../../../services/recipe_repository.dart';
import '../../../services/recipes_repository_factory.dart';
import '../../../services/profile_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/nutrition_personalization_service.dart';
import '../../../widgets/nutrition/recipe_card.dart';
import '../../../widgets/nutrition/recipe_compact_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';
import '../widgets/recipe_filters_sheet.dart';

class ExploreRecipesTab extends StatefulWidget {
  const ExploreRecipesTab({super.key});

  @override
  State<ExploreRecipesTab> createState() => _ExploreRecipesTabState();
}

class _ExploreRecipesTabState extends State<ExploreRecipesTab> {
  final RecipeRepository _recipes = RecipesRepositoryFactory.create();
  final _profileService = ProfileService();
  final _settingsService = SettingsService();

  List<RecipeModel> _all = const [];
  bool _loading = true;
  String _query = '';
  RecipeFilters _filters = RecipeFilters.empty();
  UserProfile? _profile;
  bool _showNutritionValues = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await _recipes
          .getAllRecipes()
          .timeout(const Duration(seconds: 10));
      final profile = await _profileService.getProfile();
      final settings = await _settingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _all = items;
        _profile = profile;
        _showNutritionValues = settings.showNutritionValues;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep previous data if available; just stop loading.
      debugPrint('ExploreRecipesTab._load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RecipeModel> get _filteredBase {
    return _all.where((r) => _filters.matches(r, _query)).toList();
  }

  List<RecipeModel> get _popularSorted {
    final list = [..._filteredBase];
    list.sort((a, b) => b.likes.compareTo(a.likes));
    return list;
  }

  List<RecipeModel> get _recommendedSorted {
    final list = [..._filteredBase];
    list.sort((a, b) {
      final sb = NutritionPersonalizationService.recipeRecommendationScore(_profile, b);
      final sa = NutritionPersonalizationService.recipeRecommendationScore(_profile, a);
      final r = sb.compareTo(sa);
      if (r != 0) return r;
      return b.likes.compareTo(a.likes);
    });
    return list;
  }

  Future<void> _openFilters() async {
    final availableCountries = {for (final r in _all) r.country}.toList()
      ..sort();

    final availableUtensils = {for (final r in _all) ...r.utensils}.toList()
      ..sort();

    final updated = await showModalBottomSheet<RecipeFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RecipeFiltersSheet(
          initial: _filters,
          availableCountries: availableCountries,
          availableUtensils: availableUtensils,
        );
      },
    );

    if (updated == null) return;
    setState(() => _filters = updated);
  }

  Future<void> _openRecipe(RecipeModel recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final popular = _popularSorted.take(8).toList();
    final popularIds = {for (final r in popular) r.id};
    final recommended = _recommendedSorted
        .where((r) => !popularIds.contains(r.id))
        .take(8)
        .toList();
    final allList = _popularSorted;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: ProgressSectionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o ingrediente…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _openFilters,
                  tooltip: 'Filtros',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune, color: CFColors.primary),
                      if (!_filters.isEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: CFColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                if (allList.isEmpty)
                  ProgressSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sin resultados',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Prueba a quitar filtros o buscar otro ingrediente.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                if (popular.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeader(title: 'Más populares'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: popular.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final r = popular[index];
                        return SizedBox(
                          width: 340,
                          child: RecipeCompactCard(
                            recipe: r,
                            onTap: () => _openRecipe(r),
                            showNutritionValues: _showNutritionValues,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (recommended.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionHeader(title: 'Recomendadas'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recommended.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final r = recommended[index];
                        return SizedBox(
                          width: 340,
                          child: RecipeCompactCard(
                            recipe: r,
                            onTap: () => _openRecipe(r),
                            showNutritionValues: _showNutritionValues,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (allList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionHeader(title: 'Todas'),
                  const SizedBox(height: 10),
                  for (final r in allList) ...[
                    RecipeCard(
                      recipe: r,
                      onTap: () => _openRecipe(r),
                      showNutritionValues: _showNutritionValues,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
