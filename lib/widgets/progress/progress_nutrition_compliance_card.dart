import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/progress_week_summary.dart';
import 'progress_section_card.dart';

class ProgressNutritionComplianceCard extends StatelessWidget {
  const ProgressNutritionComplianceCard({super.key, required this.summary});

  final ProgressWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = summary.nutritionCompliancePercent;
    final tagTone = _toneFor(pct, summary.nutritionLabel);

    final (tagBg, tagBorder, tagFg, tagIcon) = switch (tagTone) {
      _Tone.good => (
          Colors.green.withValues(alpha: 0.10),
          Colors.green.withValues(alpha: 0.35),
          Colors.green.shade800,
          Icons.check_circle_outline,
        ),
      _Tone.warn => (
          Colors.amber.withValues(alpha: 0.12),
          Colors.amber.withValues(alpha: 0.45),
          Colors.amber.shade900,
          Icons.info_outline,
        ),
      _Tone.neutral => (
          CFColors.background,
          CFColors.softGray,
          CFColors.textSecondary,
          Icons.insights_outlined,
        ),
    };

    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.restaurant_menu_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nutrición cumplida',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.mealsLogged} / ${summary.mealsTarget} comidas (objetivo)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: Border.all(color: tagBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tagIcon, size: 16, color: tagFg),
                    const SizedBox(width: 6),
                    Text(
                      summary.nutritionLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: tagFg,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary.nutritionMessage, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Proteína',
                  value: '${summary.proteinTotalG} g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniInfo(
                  label: 'Carbohidratos',
                  value: '${summary.carbsTotalG} g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniInfo(
                  label: 'Grasas',
                  value: '${summary.fatTotalG} g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Proteína por comida',
                  value: summary.proteinPerMealG <= 0 ? '—' : '${summary.proteinPerMealG.toStringAsFixed(0)} g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _Tone _toneFor(int pct, String label) {
    if (label == 'Buena consistencia') return _Tone.good;
    if (label == 'Baja proteína') return _Tone.warn;
    if (pct >= 75) return _Tone.good;
    if (pct >= 45) return _Tone.warn;
    return _Tone.neutral;
  }
}

enum _Tone { good, warn, neutral }

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
