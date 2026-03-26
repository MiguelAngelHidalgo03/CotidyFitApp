import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_service.dart';
import '../utils/date_utils.dart';
import '../widgets/training/exercise_guidance_bottom_sheet.dart';
import 'main_navigation.dart';
import 'workout_session_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday;
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }

  String _weekdayLabel(int i) {
    const labels = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return labels[i.clamp(0, 6)];
  }

  Future<void> _assignToDay(BuildContext context) async {
    int selected = DateTime.now().weekday - 1;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.cfSurface,
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    border: Border.all(color: context.cfBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agregar entrenamiento: Selecciona el día',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < 7; i++)
                            ChoiceChip(
                              selected: selected == i,
                              onSelected: (_) => setLocal(() => selected = i),
                              label: Text(_weekdayLabel(i)),
                              selectedColor: context.cfPrimaryTint,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(selected),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar en Mi semana'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    final plans = WorkoutPlanService();
    final weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
    final key = DateUtilsCF.toKey(weekStart);
    final existing = await plans.getPlanForWeekKey(key);
    final next = <int, String>{...?(existing?.assignments)};
    next[picked] = workout.id;

    await plans.upsertPlan(
      (existing ?? WeekPlan(weekStart: weekStart, assignments: const {}))
          .copyWith(weekStart: weekStart, assignments: next),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entrenamiento agregado para ${_weekdayLabel(picked)}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoCard(workout: workout),
              const SizedBox(height: 14),
              Text('Ejercicios', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: workout.exercises.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ex = workout.exercises[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: context.cfSurface,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(18),
                        ),
                        border: Border.all(color: context.cfBorder),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (ex.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        ex.description.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: context.cfTextSecondary,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                ex.repsOrTime,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => showExerciseGuidanceBottomSheet(
                              context,
                              exercise: ex,
                            ),
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Cómo hacerlo'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final completed = await Navigator.of(context)
                            .push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WorkoutSessionScreen(workout: workout),
                              ),
                            );
                        if (!context.mounted || completed != true) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const MainNavigation(initialIndex: 3),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Comenzar entrenamiento'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _assignToDay(context),
                      child: const Text('Agregar: Selecciona día'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: context.cfBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _Chip(label: workout.category)),
          const SizedBox(width: 10),
          _Chip(label: '${workout.durationMinutes} min'),
          const SizedBox(width: 10),
          _Chip(label: workout.level),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.cfTextPrimary,
        ),
      ),
    );
  }
}
