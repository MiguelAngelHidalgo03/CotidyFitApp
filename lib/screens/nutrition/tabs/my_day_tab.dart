import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/custom_meal_model.dart';
import '../../../models/my_day_entry_model.dart';
import '../../../models/recipe_model.dart';
import '../../../services/daily_data_service.dart';
import '../../../services/my_day_local_service.dart';
import '../../../services/recipes_local_service.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';
import '../widgets/custom_meal_bottom_sheet.dart';

class MyDayTab extends StatefulWidget {
  const MyDayTab({super.key});

  @override
  State<MyDayTab> createState() => _MyDayTabState();
}

class _MyDayTabState extends State<MyDayTab> {
  final _myDay = MyDayLocalService();
  final _recipes = RecipesLocalService();
  final _dailyData = DailyDataService();

  DateTime _day = DateTime.now();
  bool _loading = true;
  List<MyDayEntryModel> _entries = const [];
  List<CustomMealEntryModel> _customMeals = const [];
  Map<String, RecipeModel> _recipeById = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _myDay.getForDate(_day);
    final all = await _recipes.getAllRecipes();
    final map = {for (final r in all) r.id: r};

    final dateKey = dateKeyFromDate(_day);
    final daily = await _dailyData.getForDateKey(dateKey);

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _customMeals = daily.customMeals;
      _recipeById = map;
      _loading = false;
    });
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _day,
    );
    if (picked == null) return;
    setState(() => _day = picked);
    await _load();
  }

  Future<void> _openRecipe(String recipeId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipeId)));
    await _load();
  }

  Future<void> _remove(MyDayEntryModel e) async {
    await _myDay.remove(e.id);
    await _load();
  }

  Future<void> _addCustomMeal() async {
    final result = await showModalBottomSheet<CustomMealDraftResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomMealBottomSheet(),
    );

    if (result == null) return;

    final dateKey = dateKeyFromDate(_day);
    await _dailyData.addCustomMeal(
      dateKey: dateKey,
      mealType: result.mealType,
      meal: result.meal,
    );
    await _load();
  }

  Future<void> _removeCustomMeal(CustomMealEntryModel e) async {
    final dateKey = dateKeyFromDate(_day);
    await _dailyData.removeCustomMeal(dateKey: dateKey, entryId: e.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final grouped = <MealType, List<MyDayEntryModel>>{};
    for (final e in _entries) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }

    final groupedCustom = <MealType, List<CustomMealEntryModel>>{};
    for (final e in _customMeals) {
      groupedCustom.putIfAbsent(e.mealType, () => []).add(e);
    }

    final dayLabel = dateKeyFromDate(_day);
    final hasAny = _entries.isNotEmpty || _customMeals.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgressSectionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: CFColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Mi día · $dayLabel', style: Theme.of(context).textTheme.titleLarge),
                ),
                TextButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ProgressSectionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: CFColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Agregar comida personalizada',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton(
                  onPressed: _addCustomMeal,
                  child: const Text('Agregar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!hasAny)
            ProgressSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sin registros', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Añade recetas desde el detalle o crea una comida personalizada.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          for (final meal in MealType.values) ...[
            if ((grouped[meal]?.isNotEmpty == true) || (groupedCustom[meal]?.isNotEmpty == true)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(meal.label, style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final e in (grouped[meal] ?? const <MyDayEntryModel>[])) ...[
                ProgressSectionCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant, color: CFColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _recipeById[e.recipeId]?.name ?? 'Receta',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Abrir',
                        onPressed: () => _openRecipe(e.recipeId),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: () => _remove(e),
                        icon: const Icon(Icons.delete_outline, color: CFColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (final e in (groupedCustom[meal] ?? const <CustomMealEntryModel>[])) ...[
                ProgressSectionCard(
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
                              e.meal.nombre,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${e.meal.calorias} kcal · P ${e.meal.proteinas}g · C ${e.meal.carbohidratos}g · G ${e.meal.grasas}g',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: () => _removeCustomMeal(e),
                        icon: const Icon(Icons.delete_outline, color: CFColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
