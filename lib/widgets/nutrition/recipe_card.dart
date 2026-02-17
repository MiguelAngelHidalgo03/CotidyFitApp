import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/recipe_model.dart';
import '../progress/progress_section_card.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.trailing,
  });

  final RecipeModel recipe;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Row(
          children: [
            Hero(
              tag: 'recipe_${recipe.id}',
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: CFColors.softGray),
                ),
                child: const Icon(Icons.restaurant_menu, color: CFColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(text: recipe.country, icon: Icons.public),
                      _Chip(text: '${recipe.durationMinutes} min', icon: Icons.schedule),
                      _Chip(text: '${recipe.kcalPerServing} kcal', icon: Icons.local_fire_department_outlined),
                      _Chip(text: recipe.difficulty.label, icon: Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: CFColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        recipe.ratingAvg.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.favorite, size: 16, color: CFColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.likes}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CFColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
