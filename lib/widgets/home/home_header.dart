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
    final primary = context.cfPrimary;
    final now = DateTime.now();
    final greeting = _greetingForHour(now.hour);
    final dateLabel = _formatSpanishDate(now);
    final streakProgress = (streakCount / 7).clamp(0, 1).toDouble();
    final isLateNight = now.hour < 5;

    return Container(
      decoration: BoxDecoration(
        color: context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: context.cfBorder),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (isLateNight) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Aún estás a tiempo de sumar hoy.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.cfTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _StreakPill(streakCount: streakCount),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    value: streakProgress,
                    minHeight: 8,
                    backgroundColor: context.cfBorder,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: context.cfMutedSurface,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: context.cfBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Índice CF',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.cfTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                CfRingIndicator(value: cfIndex, size: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 20) return 'Buenas tardes';
    if (hour >= 20 || hour < 5) return 'Buenas noches';
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

    const weekdays = <String>['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

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
    final primary = context.cfPrimary;
    return Container(
      decoration: BoxDecoration(
        color: context.cfPrimaryTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Racha: $streakCount',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cfTextPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text('días', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
