import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'cf_ring_indicator.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.streakCount,
    required this.cfIndex,
  });

  final int streakCount;
  final int cfIndex;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _greetingForHour(now.hour);
    final dateLabel = _formatSpanishDate(now);

    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(dateLabel, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                _StreakPill(streakCount: streakCount),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Índice CF',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              CfRingIndicator(value: cfIndex, size: 72),
            ],
          ),
        ],
      ),
    );
  }

  String _greetingForHour(int hour) {
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _formatSpanishDate(DateTime dt) {
    const months = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    const weekdays = <String>[
      'lun',
      'mar',
      'mié',
      'jue',
      'vie',
      'sáb',
      'dom',
    ];

    final wd = weekdays[(dt.weekday - 1).clamp(0, 6)];
    final m = months[(dt.month - 1).clamp(0, 11)];
    return '${wd[0].toUpperCase()}${wd.substring(1)}, ${dt.day} $m';
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streakCount});

  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.primary.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: CFColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Racha: $streakCount',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CFColors.textPrimary,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            'días',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
