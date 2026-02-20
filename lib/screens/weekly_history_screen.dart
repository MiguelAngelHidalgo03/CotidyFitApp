import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/workout_history_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_section_card.dart';

class WeeklyHistoryScreen extends StatefulWidget {
  const WeeklyHistoryScreen({super.key});

  @override
  State<WeeklyHistoryScreen> createState() => _WeeklyHistoryScreenState();
}

class _WeeklyHistoryScreenState extends State<WeeklyHistoryScreen> {
  final _history = WorkoutHistoryService();

  Map<String, String> _completedByDate = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final completed = await _history.getCompletedWorkoutsByDate();
    if (!mounted) return;
    setState(() {
      _completedByDate = completed;
      _loading = false;
    });
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}'
        ' — '
        '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial semanal')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _HistoryCard(
                      completedByDate: _completedByDate,
                      weekLabel: _weekLabel,
                      mondayOf: _mondayOf,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tip: completar un entrenamiento te da +20 CF.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.completedByDate,
    required this.weekLabel,
    required this.mondayOf,
  });

  final Map<String, String> completedByDate;
  final String Function(DateTime start) weekLabel;
  final DateTime Function(DateTime d) mondayOf;

  @override
  Widget build(BuildContext context) {
    final items = <DateTime, List<MapEntry<String, String>>>{};
    for (final e in completedByDate.entries) {
      final d = DateUtilsCF.fromKey(e.key);
      if (d == null) continue;
      final day = DateUtilsCF.dateOnly(d);
      final weekStart = mondayOf(day);
      (items[weekStart] ??= []).add(e);
    }

    final weekStarts = items.keys.toList()..sort((a, b) => b.compareTo(a));
    final currentWeek = mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
    final previousWeeks = weekStarts
        .where((w) => w.isBefore(currentWeek))
        .toList();

    if (previousWeeks.isEmpty) {
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
          for (var i = 0; i < previousWeeks.length; i++) ...[
            _WeekBlock(
              label: weekLabel(previousWeeks[i]),
              entries: (items[previousWeeks[i]] ?? [])
                ..sort((a, b) => b.key.compareTo(a.key)),
            ),
            if (i != previousWeeks.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _WeekBlock extends StatelessWidget {
  const _WeekBlock({required this.label, required this.entries});

  final String label;
  final List<MapEntry<String, String>> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < entries.length; i++) ...[
          _HistoryRow(dateKey: entries[i].key, workoutName: entries[i].value),
          if (i != entries.length - 1) const SizedBox(height: 10),
        ],
      ],
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
          child: const Icon(
            Icons.fitness_center_outlined,
            color: CFColors.primary,
          ),
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
