import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/workout_session_service.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _index = 0;
  bool _isSummary = false;
  bool _saving = false;

  Timer? _timer;
  bool _isRunning = false;
  int? _initialSeconds;
  int? _remainingSeconds;

  Exercise get _current => widget.workout.exercises[_index];

  @override
  void initState() {
    super.initState();
    _setupForCurrentExercise();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setupForCurrentExercise() {
    _timer?.cancel();
    _isRunning = false;

    final seconds = _parseSeconds(_current.repsOrTime);
    _initialSeconds = seconds;
    _remainingSeconds = seconds;
    setState(() {});
  }

  int? _parseSeconds(String repsOrTime) {
    final lower = repsOrTime.toLowerCase();

    final m = RegExp(r'(\d+)').firstMatch(lower);
    if (m == null) return null;
    final n = int.tryParse(m.group(1) ?? '');
    if (n == null) return null;

    if (lower.contains('min')) return n * 60;
    if (RegExp(r'\bs\b').hasMatch(lower) || lower.contains(' s')) return n;

    return null;
  }

  String _format(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _toggleTimer() {
    if (_remainingSeconds == null) return;

    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    _timer?.cancel();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final current = _remainingSeconds ?? 0;
      final next = current - 1;
      if (next <= 0) {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        return;
      }

      setState(() => _remainingSeconds = next);
    });
  }

  void _markCompleted() {
    if (_isSummary) return;

    if (_index >= widget.workout.exercises.length - 1) {
      _timer?.cancel();
      setState(() {
        _isSummary = true;
        _isRunning = false;
      });
      return;
    }

    setState(() => _index += 1);
    _setupForCurrentExercise();
  }

  Future<void> _finishAndSave() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await WorkoutSessionService().completeWorkoutAndApplyBonus(workout: widget.workout);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSummary ? 'Resumen' : 'Sesión'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isSummary ? _buildSummary(context) : _buildSession(context),
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.workout.exercises.length;
    final ex = _current;
    final seconds = _initialSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.workout.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Ejercicio ${_index + 1} de $total',
          style: theme.textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: CFColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: CFColors.softGray),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ex.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CFColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(ex.repsOrTime, style: theme.textTheme.titleMedium),
              if (seconds != null) ...[
                const SizedBox(height: 14),
                Text(
                  _format(_remainingSeconds ?? seconds),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: CFColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        if (seconds != null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleTimer,
                  child: Text(_isRunning ? 'Pausar' : 'Iniciar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _markCompleted,
                  child: Text(_index == total - 1 ? 'Finalizar' : 'Completado'),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _markCompleted,
              child: Text(_index == total - 1 ? 'Finalizar' : 'Completado'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¡Entrenamiento completado!', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Se aplicará un bonus de +${WorkoutSessionService.cfBonus} al CF de hoy.',
          style: theme.textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Text('Ejercicios', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: widget.workout.exercises.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ex = widget.workout.exercises[index];
              return Container(
                decoration: BoxDecoration(
                  color: CFColors.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: CFColors.softGray),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ex.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(ex.repsOrTime, style: theme.textTheme.bodyMedium),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _finishAndSave,
            child: Text(_saving ? 'Guardando…' : 'Finalizar y guardar'),
          ),
        ),
      ],
    );
  }
}
