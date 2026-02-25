import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../models/custom_meal_model.dart';
import '../../../models/my_day_entry_model.dart';
import '../../../models/recipe_model.dart';
import '../../../services/daily_data_service.dart';
import '../../../services/custom_meals_firestore_service.dart';
import '../../../services/my_day_ingredient_check_local_service.dart';
import '../../../services/my_day_repository.dart';
import '../../../services/my_day_repository_factory.dart';
import '../../../services/recipe_repository.dart';
import '../../../services/recipes_repository_factory.dart';
import '../../../services/saved_custom_meals_service.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';
import '../widgets/custom_meal_bottom_sheet.dart';
import '../widgets/ingredient_check_bottom_sheet.dart';

class MyDayTab extends StatefulWidget {
  const MyDayTab({super.key});

  @override
  State<MyDayTab> createState() => _MyDayTabState();
}

class _MyDayTabState extends State<MyDayTab> {
  final MyDayRepository _myDay = MyDayRepositoryFactory.create();
  final RecipeRepository _recipes = RecipesRepositoryFactory.create();
  final _dailyData = DailyDataService();
  final _ingredientChecks = MyDayIngredientCheckLocalService();
  final _savedMealsService = SavedCustomMealsService();
  final _customMealsCloud = CustomMealsFirestoreService();

  DateTime _day = DateTime.now();
  bool _loading = true;
  List<MyDayEntryModel> _entries = const [];
  List<CustomMealEntryModel> _customMeals = const [];
  Map<String, RecipeModel> _recipeById = const {};
  List<CustomMealModel> _savedMeals = const [];
  bool _didCloudMigration = false;

  bool get _canUseCloud =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final entries = await _myDay
          .getForDate(_day)
          .timeout(const Duration(seconds: 10));
      final all = await _recipes
          .getAllRecipes()
          .timeout(const Duration(seconds: 10));
      final map = {for (final r in all) r.id: r};

      final dateKey = dateKeyFromDate(_day);

      List<CustomMealEntryModel> customMeals;
      List<CustomMealModel> savedMeals;

      if (_canUseCloud) {
        if (!_didCloudMigration) {
          final localByDate = await _dailyData
              .getAllCustomMealsByDate()
              .timeout(const Duration(seconds: 10));
          for (final localEntry in localByDate.entries) {
            await _customMealsCloud.setDailyEntriesForDate(
              dateKey: localEntry.key,
              entries: localEntry.value,
            );
          }

          final localSavedAll = await _savedMealsService
              .getAll()
              .timeout(const Duration(seconds: 5));
          if (localSavedAll.isNotEmpty) {
            await _customMealsCloud.setSavedMeals(localSavedAll);
          }
          _didCloudMigration = true;
        }

        customMeals = await _customMealsCloud
            .getForDateKey(dateKey)
            .timeout(const Duration(seconds: 10));
        savedMeals = await _customMealsCloud
            .getSavedMeals()
            .timeout(const Duration(seconds: 10));
      } else {
        final daily = await _dailyData
            .getForDateKey(dateKey)
            .timeout(const Duration(seconds: 10));
        customMeals = daily.customMeals;
        savedMeals = await _savedMealsService
            .getAll()
            .timeout(const Duration(seconds: 5));
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _customMeals = customMeals;
        _recipeById = map;
        _savedMeals = savedMeals;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('MyDayTab._load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  String get _uidKey {
    if (Firebase.apps.isEmpty) return 'anon';
    return FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  }

  Future<void> _openIngredientsForRecipe({
    required String recipeId,
  }) async {
    final recipe = _recipeById[recipeId];
    if (recipe == null) return;

    final dateKey = dateKeyFromDate(_day);
    final have = await _ingredientChecks.getHaveIngredients(
      uidKey: _uidKey,
      dateKey: dateKey,
      recipeId: recipeId,
    );

    if (!mounted) return;

    final labelByKey = <String, String>{};
    for (final ing in recipe.ingredients) {
      final key = _ingredientChecks.normalizeIngredientKey(ing.name);
      if (key.isEmpty) continue;
      labelByKey.putIfAbsent(key, () => ing.name.trim());
    }

    final items = [
      for (final e in labelByKey.entries)
        IngredientCheckItem(key: e.key, label: e.value.isEmpty ? e.key : e.value),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return IngredientCheckBottomSheet(
          title: 'Ingredientes · ${recipe.name}',
          items: items,
          initialHaveKeys: have,
          onChanged: (next) async {
            await _ingredientChecks.setHaveIngredients(
              uidKey: _uidKey,
              dateKey: dateKey,
              recipeId: recipeId,
              haveKeys: next,
            );
          },
        );
      },
    );
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
    if (_canUseCloud) {
      await _customMealsCloud.addCustomMeal(
        dateKey: dateKey,
        mealType: result.mealType,
        meal: result.meal,
      );
    } else {
      await _dailyData.addCustomMeal(
        dateKey: dateKey,
        mealType: result.mealType,
        meal: result.meal,
      );
    }
    await _load();
  }

