import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/recipe_model.dart';
import '../progress/progress_section_card.dart';
import 'nutrition_text_utils.dart';
import 'recipe_media.dart';

class RecipeCompactCard extends StatelessWidget {
  const RecipeCompactCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.showNutritionValues = true,
  });

  final RecipeModel recipe;
  final VoidCallback onTap;
  final bool showNutritionValues;

  @override
  Widget build(BuildContext context) {
    final primary = context.cfPrimary;
    final title = normalizeNutritionCardText(recipe.name);
    return ProgressSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RecipeMedia(
              imageUrl: recipe.imageUrl,
              width: 46,
              height: 46,
              borderRadius: 14,
              iconSize: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _CompactMetric(
                        icon: Icons.schedule_outlined,
                        label: '${recipe.durationMinutes} min',
                        color: context.cfTextSecondary,
                      ),
                      if (showNutritionValues)
                        _CompactMetric(
                          icon: Icons.local_fire_department_outlined,
                          label: '${recipe.kcalPerServing} kcal',
                          color: context.cfTextSecondary,
                        ),
                      _CompactMetric(
                        icon: Icons.star,
                        label: recipe.ratingAvg.toStringAsFixed(1),
                        color: primary,
                        emphasize: true,
                      ),
                      _CompactMetric(
                        icon: Icons.favorite,
                        label: '${recipe.likes}',
                        color: context.cfTextSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
