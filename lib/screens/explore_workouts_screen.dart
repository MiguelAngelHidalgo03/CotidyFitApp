import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/progress/progress_section_card.dart';
import 'workout_detail_screen.dart';

class ExploreWorkoutsScreen extends StatefulWidget {
  const ExploreWorkoutsScreen({super.key});

  @override
  State<ExploreWorkoutsScreen> createState() => _ExploreWorkoutsScreenState();
}

class _ExploreWorkoutsScreenState extends State<ExploreWorkoutsScreen> {
  final _service = const WorkoutService();

  final Set<WorkoutPlace> _places = {};
  final Set<WorkoutGoal> _goals = {};
  final Set<WorkoutDifficulty> _difficulties = {};
  final Set<WorkoutDurationFilter> _durations = {};

  void _openWorkout(Workout workout) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = WorkoutFilters(
      places: _places,
      goals: _goals,
      difficulties: _difficulties,
      durations: _durations,
    );

    final workouts = _service.getFilteredWorkouts(filters);

    return Scaffold(
      appBar: AppBar(title: const Text('Explorar entrenamientos')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _FilterGroup<WorkoutPlace>(
                      title: 'Lugar',
                      values: WorkoutPlace.values,
                      selected: _places,
                      labelFor: (v) => v.label,
                      iconFor: (v) => v.icon,
                      onToggle: (v) {
                        setState(() {
                          _places.contains(v) ? _places.remove(v) : _places.add(v);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _FilterGroup<WorkoutGoal>(
                      title: 'Objetivo',
                      values: WorkoutGoal.values,
                      selected: _goals,
                      labelFor: (v) => v.label,
                      iconFor: (v) => v.icon,
                      onToggle: (v) {
                        setState(() {
                          _goals.contains(v) ? _goals.remove(v) : _goals.add(v);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _FilterGroup<WorkoutDifficulty>(
                      title: 'Dificultad',
                      values: WorkoutDifficulty.values,
                      selected: _difficulties,
                      labelFor: (v) => v.label,
                      iconFor: (v) => v.icon,
                      onToggle: (v) {
                        setState(() {
                          _difficulties.contains(v)
                              ? _difficulties.remove(v)
                              : _difficulties.add(v);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _FilterGroup<WorkoutDurationFilter>(
                      title: 'Duración',
                      values: WorkoutDurationFilter.values,
                      selected: _durations,
                      labelFor: (v) => v.label,
                      iconFor: (v) => v.icon,
                      onToggle: (v) {
                        setState(() {
                          _durations.contains(v)
                              ? _durations.remove(v)
                              : _durations.add(v);
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Resultados',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '${workouts.length}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (workouts.isEmpty)
                      ProgressSectionCard(
                        child: Text(
                          'No hay rutinas que coincidan con esos filtros.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...workouts.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: InkWell(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(18)),
                                onTap: () => _openWorkout(w),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              w.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${w.durationMinutes} min · ${w.level}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: CFColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _places.clear();
                            _goals.clear();
                            _difficulties.clear();
                            _durations.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Limpiar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterGroup<T> extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.iconFor,
    required this.onToggle,
  });

  final String title;
  final List<T> values;
  final Set<T> selected;
  final String Function(T) labelFor;
  final IconData Function(T) iconFor;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in values)
                FilterChip(
                  selected: selected.contains(v),
                  onSelected: (_) => onToggle(v),
                  avatar: Icon(iconFor(v), size: 18, color: CFColors.primary),
                  label: Text(labelFor(v)),
                  selectedColor: CFColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: CFColors.primary,
                  side: BorderSide(
                    color: selected.contains(v) ? CFColors.primary : CFColors.softGray,
                  ),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected.contains(v) ? CFColors.primary : CFColors.textSecondary,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
