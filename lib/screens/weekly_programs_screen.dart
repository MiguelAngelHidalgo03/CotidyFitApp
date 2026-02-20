import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/weekly_program_model.dart';
import '../models/workout_plan.dart';
import '../services/weekly_programs_service.dart';
import '../services/workout_plan_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_section_card.dart';

class WeeklyProgramsScreen extends StatefulWidget {
  const WeeklyProgramsScreen({super.key});

  @override
  State<WeeklyProgramsScreen> createState() => _WeeklyProgramsScreenState();
}

class _WeeklyProgramsScreenState extends State<WeeklyProgramsScreen> {
  final _programs = const WeeklyProgramsService();
  final _plans = WorkoutPlanService();
  final _workouts = const WorkoutService();

  bool _saving = false;

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }

  Future<void> _applyToCurrentWeek(WeeklyProgramModel program) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
      final weekKey = DateUtilsCF.toKey(weekStart);

      final existing = await _plans.getPlanForWeekKey(weekKey);
      final baseAssignments = <int, String>{...?(existing?.assignments)};

      final week0 = program.estructuraDias.isNotEmpty
          ? program.estructuraDias.first
          : List<String?>.filled(7, null);

      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        final workoutId = (dayIndex < week0.length) ? week0[dayIndex] : null;
        if (workoutId == null) continue;
        if (_workouts.getWorkoutById(workoutId) == null) continue;
        baseAssignments[dayIndex] = workoutId;
      }

      final updated = (existing ??
              WeekPlan(
                weekStart: weekStart,
                assignments: const {},
              ))
          .copyWith(weekStart: weekStart, assignments: baseAssignments);

      await _plans.upsertPlan(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan semanal agregado a tu semana actual.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _programs.getPrograms();

    return Scaffold(
      appBar: AppBar(title: const Text('Planes semanales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Elige un plan y cópialo a tu semana actual.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final p in items) ...[
              _WeeklyProgramCard(
                program: p,
                busy: _saving,
                onApply: () => _applyToCurrentWeek(p),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgramCard extends StatelessWidget {
  const _WeeklyProgramCard({
    required this.program,
    required this.onApply,
    required this.busy,
  });

  final WeeklyProgramModel program;
  final VoidCallback onApply;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.calendar_month_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  program.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetaLine(label: 'Objetivo', value: program.objetivo),
          const SizedBox(height: 6),
          _MetaLine(label: 'Nivel', value: program.nivel),
          const SizedBox(height: 6),
          _MetaLine(label: 'Duración', value: '${program.semanas} semanas'),
          const SizedBox(height: 6),
          _MetaLine(label: 'Días/semana', value: '${program.diasPorSemana}'),
          const SizedBox(height: 10),
          Text(
            program.descripcion,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onApply,
              style: FilledButton.styleFrom(backgroundColor: CFColors.primary, foregroundColor: Colors.white),
              child: Text(busy ? 'Agregando…' : 'Agregar a mi plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CFColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
