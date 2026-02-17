import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/workout_history_service.dart';
import '../services/workout_plan_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_section_card.dart';

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  final _workouts = const WorkoutService();
  final _plans = WorkoutPlanService();
  final _history = WorkoutHistoryService();

  late DateTime _weekStart;
  WeekPlan? _plan;
  Map<String, String> _completedByDate = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plan = await _plans.getPlanForWeekKey(DateUtilsCF.toKey(_weekStart));
    final completed = await _history.getCompletedWorkoutsByDate();
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _completedByDate = completed;
      _loading = false;
    });
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _load();
  }

  WeekPlan _ensurePlan() {
    return _plan ?? WeekPlan(weekStart: _weekStart, assignments: const {});
  }

  Future<void> _assign(int dayIndex, Workout workout) async {
    final plan = _ensurePlan();
    final next = Map<int, String>.from(plan.assignments);
    next[dayIndex] = workout.id;

    final updated = plan.copyWith(weekStart: _weekStart, assignments: next);
    await _plans.upsertPlan(updated);
    if (!mounted) return;
    setState(() => _plan = updated);
  }

  Future<void> _clearAssignment(int dayIndex) async {
    final plan = _ensurePlan();
    if (!plan.assignments.containsKey(dayIndex)) return;

    final next = Map<int, String>.from(plan.assignments);
    next.remove(dayIndex);

    final updated = plan.copyWith(weekStart: _weekStart, assignments: next);
    await _plans.upsertPlan(updated);
    if (!mounted) return;
    setState(() => _plan = updated);
  }

  Workout? _byId(String? id) {
    if (id == null) return null;
    for (final w in _workouts.getAllWorkouts()) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _ensurePlan();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Plan')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _WeekHeader(
                      weekStart: _weekStart,
                      onPrev: _prevWeek,
                      onNext: _nextWeek,
                    ),
                    const SizedBox(height: 12),
                    Text('Semana', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    for (var i = 0; i < 7; i++) ...[
                      _DayPlanRow(
                        dayIndex: i,
                        date: _weekStart.add(Duration(days: i)),
                        workout: _byId(plan.assignments[i]),
                        onAssign: (w) => _assign(i, w),
                        onClear: () => _clearAssignment(i),
                        allWorkouts: _workouts.getAllWorkouts(),
                      ),
                      if (i != 6) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 18),
                    Text('Arrastra y suelta', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _workouts.getAllWorkouts().length,
                          separatorBuilder: (_, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final w = _workouts.getAllWorkouts()[index];
                            return _DraggableWorkoutPill(workout: w);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Historial', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    _HistoryCard(completedByDate: _completedByDate),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.weekStart, required this.onPrev, required this.onNext});

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    final label = '${weekStart.day.toString().padLeft(2, '0')}/${weekStart.month.toString().padLeft(2, '0')}'
        ' — '
        '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Semana anterior',
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Semana siguiente',
        ),
      ],
    );
  }
}

class _DayPlanRow extends StatelessWidget {
  const _DayPlanRow({
    required this.dayIndex,
    required this.date,
    required this.workout,
    required this.onAssign,
    required this.onClear,
    required this.allWorkouts,
  });

  final int dayIndex;
  final DateTime date;
  final Workout? workout;
  final ValueChanged<Workout> onAssign;
  final VoidCallback onClear;
  final List<Workout> allWorkouts;

  @override
  Widget build(BuildContext context) {
    final label = _weekdayLabel(dayIndex);

    return DragTarget<Workout>(
      onAcceptWithDetails: (details) => onAssign(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;

        return ProgressSectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isActive ? CFColors.primary : CFColors.background).withValues(alpha: isActive ? 0.10 : 1.0),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: isActive ? CFColors.primary : CFColors.softGray),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isActive ? CFColors.primary : CFColors.textPrimary,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    if (workout == null)
                      Text(
                        isActive ? 'Suelta aquí para asignar' : 'Sin entrenamiento',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                      )
                    else
                      Draggable<Workout>(
                        data: workout!,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _WorkoutPill(workout: workout!, elevated: true),
                        ),
                        childWhenDragging: Text(
                          'Moviendo…',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        child: _WorkoutPill(workout: workout!),
                      ),
                  ],
                ),
              ),
              if (workout == null)
                IconButton(
                  onPressed: () async {
                    final picked = await showModalBottomSheet<Workout>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) {
                        return SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ProgressSectionCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Asignar entrenamiento',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 340,
                                    child: ListView.separated(
                                      itemCount: allWorkouts.length,
                                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final w = allWorkouts[index];
                                        return Card(
                                          child: ListTile(
                                            title: Text(w.name),
                                            subtitle: Text('${w.durationMinutes} min · ${w.level}'),
                                            trailing: const Icon(Icons.add, color: CFColors.primary),
                                            onTap: () => Navigator.of(context).pop(w),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    if (picked != null) onAssign(picked);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: CFColors.primary,
                  tooltip: 'Asignar',
                )
              else
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                  color: CFColors.textSecondary,
                  tooltip: 'Quitar',
                ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayLabel(int i) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[i.clamp(0, 6)];
  }
}

class _DraggableWorkoutPill extends StatelessWidget {
  const _DraggableWorkoutPill({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return Draggable<Workout>(
      data: workout,
      feedback: Material(
        color: Colors.transparent,
        child: _WorkoutPill(workout: workout, elevated: true),
      ),
      child: _WorkoutPill(workout: workout),
    );
  }
}

class _WorkoutPill extends StatelessWidget {
  const _WorkoutPill({required this.workout, this.elevated = false});

  final Workout workout;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.durationMinutes} min · ${workout.level}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.completedByDate});

  final Map<String, String> completedByDate;

  @override
  Widget build(BuildContext context) {
    final entries = completedByDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final recent = entries.take(7).toList();

    if (recent.isEmpty) {
      return ProgressSectionCard(
        child: Text(
          'Aún no hay entrenamientos completados.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            _HistoryRow(dateKey: recent[i].key, workoutName: recent[i].value),
            if (i != recent.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.dateKey, required this.workoutName});

  final String dateKey;
  final String workoutName;

  @override
  Widget build(BuildContext context) {
    final d = DateUtilsCF.fromKey(dateKey);
    final label = d == null
        ? dateKey
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: CFColors.primary.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: const Icon(Icons.fitness_center_outlined, color: CFColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text(
                workoutName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
