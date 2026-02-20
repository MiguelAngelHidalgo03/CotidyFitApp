import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/weight_entry.dart';
import 'progress_section_card.dart';
import 'progress_sparkline.dart';

class ProgressWeightSummaryCard extends StatelessWidget {
  const ProgressWeightSummaryCard({
    super.key,
    required this.latest,
    required this.weekDiffKg,
    required this.monthDiffKg,
    required this.last30Days,
    required this.onAdd,
  });

  final WeightEntry? latest;
  final double? weekDiffKg;
  final double? monthDiffKg;
  final List<WeightEntry> last30Days;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final w = latest?.weight;
    final weightText = w == null ? '—' : '${w.toStringAsFixed(1)} kg';

    final values = [for (final e in last30Days) e.weight];

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
                child: const Icon(Icons.monitor_weight_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Peso',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peso actual',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weightText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DeltaPill(
                            label: 'Semanal',
                            deltaKg: weekDiffKg,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DeltaPill(
                            label: 'Mensual',
                            deltaKg: monthDiffKg,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Últimos 30 días',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    ProgressSparkline(
                      values: values,
                      height: 56,
                      lineColor: CFColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.label, required this.deltaKg});

  final String label;
  final double? deltaKg;

  @override
  Widget build(BuildContext context) {
    final d = deltaKg;
    final text = d == null ? '—' : '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} kg';

    final isGood = d != null && d.abs() <= 0.4;
    final isWarn = d != null && d.abs() > 1.0;

    final (bg, border, fg) = isWarn
        ? (
            Colors.amber.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.45),
            Colors.amber.shade900,
          )
        : (isGood
            ? (
                Colors.green.withValues(alpha: 0.10),
                Colors.green.withValues(alpha: 0.35),
                Colors.green.shade800,
              )
            : (
                CFColors.background,
                CFColors.softGray,
                CFColors.textSecondary,
              ));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: CFColors.textPrimary,
                  ),
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
          ),
        ],
      ),
    );
  }
}
