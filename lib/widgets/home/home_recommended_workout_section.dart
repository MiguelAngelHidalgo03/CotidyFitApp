import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';

class HomeRecommendedWorkoutSection extends StatelessWidget {
  const HomeRecommendedWorkoutSection({
    super.key,
    required this.workout,
    required this.reason,
    required this.onOpen,
  });

  final Workout? workout;
  final String reason;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: context.cfBorder),
        boxShadow: [
          BoxShadow(
            color: context.cfShadow,
            blurRadius: context.cfIsDark ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: workout == null
          ? Text(
              'Recomendación disponible cuando carguen tus entrenamientos.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrenamiento recomendado',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  workout!.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${workout!.durationMinutes} min · ${workout!.level}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.cfTextSecondary,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onOpen,
                    child: const Text('Ver entrenamiento'),
                  ),
                ),
              ],
            ),
    );
  }
}
