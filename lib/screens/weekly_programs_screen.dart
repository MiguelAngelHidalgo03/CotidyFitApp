import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../models/weekly_program_model.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/cycle_recommendation_service.dart';
import '../services/profile_service.dart';
import '../services/training_firestore_service.dart';
import '../services/training_recommendation_service.dart';
import '../services/women_cycle_service.dart';
import '../services/weekly_programs_service.dart';
import '../services/workout_plan_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_section_card.dart';
import 'weekly_program_detail_screen.dart';

class WeeklyProgramsScreen extends StatefulWidget {
  const WeeklyProgramsScreen({super.key});

  @override
  State<WeeklyProgramsScreen> createState() => _WeeklyProgramsScreenState();
}

class _WeeklyProgramsScreenState extends State<WeeklyProgramsScreen> {
  final _programs = WeeklyProgramsService();
  final _plans = WorkoutPlanService();
  final _workouts = WorkoutService();
  final _profileService = ProfileService();
  final _trainingFirestore = TrainingFirestoreService();
  final _womenCycleService = WomenCycleService();

  bool _saving = false;
  bool _loading = true;
  String? _error;

  UserProfile? _profile;
  List<WeeklyProgramModel> _items = const [];
  WeekPlan? _currentWeekPlan;
  WomenCycleData? _cycleData;

