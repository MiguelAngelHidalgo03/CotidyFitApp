import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/workout_session_service.dart';
import '../services/workout_sound_service.dart';

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

  static const _exerciseMotivation = <String>[
    '¡Sigue así!',
    'Buen ritmo',
    'Vas genial',
  ];

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
        // Play configurable end sound (stored in Profile > Configuración).
        // Fire-and-forget to avoid blocking UI.
        // ignore: discarded_futures
        WorkoutSoundService().playSelectedEndSound();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporizador finalizado.')),
        );
        return;
      }

      setState(() => _remainingSeconds = next);
    });
  }

  void _markCompleted() {
    if (_isSummary) return;

    final msg = _exerciseMotivation[_index % _exerciseMotivation.length];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );

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
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: CFColors.primary.withValues(alpha: 0.14)),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, color: CFColors.primary, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ex.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CFColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(ex.repsOrTime, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(
                'Descripción: próximamente.',
                style: theme.textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _VariantChip(text: 'Variante A'),
                  _VariantChip(text: 'Variante B'),
                ],
              ),
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
        Text('Excelente trabajo 💪', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Has completado tu entrenamiento de hoy.\n'
          'Minutos activos: ${widget.workout.durationMinutes} min · Impacto CF: +${WorkoutSessionService.cfBonus}',
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

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: CFColors.primary,
            ),
      ),
    );
  }
}
