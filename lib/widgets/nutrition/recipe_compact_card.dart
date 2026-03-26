import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/recipe_model.dart';
import '../progress/progress_section_card.dart';
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
    return ProgressSectionCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Row(
          children: [
            RecipeMedia(
              imageUrl: recipe.imageUrl,
              width: 54,
              height: 54,
              borderRadius: 16,
              iconSize: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    showNutritionValues
                        ? '${recipe.durationMinutes} min · ${recipe.kcalPerServing} kcal'
                        : '${recipe.durationMinutes} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: primary),
                    const SizedBox(width: 4),
                    Text(
                      recipe.ratingAvg.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('❤ ${recipe.likes}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
