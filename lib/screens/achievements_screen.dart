import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/daily_data_model.dart';
import '../services/daily_data_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({
    super.key,
    required this.streakCount,
    required this.bestCf,
    required this.workoutCompleted,
    required this.mealsLoggedCount,
    required this.todayData,
  });

  final int streakCount;
  final int bestCf;
  final bool workoutCompleted;
  final int mealsLoggedCount;
  final DailyDataModel todayData;

  @override
  Widget build(BuildContext context) {
    final achievements = _buildAchievements();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              for (final a in achievements)
                _AchievementTile(
                  title: a.title,
                  subtitle: a.subtitle,
                  icon: a.icon,
                  unlocked: a.unlocked,
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<_Achievement> _buildAchievements() {
    final stepsOk = todayData.steps >= DailyDataService.stepsTarget;
    final waterOk = todayData.waterLiters >= DailyDataService.waterLitersTarget;
    final activeOk = todayData.activeMinutes >= DailyDataService.activeMinutesTarget;
    final mealsOk = mealsLoggedCount >= DailyDataService.mealsTarget;

    final feelingsOk = (todayData.energy != null) ||
        (todayData.mood != null) ||
        (todayData.stress != null) ||
        (todayData.sleep != null);

    return [
      _Achievement(
        title: 'Primer día',
        subtitle: 'Registra tu primer día',
        icon: Icons.flag_outlined,
        unlocked: bestCf > 0 || streakCount > 0,
      ),
      _Achievement(
        title: 'Racha 3',
        subtitle: '3 días seguidos',
        icon: Icons.local_fire_department_outlined,
        unlocked: streakCount >= 3,
      ),
      _Achievement(
        title: 'Racha 7',
        subtitle: '1 semana',
        icon: Icons.whatshot_outlined,
        unlocked: streakCount >= 7,
      ),
      _Achievement(
        title: 'Entreno hecho',
        subtitle: 'Completa un entrenamiento',
        icon: Icons.fitness_center_outlined,
        unlocked: workoutCompleted,
      ),
      _Achievement(
        title: 'Paso a paso',
        subtitle: '${DailyDataService.stepsTarget} pasos',
        icon: Icons.directions_walk_outlined,
        unlocked: stepsOk,
      ),
      _Achievement(
        title: 'Hidratación',
        subtitle: '${DailyDataService.waterLitersTarget.toStringAsFixed(1)} L',
        icon: Icons.water_drop_outlined,
        unlocked: waterOk,
      ),
      _Achievement(
        title: 'Actívate',
        subtitle: '${DailyDataService.activeMinutesTarget} min activos',
        icon: Icons.timer_outlined,
        unlocked: activeOk,
      ),
      _Achievement(
        title: 'Comidas OK',
        subtitle: '${DailyDataService.mealsTarget} comidas',
        icon: Icons.restaurant_outlined,
        unlocked: mealsOk,
      ),
      _Achievement(
        title: 'Check-in',
        subtitle: 'Registra cómo te sientes',
        icon: Icons.sentiment_satisfied_alt_outlined,
        unlocked: feelingsOk,
      ),
    ];
  }
}

class _Achievement {
  const _Achievement({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final fg = unlocked ? CFColors.primary : CFColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? CFColors.primary.withValues(alpha: 0.10)
                  : CFColors.softGray.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: Icon(icon, color: fg),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CFColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
