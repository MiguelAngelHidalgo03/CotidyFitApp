import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/training_program_detail_model.dart';
import '../models/workout_plan.dart';
import '../services/training_firestore_service.dart';
import '../services/workout_plan_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_section_card.dart';

class WeeklyProgramDetailScreen extends StatefulWidget {
  const WeeklyProgramDetailScreen({super.key, required this.programId});

  final String programId;

  @override
  State<WeeklyProgramDetailScreen> createState() => _WeeklyProgramDetailScreenState();
}

class _WeeklyProgramDetailScreenState extends State<WeeklyProgramDetailScreen> {
  final _service = TrainingFirestoreService();
  final _plans = WorkoutPlanService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  WeeklyProgramDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.getWeeklyProgramDetail(programId: widget.programId);
      if (!mounted) return;
      setState(() => _detail = detail);
      if (detail == null) {
        setState(() => _error = 'Programa no encontrado.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error al cargar el programa: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _replaceExercise({
    required String dayId,
    required ProgramDayExerciseModel exercise,
  }) async {
    final options = await _service.getExerciseOptions();
    if (!mounted) return;
    final selected = await showModalBottomSheet<MapEntry<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var q = '';
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final filtered = options.where((e) {
                  final query = q.trim().toLowerCase();
                  if (query.isEmpty) return true;
                  return e.value.toLowerCase().contains(query);
                }).toList();

                return ProgressSectionCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cambiar ejercicio',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      TextField(
                        onChanged: (v) => setSheetState(() => q = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar ejercicio…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(item.value),
                              subtitle: Text(item.key),
                              onTap: () => Navigator.of(context).pop(item),
                            );
                          },
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

    if (selected == null) return;
    setState(() => _saving = true);
    try {
      await _service.replaceProgramExercise(
        programId: widget.programId,
        dayId: dayId,
        dayExerciseDocId: exercise.id,
        newExerciseId: selected.key,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ejercicio reemplazado en tu programa activo.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar ejercicio: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday;
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }

  Future<void> _addToMyPlan() async {
    setState(() => _saving = true);
    try {
      final weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
      final weekKey = DateUtilsCF.toKey(weekStart);

      final existing = await _plans.getPlanForWeekKey(weekKey);
      final baseAssignments = <int, String>{...?(existing?.assignments)};

      final generatedAssignments = await _service.buildUserWeekAssignmentsFromProgram(
        programId: widget.programId,
      );
      if (generatedAssignments.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo agregar. Verifica sesión y días del programa.'),
          ),
        );
        return;
      }
      for (final entry in generatedAssignments.entries) {
        baseAssignments[entry.key] = entry.value;
      }

      await _plans.upsertPlan(
        (existing ??
                WeekPlan(
                  weekStart: weekStart,
                  assignments: const {},
                ))
            .copyWith(weekStart: weekStart, assignments: baseAssignments),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programa agregado a Mi semana.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo agregar a Mi semana: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator())));
    }

    final detail = _detail;
    if (_error != null || detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Programa semanal')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'No disponible', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(detail.program.nombre)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProgressSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.program.nombre,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(detail.program.descripcion),
                  const SizedBox(height: 8),
                  Text('Duración: ${detail.program.semanas} semanas'),
                  if (detail.isUserSpecificCopy) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Programa activo personalizado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.primary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _addToMyPlan,
                      icon: const Icon(Icons.add_task_outlined),
                      label: Text(_saving ? 'Guardando…' : 'Agregar a mi plan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final day in detail.days) ...[
              ProgressSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.dayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (day.focus.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Enfoque: ${day.focus}'),
                    ],
                    const SizedBox(height: 8),
                    for (final ex in day.exercises) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CFColors.surface,
                          borderRadius: const BorderRadius.all(Radius.circular(14)),
                          border: Border.all(color: CFColors.softGray),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.exerciseName,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text('Sets: ${ex.sets} · Reps: ${ex.reps} · Descanso: ${ex.restSeconds}s'),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _replaceExercise(dayId: day.id, exercise: ex),
                              child: const Text('Cambiar ejercicio'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
