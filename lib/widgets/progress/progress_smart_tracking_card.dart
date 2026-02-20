import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/progress_week_summary.dart';
import 'progress_section_card.dart';

class ProgressSmartTrackingCard extends StatelessWidget {
  const ProgressSmartTrackingCard({super.key, required this.summary});

  final ProgressWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final energy = summary.energyAverage == null
        ? '—'
        : summary.energyAverage!.toStringAsFixed(1);

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
                child: const Icon(Icons.auto_graph_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Seguimiento inteligente',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChipMetric(
                icon: Icons.event_available_outlined,
                label: '${summary.activeDays}/7 días activos',
              ),
              _ChipMetric(
                icon: Icons.timer_outlined,
                label: '${summary.trainedMinutes} min entrenados',
              ),
              _ChipMetric(
                icon: Icons.water_drop_outlined,
                label: '${summary.hydrationAveragePercent}% hidratación',
              ),
              _ChipMetric(
                icon: Icons.bolt_outlined,
                label: 'Energía $energy',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipMetric extends StatelessWidget {
  const _ChipMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: CFColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