  final Set<WorkoutPlace> _places = {};
  final Set<WorkoutGoal> _goals = {};
  final Set<WorkoutDifficulty> _difficulties = {};
  final Set<WorkoutDurationFilter> _durations = {};

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
      await _workouts.ensureLoaded();
      final profile = await _profileService.getProfile();
      final cycle = await _womenCycleService.getCurrentCycle();
      final items = await _programs.getPrograms();
      final weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));
      final plan = await _plans.getPlanForWeekKey(DateUtilsCF.toKey(weekStart));
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _cycleData = cycle;
        _items = items;
        _currentWeekPlan = plan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error al cargar programas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday;
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

      final generatedAssignments = await _trainingFirestore
          .buildUserWeekAssignmentsFromProgram(programId: program.id);
      if (generatedAssignments.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo asignar el programa. Verifica sesión y días configurados.',
            ),
          ),
        );
        return;
      }
      for (final entry in generatedAssignments.entries) {
        baseAssignments[entry.key] = entry.value;
      }

      final updated =
          (existing ?? WeekPlan(weekStart: weekStart, assignments: const {}))
              .copyWith(weekStart: weekStart, assignments: baseAssignments);

      await _plans.upsertPlan(updated);
      if (!mounted) return;
      setState(() => _currentWeekPlan = updated);
      unawaited(_workouts.refreshFromFirestore());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan semanal agregado a tu semana actual.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDetail(WeeklyProgramModel p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeeklyProgramDetailScreen(programId: p.id),
      ),
    );
  }

  WorkoutDifficulty _difficultyFromLevel(String level) {
    switch (level.trim().toLowerCase()) {
      case 'principiante':
        return WorkoutDifficulty.leve;
      case 'avanzado':
        return WorkoutDifficulty.experto;
      case 'intermedio':
      default:
        return WorkoutDifficulty.moderado;
    }
  }

  WorkoutPlace _placeFromEquipment(String equipment) {
    switch (equipment.trim().toLowerCase()) {
      case 'gym':
        return WorkoutPlace.gimnasio;
      case 'casa con material':
      case 'casa_con_material':
      case 'home':
        return WorkoutPlace.casaConMaterial;
      case 'parque':
      case 'aire libre':
      case 'outdoor':
        return WorkoutPlace.parqueCalistenia;
      case 'casa':
      case 'sin material':
      case 'sin_material':
      case 'none':
      default:
        return WorkoutPlace.casaSinMaterial;
    }
  }

  bool _matchesGoal(String objetivo, WorkoutGoal goal) {
    final o = objetivo.toLowerCase();
    switch (goal) {
      case WorkoutGoal.perderGrasa:
        return o.contains('grasa') || o.contains('peso');
      case WorkoutGoal.ganarMasaMuscular:
        return o.contains('masa') || o.contains('muscular');
      case WorkoutGoal.tonificar:
        return o.contains('ton');
      case WorkoutGoal.principiantes:
        return o.contains('hábito') || o.contains('princip');
      case WorkoutGoal.flexibilidad:
        return o.contains('flex');
      case WorkoutGoal.movilidad:
        return o.contains('movil');
      case WorkoutGoal.cardio:
        return o.contains('cardio') || o.contains('resistencia');
    }
  }

  bool _matchesProgram(WeeklyProgramModel p) {
    if (_places.isNotEmpty &&
        !_places.contains(_placeFromEquipment(p.equipmentNeeded))) {
      return false;
    }
    if (_goals.isNotEmpty && !_goals.any((g) => _matchesGoal(p.objetivo, g))) {
      return false;
    }
    if (_difficulties.isNotEmpty &&
        !_difficulties.contains(_difficultyFromLevel(p.nivel))) {
      return false;
    }
    if (_durations.isNotEmpty &&
        !_durations.any((d) => d.matchesMinutes(p.durationMinutes))) {
      return false;
    }
    return true;
  }

  bool _isProgramApplied(WeeklyProgramModel program) {
    final values =
        _currentWeekPlan?.assignments.values ?? const Iterable<String>.empty();
    final prefix = 'gen_${program.id}_';
    for (final id in values) {
      if (id.startsWith(prefix)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planes semanales')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
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

    final filtered = _items.where(_matchesProgram).toList();
    final isPeriodActive = CycleRecommendationService.isPeriodActive(
      _cycleData,
    );
    final scored =
        filtered
            .map(
              (p) => (
                program: p,
                rec: TrainingRecommendationService.scoreWeeklyProgram(
                  profile: _profile,
                  program: p,
                ),
              ),
            )
            .toList()
          ..sort((a, b) {
            final sb =
                b.rec.score +
                (isPeriodActive
                    ? CycleRecommendationService.weeklyProgramPeriodScore(
                        b.program,
                      )
                    : 0);
            final sa =
                a.rec.score +
                (isPeriodActive
                    ? CycleRecommendationService.weeklyProgramPeriodScore(
                        a.program,
                      )
                    : 0);
            return sb.compareTo(sa);
          });

    final periodFriendly = isPeriodActive
        ? scored
              .where(
                (e) => CycleRecommendationService.isWeeklyProgramPeriodFriendly(
                  e.program,
                ),
              )
              .take(3)
              .toList()
        : const [];
    final periodIds = {for (final item in periodFriendly) item.program.id};
    final recommended = scored
        .where((e) => e.rec.score > 0 && !periodIds.contains(e.program.id))
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Planes semanales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (isPeriodActive) ...[
              ProgressSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regla activa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Priorizamos programas semanales más suaves o marcados desde tu base de datos para esta fase.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (periodFriendly.isNotEmpty) ...[
              Text(
                'Programas para estos días',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final item in periodFriendly) ...[
                _WeeklyProgramCard(
                  program: item.program,
                  busy: _saving,
                  recommendation:
                      'Bien para estos días. ${item.rec.explanation}',
                  primaryLabel: _isProgramApplied(item.program)
                      ? 'Editar plan'
                      : 'Agregar a mi plan',
                  onApply: _isProgramApplied(item.program)
                      ? () => _openDetail(item.program)
                      : () => _applyToCurrentWeek(item.program),
                  onOpen: () => _openDetail(item.program),
                  highlightedForPeriod: true,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
            if (recommended.isNotEmpty) ...[
              Text(
                'Recomendado para ti',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final item in recommended) ...[
                _WeeklyProgramCard(
                  program: item.program,
                  busy: _saving,
                  recommendation: item.rec.explanation,
                  primaryLabel: _isProgramApplied(item.program)
                      ? 'Editar plan'
                      : 'Agregar a mi plan',
                  onApply: _isProgramApplied(item.program)
                      ? () => _openDetail(item.program)
                      : () => _applyToCurrentWeek(item.program),
                  onOpen: () => _openDetail(item.program),
                  highlightedForPeriod: false,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
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
            const SizedBox(height: 14),
            Text('Programas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (scored.isEmpty)
              const ProgressSectionCard(
                child: Text(
                  'No hay programas que coincidan con estos filtros.',
                ),
              )
            else
              for (final item in scored) ...[
                _WeeklyProgramCard(
                  program: item.program,
                  busy: _saving,
                  recommendation: item.rec.explanation,
                  primaryLabel: _isProgramApplied(item.program)
                      ? 'Editar plan'
                      : 'Agregar a mi plan',
                  onApply: _isProgramApplied(item.program)
                      ? () => _openDetail(item.program)
                      : () => _applyToCurrentWeek(item.program),
                  onOpen: () => _openDetail(item.program),
                ),
                const SizedBox(height: 10),
              ],
          ],
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
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
                    color: selected.contains(v)
                        ? CFColors.primary
                        : CFColors.softGray,
                  ),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected.contains(v)
                        ? CFColors.primary
                        : CFColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgramCard extends StatelessWidget {
  const _WeeklyProgramCard({
    required this.program,
    required this.onApply,
    required this.onOpen,
    required this.busy,
    required this.recommendation,
    required this.primaryLabel,
    this.highlightedForPeriod = false,
  });

  final WeeklyProgramModel program;
  final VoidCallback onApply;
  final VoidCallback onOpen;
  final bool busy;
  final String recommendation;
  final String primaryLabel;
  final bool highlightedForPeriod;

  String _equipmentLabel(String equipment) {
    switch (equipment.trim().toLowerCase()) {
      case '':
      case 'none':
      case 'sin material':
      case 'sin_material':
      case 'bodyweight':
      case 'peso corporal':
        return 'Sin material';
      case 'casa':
      case 'casa con material':
      case 'casa_con_material':
      case 'home':
        return 'Casa con material';
      case 'gym':
        return 'Gimnasio';
      case 'parque':
      case 'aire libre':
      case 'outdoor':
        return 'Parque';
      default:
        return equipment.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (highlightedForPeriod) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.cfPrimaryTint,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: Border.all(color: context.cfPrimaryTintStrong),
                ),
                child: Text(
                  'Recomendado con la regla',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.cfPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: CFColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    program.nombre,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: CFColors.textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            _MetaLine(label: 'Objetivo', value: program.objetivo),
            const SizedBox(height: 6),
            _MetaLine(label: 'Nivel', value: program.nivel),
            const SizedBox(height: 6),
            _MetaLine(label: 'Duración', value: '${program.semanas} semanas'),
            const SizedBox(height: 6),
            _MetaLine(
              label: 'Equipamiento',
              value: _equipmentLabel(program.equipmentNeeded),
            ),
            const SizedBox(height: 10),
            Text(program.descripcion),
            const SizedBox(height: 8),
            Text(
              recommendation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: CFColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(busy ? 'Agregando…' : primaryLabel),
              ),
            ),
          ],
        ),
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
