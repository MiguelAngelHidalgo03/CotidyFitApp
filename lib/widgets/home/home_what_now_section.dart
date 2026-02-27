import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';

class HomeWhatNowSection extends StatelessWidget {
  const HomeWhatNowSection({
    super.key,
    required this.recommendedWorkout,
    required this.recommendedReason,
    required this.onStartTraining,
    required this.onGoNutrition,
    required this.onAddMeditation,
    required this.onSoftStretch,
    required this.onGuidedBreath,
    required this.dailyMissionProgress,
    required this.weeklyMissionProgress,
    required this.dailyMissionItems,
    required this.weeklyMissionItems,
  });

  final Workout? recommendedWorkout;
  final String recommendedReason;
  final VoidCallback onStartTraining;
  final VoidCallback onGoNutrition;
  final Future<void> Function() onAddMeditation;
  final VoidCallback onSoftStretch;
  final VoidCallback onGuidedBreath;
  final double dailyMissionProgress;
  final double weeklyMissionProgress;
  final List<String> dailyMissionItems;
  final List<String> weeklyMissionItems;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final mealHint = hour < 12
        ? 'Te recomendamos un desayuno alto en proteína.'
        : (hour < 18
            ? 'Son las ${TimeOfDay.now().format(context)}. Te recomendamos una comida alta en proteína.'
            : 'Te recomendamos una cena ligera alta en proteína.');

    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué quieres hacer ahora?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _NowCard(
            emoji: '🏋️',
            title: 'Entrenar',
            subtitle: recommendedWorkout == null
                ? 'Recomendación personalizada del día'
                : 'Hoy te recomiendo: ${recommendedWorkout!.name}',
            description: recommendedWorkout == null
                ? 'Cargando recomendación...'
                : '${recommendedWorkout!.durationMinutes} min · $recommendedReason',
            primaryLabel: 'Empezar ahora',
            onPrimary: onStartTraining,
          ),
          const SizedBox(height: 10),
          _NowCard(
            emoji: '🥗',
            title: 'Comer mejor',
            subtitle: 'Plantilla recomendada + receta por hora',
            description: mealHint,
            primaryLabel: 'Planificar mi día',
            onPrimary: onGoNutrition,
          ),
          const SizedBox(height: 10),
          _NowCard(
            emoji: '🧠',
            title: 'Cuidar mente',
            subtitle: 'Meditación 5 min · Estiramientos · Respiración guiada',
            description: 'Muy útil para mantener constancia y energía mental.',
            extraActions: [
              _MiniAction(label: 'Meditación 5 min', onTap: () async => onAddMeditation()),
              _MiniAction(label: 'Estiramientos suaves', onTap: onSoftStretch),
              _MiniAction(label: 'Respiración guiada', onTap: onGuidedBreath),
            ],
          ),
          const SizedBox(height: 10),
          _MissionCard(
            emoji: '🔥',
            title: 'Misión del día',
            progress: dailyMissionProgress,
            items: dailyMissionItems,
          ),
          const SizedBox(height: 10),
          _MissionCard(
            emoji: '🎯',
            title: 'Misión de la semana',
            progress: weeklyMissionProgress,
            items: weeklyMissionItems,
          ),
        ],
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    this.primaryLabel,
    this.onPrimary,
    this.extraActions = const [],
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final List<_MiniAction> extraActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CFColors.softGray),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  $title', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary)),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
          ],
          if (extraActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in extraActions)
                  FilledButton.tonal(onPressed: action.onTap, child: Text(action.label)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.emoji,
    required this.title,
    required this.progress,
    required this.items,
  });

  final String emoji;
  final String title;
  final double progress;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0, 1) * 100).round();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CFColors.softGray),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  $title', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: CFColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text('$pct%', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MiniAction {
  const _MiniAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}
