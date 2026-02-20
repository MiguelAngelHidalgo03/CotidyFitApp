import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/recipe_filters.dart';
import '../../../models/price_tier.dart';
import '../../../models/recipe_model.dart';
import '../../../widgets/progress/progress_section_card.dart';

class RecipeFiltersSheet extends StatefulWidget {
  const RecipeFiltersSheet({
    super.key,
    required this.initial,
    required this.availableCountries,
    required this.availableUtensils,
  });

  final RecipeFilters initial;
  final List<String> availableCountries;
  final List<String> availableUtensils;

  @override
  State<RecipeFiltersSheet> createState() => _RecipeFiltersSheetState();
}

class _RecipeFiltersSheetState extends State<RecipeFiltersSheet> {
  late RecipeFilters _filters = widget.initial;

  void _toggleEnum<T>(T v, Set<T> set) {
    final next = set.contains(v) ? (set.toSet()..remove(v)) : (set.toSet()..add(v));

    if (T == DietType) {
      _filters = _filters.copyWith(dietTypes: next.cast<DietType>());
    } else if (T == AllergenFree) {
      _filters = _filters.copyWith(allergenFree: next.cast<AllergenFree>());
    } else if (T == DurationRange) {
      _filters = _filters.copyWith(durationRanges: next.cast<DurationRange>());
    } else if (T == MealType) {
      _filters = _filters.copyWith(mealTypes: next.cast<MealType>());
    } else if (T == RecipeGoal) {
      _filters = _filters.copyWith(goals: next.cast<RecipeGoal>());
    } else if (T == PriceTier) {
      _filters = _filters.copyWith(priceTiers: next.cast<PriceTier>());
    } else if (T == DifficultyLevel) {
      _filters = _filters.copyWith(difficulties: next.cast<DifficultyLevel>());
    }

    setState(() {});
  }

  void _toggleString(String v, Set<String> set, {required bool countries}) {
    final next = set.contains(v) ? (set.toSet()..remove(v)) : (set.toSet()..add(v));
    setState(() {
      _filters = countries ? _filters.copyWith(countries: next) : _filters.copyWith(utensils: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge)),
                    TextButton(
                      onPressed: () => setState(() => _filters = RecipeFilters.empty()),
                      child: const Text('Limpiar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_filters),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _SectionTitle('Tipo de alimentación'),
                _wrap([
                  for (final v in DietType.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.dietTypes.contains(v),
                      onTap: () => _toggleEnum<DietType>(v, _filters.dietTypes),
                    ),
                ]),

                _SectionTitle('Alérgenos'),
                _wrap([
                  for (final v in AllergenFree.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.allergenFree.contains(v),
                      onTap: () => _toggleEnum<AllergenFree>(v, _filters.allergenFree),
                    ),
                ]),

                _SectionTitle('Duración'),
                _wrap([
                  for (final v in DurationRange.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.durationRanges.contains(v),
                      onTap: () => _toggleEnum<DurationRange>(v, _filters.durationRanges),
                    ),
                ]),

                _SectionTitle('Tipo de comida'),
                _wrap([
                  for (final v in MealType.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.mealTypes.contains(v),
                      onTap: () => _toggleEnum<MealType>(v, _filters.mealTypes),
                    ),
                ]),

                _SectionTitle('Objetivo'),
                _wrap([
                  for (final v in RecipeGoal.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.goals.contains(v),
                      onTap: () => _toggleEnum<RecipeGoal>(v, _filters.goals),
                    ),
                ]),

                _SectionTitle('Precio'),
                _wrap([
                  for (final v in PriceTier.values)
                    _FilterPill(
                      label: v.label,
                      selected: _filters.priceTiers.contains(v),
                      onTap: () => _toggleEnum<PriceTier>(v, _filters.priceTiers),
                    ),
                ]),

                _SectionTitle('País'),
                _wrap([
                  for (final c in widget.availableCountries)
                    _FilterPill(
                      label: c,
                      selected: _filters.countries.contains(c),
                      onTap: () => _toggleString(c, _filters.countries, countries: true),
                    ),
                ]),

                _SectionTitle('Utensilios'),
                _wrap([
                  for (final u in widget.availableUtensils)
                    _FilterPill(
                      label: u,
                      selected: _filters.utensils.contains(u),
                      onTap: () => _toggleString(u, _filters.utensils, countries: false),
                    ),
                ]),

                _SectionTitle('Dificultad'),
                _wrap([
                  for (final d in DifficultyLevel.values)
                    _FilterPill(
                      label: d.label,
                      selected: _filters.difficulties.contains(d),
                      onTap: () => _toggleEnum<DifficultyLevel>(d, _filters.difficulties),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrap(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 10, runSpacing: 10, children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? CFColors.primary.withValues(alpha: 0.12) : CFColors.background,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: selected ? CFColors.primary : CFColors.softGray),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: CFColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? CFColors.primary : CFColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
