import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme.dart';
import '../../../models/nutrition_template_model.dart';
import '../../../models/recipe_model.dart';
import '../../../models/template_recipe_link_model.dart';
import '../../../services/my_day_repository.dart';
import '../../../services/my_day_repository_factory.dart';
import '../../../services/nutrition_templates_firestore_service.dart';
import '../../../services/recipe_repository.dart';
import '../../../services/recipes_repository_factory.dart';
import '../../../services/template_ingredient_check_local_service.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../recipe_detail_screen.dart';
import 'ingredient_check_bottom_sheet.dart';

class TemplateDetailBottomSheet extends StatefulWidget {
  const TemplateDetailBottomSheet({
    super.key,
    required this.template,
    required this.currentUser,
  });

  final NutritionTemplateModel template;
  final User? currentUser;

  @override
  State<TemplateDetailBottomSheet> createState() =>
      _TemplateDetailBottomSheetState();
}

class _TemplateDetailBottomSheetState extends State<TemplateDetailBottomSheet> {
  final _templatesDb = NutritionTemplatesFirestoreService();
  final RecipeRepository _recipes = RecipesRepositoryFactory.create();
  final MyDayRepository _myDay = MyDayRepositoryFactory.create();
  final _ingredientChecks = TemplateIngredientCheckLocalService();

  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String get _uidKey => widget.currentUser?.uid ?? 'anon';

  Future<_DetailData> _load() async {
    final links = await _templatesDb.getTemplateRecipes(
      templateId: widget.template.id,
    );
    final all = await _recipes.getAllRecipes();
    final recipeById = {for (final r in all) r.id: r};

    final ingredientLabelByKey = <String, String>{};
    for (final link in links) {
      final r = recipeById[link.recipeId];
      if (r == null) continue;
      for (final ing in r.ingredients) {
        final key = _ingredientChecks.normalizeIngredientKey(ing.name);
        if (key.isEmpty) continue;
        ingredientLabelByKey.putIfAbsent(key, () => ing.name.trim());
      }
    }

    final have = await _ingredientChecks.getHaveIngredients(
      uidKey: _uidKey,
      templateId: widget.template.id,
    );

    final items = [
      for (final e in ingredientLabelByKey.entries)
        IngredientCheckItem(key: e.key, label: e.value.isEmpty ? e.key : e.value),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return _DetailData(
      links: links,
      recipeById: recipeById,
      ingredients: items,
      haveIngredients: have,
    );
  }

  String _slotLabel(String slot) {
    switch (slot.trim().toLowerCase()) {
      case 'desayuno':
        return 'Desayuno';
      case 'comida':
        return 'Comida';
      case 'merienda':
        return 'Merienda';
      case 'cena':
        return 'Cena';
    }
    return slot;
  }

  MealType? _mealTypeFromSlot(String slot) {
    switch (slot.trim().toLowerCase()) {
      case 'desayuno':
        return MealType.breakfast;
      case 'comida':
        return MealType.lunch;
      case 'merienda':
        return MealType.snack;
      case 'cena':
        return MealType.dinner;
    }
    return null;
  }

  Future<void> _openIngredientsChecklist(_DetailData data) async {
    if (data.ingredients.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return IngredientCheckBottomSheet(
          title: 'Ingredientes · ${widget.template.name}',
          items: data.ingredients,
          initialHaveKeys: data.haveIngredients,
          onChanged: (next) async {
            await _ingredientChecks.setHaveIngredients(
              uidKey: _uidKey,
              templateId: widget.template.id,
              haveKeys: next,
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openRecipe(String recipeId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _saveToMyDay(_DetailData data) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (picked == null) return;

    final toAdd = <({MealType mealType, String recipeId})>[];
    for (final link in data.links) {
      final mt = _mealTypeFromSlot(link.mealSlot);
      if (mt == null) continue;
      toAdd.add((mealType: mt, recipeId: link.recipeId));
    }

    if (toAdd.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta plantilla no tiene recetas asociadas.')),
      );
      return;
    }

    await _myDay.addMany(day: picked, entries: toAdd);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardado en “Mi día”.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: CFColors.softGray,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.template.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (widget.template.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.template.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: CFColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 14),

                ProgressSectionCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen nutricional',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(text: '${widget.template.caloriesTotal.round()} kcal'),
                          _Chip(text: 'P ${widget.template.proteinTotal.round()}g'),
                          _Chip(text: 'C ${widget.template.carbsTotal.round()}g'),
                          _Chip(text: 'G ${widget.template.fatsTotal.round()}g'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                FutureBuilder<_DetailData>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final data = snap.data;
                    if (data == null) {
                      return const ProgressSectionCard(
                        child: Text('No se pudo cargar la plantilla.'),
                      );
                    }

                    final bySlot = <String, List<TemplateRecipeLinkModel>>{};
                    for (final link in data.links) {
                      bySlot.putIfAbsent(link.mealSlot, () => []).add(link);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recetas',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openIngredientsChecklist(data),
                              icon: const Icon(Icons.checklist_outlined),
                              label: const Text('Ingredientes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final slot in bySlot.keys) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                            child: Text(
                              _slotLabel(slot),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          for (final link in (bySlot[slot] ?? const [])) ...[
                            ProgressSectionCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.restaurant, color: CFColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      data.recipeById[link.recipeId]?.name ?? 'Receta',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Abrir',
                                    onPressed: () => _openRecipe(link.recipeId),
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],

                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _saveToMyDay(data),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Guardar en mi día'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailData {
  const _DetailData({
    required this.links,
    required this.recipeById,
    required this.ingredients,
    required this.haveIngredients,
  });

  final List<TemplateRecipeLinkModel> links;
  final Map<String, RecipeModel> recipeById;
  final List<IngredientCheckItem> ingredients;
  final Set<String> haveIngredients;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: CFColors.textPrimary),
      ),
    );
  }
}
