import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/workout_session_service.dart';
import '../services/workout_sound_service.dart';
import '../widgets/training/exercise_guidance_bottom_sheet.dart';

enum _CountdownKind { exercise, rest }

enum _RestKind { betweenSets, betweenExercises }

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int _index = 0;
  int _setIndex = 0;
  bool _isSummary = false;
  bool _saving = false;

  Timer? _timer;
  bool _isRunning = false;
  _CountdownKind? _countdownKind;
  _RestKind? _restKind;
  int? _remainingSeconds;
  int? _selectedVariantIndex;
  String? _statusMessage;

  final Map<int, double> _weightKgByExerciseIndex = {};

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

  void _setupForCurrentExercise({String? statusMessage}) {
    _timer?.cancel();
    _isRunning = false;
    _countdownKind = null;
    _restKind = null;
    _setIndex = 0;

    final seconds =
        _current.durationSeconds ?? _parseSeconds(_current.repsOrTime);
    if (seconds != null) {
      _countdownKind = _CountdownKind.exercise;
    }
    _remainingSeconds = seconds;
    _selectedVariantIndex = null;
    _statusMessage = statusMessage;
    setState(() {});
  }

  String _normalizeMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final raw = url.trim();

    final fileIdMatch = RegExp(
      r'drive\.google\.com/file/d/([^/]+)',
    ).firstMatch(raw);
    if (fileIdMatch != null) {
      final id = fileIdMatch.group(1);
      if (id != null && id.isNotEmpty) {
        return 'https://drive.google.com/uc?export=view&id=$id';
      }
    }

    final openIdMatch = RegExp(r'[?&]id=([^&]+)').firstMatch(raw);
    if (raw.contains('drive.google.com') && openIdMatch != null) {
      final id = openIdMatch.group(1);
      if (id != null && id.isNotEmpty) {
        return 'https://drive.google.com/uc?export=view&id=$id';
      }
    }

    return raw;
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

  bool _shouldAskWeight(Exercise exercise) {
    return exercise.askWeight || exercise.trackWeight;
  }

  bool _shouldTrackWeight(Exercise exercise) {
    return exercise.trackWeight;
  }

  Future<void> _captureWeightIfNeeded(Exercise exercise) async {
    if (!_shouldAskWeight(exercise)) return;

    final weightKg = await _promptWeightKg(exercise: exercise);
    if (weightKg == null) return;

    if (_shouldTrackWeight(exercise)) {
      _weightKgByExerciseIndex[_index] = weightKg;
    }
  }

  void _toggleTimer() {
    if (_countdownKind != _CountdownKind.exercise) return;
    if (_remainingSeconds == null) return;

    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _statusMessage = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final current = _remainingSeconds ?? 0;
      final next = current - 1;
      if (next <= 0) {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
          _statusMessage =
              'Temporizador finalizado. Marca el ejercicio cuando quieras.';
        });
        // Play configurable end sound (stored in Profile > Configuración).
        // Fire-and-forget to avoid blocking UI.
        // ignore: discarded_futures
        WorkoutSoundService().playSelectedEndSound();
        return;
      }

      setState(() => _remainingSeconds = next);
    });
  }

  int _restSecondsFor(Exercise ex) {
    final s = ex.restSeconds;
    if (s != null && s > 0) return s;
    return 60;
  }

  void _startRest({required _RestKind kind, required int seconds}) {
    _timer?.cancel();
    _restKind = kind;
    _countdownKind = _CountdownKind.rest;
    _remainingSeconds = seconds;
    _isRunning = true;
    _statusMessage = null;
    setState(() {});

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

        // ignore: discarded_futures
        WorkoutSoundService().playSelectedEndSound();

        final restKind = _restKind;
        _restKind = null;
        _countdownKind = null;
        _remainingSeconds = null;

        if (restKind == _RestKind.betweenSets) {
          final totalSets = (_current.sets != null && _current.sets! > 0)
              ? _current.sets!
              : 1;
          setState(() {
            _setIndex += 1;
            _statusMessage =
                'Descanso finalizado. Sigue con la serie ${_setIndex + 1} de $totalSets.';
          });
          return;
        }

        if (restKind == _RestKind.betweenExercises) {
          if (_index >= widget.workout.exercises.length - 1) {
            _timer?.cancel();
            setState(() {
              _isSummary = true;
              _isRunning = false;
              _statusMessage = null;
            });
            return;
          }
          _index += 1;
          _setupForCurrentExercise(
            statusMessage:
                'Descanso finalizado. Siguiente ejercicio: ${widget.workout.exercises[_index].name}.',
          );
        }
        return;
      }

      setState(() => _remainingSeconds = next);
    });
  }

  Future<double?> _promptWeightKg({required Exercise exercise}) async {
    final ctrl = TextEditingController();
    double? parsed;

    final result = await showDialog<double?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave = parsed != null && parsed! > 0;
            return AlertDialog(
              title: Text('Peso usado (${exercise.name})'),
              content: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej. 20',
                  suffixText: 'kg',
                ),
                onChanged: (v) {
                  final cleaned = v.trim().replaceAll(',', '.');
                  setDialogState(() => parsed = double.tryParse(cleaned));
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Omitir'),
                ),
                FilledButton(
                  onPressed: canSave
                      ? () => Navigator.of(context).pop(parsed)
                      : null,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _completeRepBasedExercise() async {
    if (_isSummary) return;
    if (_countdownKind == _CountdownKind.rest) return;

    final ex = _current;
    final totalExercises = widget.workout.exercises.length;

    final sets = (ex.sets != null && ex.sets! > 0) ? ex.sets! : 1;
    final restSeconds = _restSecondsFor(ex);

    if (_setIndex < sets - 1) {
      _startRest(kind: _RestKind.betweenSets, seconds: restSeconds);
      return;
    }

    await _captureWeightIfNeeded(ex);
    if (!mounted) return;

    final msg = _exerciseMotivation[_index % _exerciseMotivation.length];
    if (mounted) setState(() => _statusMessage = msg);

    if (_index >= totalExercises - 1) {
      _timer?.cancel();
      setState(() {
        _isSummary = true;
        _isRunning = false;
      });
      return;
    }

    _startRest(kind: _RestKind.betweenExercises, seconds: restSeconds);
  }

  Future<void> _markCompleted() async {
    if (_isSummary) return;

    if (_countdownKind == _CountdownKind.rest) return;

    final ex = _current;
    await _captureWeightIfNeeded(ex);
    if (!mounted) return;

    final msg = _exerciseMotivation[_index % _exerciseMotivation.length];
    setState(() => _statusMessage = msg);

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
      final exerciseLogs = <Map<String, Object?>>[];
      for (var i = 0; i < widget.workout.exercises.length; i++) {
        final w = _weightKgByExerciseIndex[i];
        if (w == null) continue;
        final ex = widget.workout.exercises[i];
        exerciseLogs.add({
          'order': i,
          if (ex.id != null && ex.id!.trim().isNotEmpty) 'exerciseId': ex.id,
          'name': ex.name,
          'sets': ex.sets,
          'reps': ex.reps,
          'weightKg': w,
          'muscleGroup': ex.muscleGroup.firestoreKey,
        });
      }

      await WorkoutSessionService().completeWorkoutAndApplyBonus(
        workout: widget.workout,
        completionData: {
          'workoutId': widget.workout.id,
          'durationMinutes': widget.workout.durationMinutes,
          if (exerciseLogs.isNotEmpty) 'exerciseLogs': exerciseLogs,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSummary ? 'Resumen' : 'Sesión')),
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
    final primary = context.cfPrimary;
    final total = widget.workout.exercises.length;
    final ex = _current;
    final seconds = ex.durationSeconds ?? _parseSeconds(ex.repsOrTime);
    final hasVariants = ex.variants.isNotEmpty;
    final isResting = _countdownKind == _CountdownKind.rest;
    final sets = (ex.sets != null && ex.sets! > 0) ? ex.sets! : 1;
    final reps = ex.reps;
    final isRepBased = seconds == null && reps != null;
    final selectedVariant =
        (_selectedVariantIndex != null &&
            _selectedVariantIndex! >= 0 &&
            _selectedVariantIndex! < ex.variants.length)
        ? ex.variants[_selectedVariantIndex!]
        : null;

    final imageUrl = _normalizeMediaUrl(
      selectedVariant?.imageUrl ?? ex.imageUrl,
    );
    final videoUrl = _normalizeMediaUrl(
      selectedVariant?.videoUrl ?? ex.videoUrl,
    );
    final description = (() {
      final d = (selectedVariant?.description ?? ex.description).trim();
      if (d.isEmpty) return 'Sin descripción disponible.';
      return d;
    })();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.workout.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Ejercicio ${_index + 1} de $total',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.cfTextSecondary,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.cfSurface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: context.cfBorder),
            boxShadow: [
              BoxShadow(
                color: context.cfShadow,
                blurRadius: context.cfIsDark ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.cfPrimaryTint,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: context.cfPrimaryTintStrong),
                ),
                child: imageUrl.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: primary,
                          size: 40,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(16),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: primary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                ex.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cfTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (isRepBased ? '$sets x $reps' : ex.repsOrTime),
                style: theme.textTheme.titleMedium,
              ),
              if (isRepBased && !isResting) ...[
                const SizedBox(height: 6),
                Text(
                  'Serie ${_setIndex + 1} de $sets',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.cfTextSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.cfTextSecondary,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showExerciseGuidanceBottomSheet(
                  context,
                  exercise: ex,
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Cómo hacerlo'),
              ),
              if (videoUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(videoUrl);
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Ver vídeo'),
                ),
              ],
              const SizedBox(height: 10),
              if (hasVariants)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < ex.variants.length; i++)
                      _VariantChip(
                        text: ex.variants[i].name,
                        selected: _selectedVariantIndex == i,
                        onTap: () => setState(() => _selectedVariantIndex = i),
                      ),
                  ],
                ),
              if (_statusMessage != null &&
                  _statusMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _SessionStatusBanner(message: _statusMessage!),
              ],
              if (isResting) ...[
                const SizedBox(height: 14),
                Text(
                  'Descanso',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cfTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _format(_remainingSeconds ?? 0),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _restKind == _RestKind.betweenSets
                      ? 'Siguiente serie: ${(_setIndex + 2).clamp(1, sets)} de $sets'
                      : (_index < total - 1
                            ? 'Siguiente ejercicio: ${widget.workout.exercises[_index + 1].name}'
                            : 'Siguiente ejercicio'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.cfTextSecondary,
                  ),
                ),
              ] else if (seconds != null) ...[
                const SizedBox(height: 14),
                Text(
                  _format(_remainingSeconds ?? seconds),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        if (isResting) ...[
          const SizedBox(height: 6),
        ] else if (seconds != null) ...[
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
        ] else if (isRepBased) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _completeRepBasedExercise,
              child: Text(
                (_setIndex < sets - 1)
                    ? 'Serie completada'
                    : (_index == total - 1
                          ? 'Finalizar'
                          : 'Ejercicio completado'),
              ),
            ),
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.cfTextSecondary,
            height: 1.4,
          ),
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
              final weight = _weightKgByExerciseIndex[index];
              return Container(
                decoration: BoxDecoration(
                  color: context.cfSurface,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: context.cfBorder),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                    Text(
                      '${ex.repsOrTime}${weight == null ? '' : ' · ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg'}',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.end,
                    ),
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
  const _VariantChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.cfPrimaryTintStrong : context.cfPrimaryTint,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: selected ? context.cfPrimary : context.cfPrimaryTintStrong,
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.cfPrimary,
          ),
        ),
      ),
    );
  }
}

class _SessionStatusBanner extends StatelessWidget {
  const _SessionStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cfPrimaryTint,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, color: context.cfPrimary, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.cfTextPrimary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
