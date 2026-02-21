import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/my_day_entry_model.dart';
import '../../models/recipe_model.dart';
import '../../services/my_day_repository.dart';
import '../../services/my_day_repository_factory.dart';
import '../../services/recipe_favorites_local_service.dart';
import '../../services/recipe_ratings_local_service.dart';
import '../../services/recipe_repository.dart';
import '../../services/recipes_repository_factory.dart';
import '../../widgets/progress/progress_section_card.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeRepository _recipes = RecipesRepositoryFactory.create();
  final _favorites = RecipeFavoritesLocalService();
  final _ratings = RecipeRatingsLocalService();
  final MyDayRepository _myDay = MyDayRepositoryFactory.create();

  bool _loading = true;
  RecipeModel? _recipe;
  bool _isFavorite = false;
  double? _myRating;
  final Set<int> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _recipes.getRecipeById(widget.recipeId);
    final fav = r == null ? false : await _favorites.isFavorite(r.id);
    final myRating = r == null ? null : await _ratings.getMyRating(r.id);

    if (!mounted) return;
    setState(() {
      _recipe = r;
      _isFavorite = fav;
      _myRating = myRating;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final r = _recipe;
    if (r == null) return;
    final nowFav = await _favorites.toggleFavorite(r.id);
    if (!mounted) return;
    setState(() => _isFavorite = nowFav);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowFav ? 'Añadida a Favoritas' : 'Quitada de Favoritas'),
      ),
    );
  }

  Future<void> _rate() async {
    final r = _recipe;
    if (r == null) return;

    var value = _myRating ?? 4.0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Puntuar receta'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Slider(
                    value: value,
                    min: 1,
                    max: 5,
                    divisions: 40,
                    onChanged: (v) => setLocal(() => value = v),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    await _ratings.setMyRating(r.id, value);
    if (!mounted) return;
    setState(() => _myRating = value);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Puntuación guardada (local).')),
    );
  }

  Future<void> _addToMyDay() async {
    final r = _recipe;
    if (r == null) return;

    var day = DateTime.now();
    var meal = MealType.lunch;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setLocal) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Añadir a Mi día',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: CFColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateKeyFromDate(day),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate: day,
                              );
                              if (picked == null) return;
                              setLocal(() => day = picked);
                            },
                            child: const Text('Cambiar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<MealType>(
                        key: ValueKey(meal),
                        initialValue: meal,
                        items: [
                          for (final m in MealType.values)
                            DropdownMenuItem(value: m, child: Text(m.label)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => meal = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tipo de comida',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir'),
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

    if (confirmed != true) return;

    await _myDay.add(day: day, mealType: meal, recipeId: r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Añadida a Mi día (local).')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final r = _recipe;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receta')),
        body: const SafeArea(
          child: Center(child: Text('Receta no encontrada.')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: 'Favorito',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: CFColors.primary,
            ),
          ),
          IconButton(
            tooltip: 'Puntuar',
            onPressed: _rate,
            icon: const Icon(Icons.star_outline, color: CFColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Hero(
              tag: 'recipe_${r.id}',
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(22)),
                  border: Border.all(color: CFColors.softGray),
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: CFColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ProgressSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CFColors.primary.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                          border: Border.all(color: CFColors.primary),
                        ),
                        child: Text(
                          r.country,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: CFColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _statChip(
                        icon: Icons.star,
                        label:
                            '${r.ratingAvg.toStringAsFixed(1)} (${r.ratingCount})',
                      ),
                      _statChip(
                        icon: Icons.favorite,
                        label: '${r.likes} likes',
                      ),
                      _statChip(
                        icon: Icons.local_fire_department_outlined,
                        label: '${r.kcalPerServing} kcal/ración',
                      ),
                      _statChip(
                        icon: Icons.local_fire_department,
                        label: '${r.kcalPer100g} kcal/100g',
                      ),
                      _statChip(
                        icon: Icons.schedule,
                        label: '${r.durationMinutes} min',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Macronutrientes (por ración)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _macroTile(
                          title: 'Proteína',
                          value: '${r.macrosPerServing.proteinG} g',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _macroTile(
                          title: 'Carbs',
                          value: '${r.macrosPerServing.carbsG} g',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _macroTile(
                          title: 'Grasa',
                          value: '${r.macrosPerServing.fatG} g',
                        ),
                      ),
                    ],
                  ),
                  if (_myRating != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Tu puntuación: ${_myRating!.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addToMyDay,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Añadir a Mi día'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ProgressSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingredientes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < r.ingredients.length; i++) ...[
                    CheckboxListTile(
                      value: _checkedIngredients.contains(i),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _checkedIngredients.add(i);
                          } else {
                            _checkedIngredients.remove(i);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        r.ingredients[i].display,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            ProgressSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pasos', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (var i = 0; i < r.steps.length; i++) ...[
                    _stepTile(index: i + 1, text: r.steps[i].text),
                    if (i != r.steps.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Vídeo: próximamente',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _statChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CFColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: CFColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _macroTile({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: CFColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: CFColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _stepTile({required int index, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: CFColors.primary.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(color: CFColors.primary),
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: CFColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: CFColors.textPrimary,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
