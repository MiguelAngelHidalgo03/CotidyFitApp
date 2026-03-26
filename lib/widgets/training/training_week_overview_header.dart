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
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 280;
              final compact = constraints.maxWidth < 360;
              final plannedMinutes = _Metric(
                icon: Icons.timer_outlined,
                label: 'Minutos planificados',
                value: '${summary.plannedMinutes} min',
                compact: compact,
              );
              final activeDays = _Metric(
                icon: Icons.calendar_today_outlined,
                label: 'Días activos',
                value: '${summary.activeDays}',
                compact: compact,
              );

              if (useColumn) {
                return Column(
                  children: [
                    plannedMinutes,
                    const SizedBox(height: 12),
                    activeDays,
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: plannedMinutes),
                    const SizedBox(width: 12),
                    Expanded(child: activeDays),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.trending_up_outlined,
                size: 18,
                color: context.cfPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    value: summary.weeklyProgress,
                    minHeight: 8,
                    backgroundColor: context.cfBorder,
                    color: context.cfPrimary,
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
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: context.cfPrimary, size: compact ? 18 : 20),
          SizedBox(height: compact ? 10 : 14),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.cfTextSecondary,
                  )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.cfTextSecondary,
                  ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: context.cfTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