  Future<void> _saveCustomMealForFuture(CustomMealModel meal) async {
    if (_canUseCloud) {
      await _customMealsCloud.saveSavedMeal(meal);
    } else {
      await _savedMealsService.save(meal);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardada para futuro: ${meal.nombre}')),
    );
    await _load();
  }

  Future<void> _removeCustomMeal(CustomMealEntryModel e) async {
    if (_canUseCloud) {
      await _customMealsCloud.removeCustomMeal(e.id);
    } else {
      final dateKey = dateKeyFromDate(_day);
      await _dailyData.removeCustomMeal(dateKey: dateKey, entryId: e.id);
    }
    await _load();
  }

  Future<void> _reuseSavedMeal(CustomMealModel meal) async {
    final mealType = await showDialog<MealType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿En qué comida?'),
        children: [
          for (final m in MealType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(m),
              child: Text(m.label),
            ),
        ],
      ),
    );
    if (mealType == null) return;

    final dateKey = dateKeyFromDate(_day);
    // Give a fresh id so it's a new entry
    final freshMeal = CustomMealModel(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      nombre: meal.nombre,
      listaAlimentos: meal.listaAlimentos,
      calorias: meal.calorias,
      proteinas: meal.proteinas,
      carbohidratos: meal.carbohidratos,
      grasas: meal.grasas,
    );
    if (_canUseCloud) {
      await _customMealsCloud.addCustomMeal(
        dateKey: dateKey,
        mealType: mealType,
        meal: freshMeal,
      );
    } else {
      await _dailyData.addCustomMeal(
        dateKey: dateKey,
        mealType: mealType,
        meal: freshMeal,
      );
    }
    await _load();
  }

  Future<void> _openSavedMealsPicker() async {
    if (!mounted) return;

    String q = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final query = q.trim().toLowerCase();
                  final filtered = _savedMeals
                      .where((m) => query.isEmpty || m.nombre.toLowerCase().contains(query))
                      .toList();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recetas personalizadas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setModalState(() => q = v),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            query.isEmpty
                                ? 'No tienes recetas personalizadas guardadas todavía.'
                                : 'Sin resultados para "$query".',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final meal = filtered[i];
                              return ProgressSectionCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.bookmark_outline, color: CFColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            meal.nombre,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${meal.calorias} kcal · P ${meal.proteinas}g · C ${meal.carbohidratos}g · G ${meal.grasas}g',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        await _reuseSavedMeal(meal);
                                      },
                                      child: const Text('Usar hoy'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
          ProgressSectionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline, color: CFColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recetas personalizadas (${_savedMeals.length})',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton(
                  onPressed: _openSavedMealsPicker,
                  child: const Text('Abrir'),
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
                        child: InkWell(
                          onTap: () => _openRecipe(e.recipeId),
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              _recipeById[e.recipeId]?.name ?? 'Receta',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ingredientes',
                        onPressed: () => _openIngredientsForRecipe(recipeId: e.recipeId),
                        icon: const Icon(Icons.checklist_outlined, color: CFColors.textSecondary),
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
                        tooltip: 'Guardar para futuro',
                        onPressed: () => _saveCustomMealForFuture(e.meal),
                        icon: const Icon(Icons.bookmark_add_outlined, color: CFColors.primary),
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
