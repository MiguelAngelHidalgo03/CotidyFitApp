import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/training_week_summary.dart';
import '../progress/progress_section_card.dart';

class TrainingWeekOverviewHeader extends StatelessWidget {
  const TrainingWeekOverviewHeader({super.key, required this.summary});

  final TrainingWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final title =
        'Esta semana tienes ${summary.assignedWorkouts} entrenamientos asignados';

    return ProgressSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.timer_outlined,
                  label: 'Minutos planificados',
                  value: '${summary.plannedMinutes} min',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  icon: Icons.calendar_today_outlined,
                  label: 'Días activos',
                  value: '${summary.activeDays}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.trending_up_outlined,
                size: 18,
                color: CFColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    value: summary.weeklyProgress,
                    minHeight: 8,
                    backgroundColor: CFColors.softGray,
                    color: CFColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(summary.weeklyProgress * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        children: [
          Icon(icon, color: CFColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
