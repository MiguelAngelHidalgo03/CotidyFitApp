import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  int? _selectedVariantIndex;

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
    _selectedVariantIndex = null;
    setState(() {});
  }

  String _normalizeMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final raw = url.trim();

    final fileIdMatch = RegExp(r'drive\.google\.com/file/d/([^/]+)').firstMatch(raw);
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
    final hasVariants = ex.variants.isNotEmpty;
    final selectedVariant = (_selectedVariantIndex != null &&
            _selectedVariantIndex! >= 0 &&
            _selectedVariantIndex! < ex.variants.length)
        ? ex.variants[_selectedVariantIndex!]
        : null;

    final imageUrl = _normalizeMediaUrl(selectedVariant?.imageUrl ?? ex.imageUrl);
    final videoUrl = _normalizeMediaUrl(selectedVariant?.videoUrl ?? ex.videoUrl);
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
                child: imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_outlined, color: CFColors.primary, size: 40),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: CFColors.primary, size: 36),
                          ),
                        ),
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
                description,
                style: theme.textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
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
          color: selected
              ? CFColors.primary.withValues(alpha: 0.14)
              : CFColors.primary.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: selected ? CFColors.primary : CFColors.primary.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: CFColors.primary,
              ),
        ),
      ),
    );
  }
}
