import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/nutrition_template_model.dart';
import '../progress/progress_section_card.dart';

class NutritionTemplateCard extends StatelessWidget {
  const NutritionTemplateCard({
    super.key,
    required this.template,
    required this.liked,
    required this.myRating,
    required this.onTap,
    required this.onToggleLike,
    required this.onRate,
  });

  final NutritionTemplateModel template;
  final bool liked;
  final int? myRating;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final ValueChanged<int> onRate;

  String get _ratingLabel {
    final v = template.avgRating;
    if (v <= 0) return '0.0';
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (template.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          template.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: CFColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: liked ? 'Quitar like' : 'Dar like',
                  onPressed: onToggleLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? CFColors.primary : CFColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(
                  icon: Icons.star,
                  label: _ratingLabel,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.favorite,
                  label: '${template.totalLikes}',
                ),
                const Spacer(),
                _RatingRow(
                  value: myRating,
                  onRate: onRate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(text: '${template.caloriesTotal.round()} kcal'),
                _Pill(text: 'P ${template.proteinTotal.round()}g'),
                _Pill(text: 'C ${template.carbsTotal.round()}g'),
                _Pill(text: 'G ${template.fatsTotal.round()}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CFColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CFColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

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

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.value, required this.onRate});

  final int? value;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Valorar $i',
            onPressed: () => onRate(i),
            icon: Icon(
              i <= v ? Icons.star : Icons.star_border,
              size: 20,
              color: i <= v ? CFColors.primary : CFColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
