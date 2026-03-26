import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/achievements_service.dart';
import 'progress_section_card.dart';

class ProgressAchievementsCard extends StatelessWidget {
  const ProgressAchievementsCard({
    super.key,
    required this.items,
    this.emptyMessage,
  });

  final List<AchievementViewItem> items;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logros',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyMessage ?? 'No hay logros configurados todavía.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _AchievementRow(item: items[i]),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.item});

  final AchievementViewItem item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.user.unlocked;
    final fg = unlocked ? CFColors.primary : CFColors.textSecondary;

    return Opacity(
      opacity: unlocked ? 1.0 : 0.72,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: CFColors.softGray),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFromName(item.catalog.icon), color: fg, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.catalog.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(
                  unlocked ? Icons.lock_open : Icons.lock_outline,
                  color: fg,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.catalog.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              child: LinearProgressIndicator(
                value: item.progressRatio,
                minHeight: 7,
                backgroundColor: CFColors.softGray,
                valueColor: AlwaysStoppedAnimation<Color>(
                  CFColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.user.progress}/${item.catalog.conditionValue}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CFColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'fitness_center_outlined':
        return Icons.fitness_center_outlined;
      case 'local_fire_department_outlined':
        return Icons.local_fire_department_outlined;
      case 'water_drop_outlined':
        return Icons.water_drop_outlined;
      case 'self_improvement_outlined':
        return Icons.self_improvement_outlined;
      case 'military_tech_outlined':
        return Icons.military_tech_outlined;
      case 'event_available_outlined':
        return Icons.event_available_outlined;
      case 'directions_walk_outlined':
        return Icons.directions_walk_outlined;
      case 'timer_outlined':
        return Icons.timer_outlined;
      case 'restaurant_outlined':
        return Icons.restaurant_outlined;
      case 'emoji_emotions_outlined':
        return Icons.emoji_emotions_outlined;
      case 'auto_graph_outlined':
        return Icons.auto_graph_outlined;
      case 'monitor_weight_outlined':
        return Icons.monitor_weight_outlined;
      default:
        return Icons.emoji_events_outlined;
    }
  }
}
