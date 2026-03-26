import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../models/training_week_summary.dart';
import '../services/training_week_summary_service.dart';
import '../widgets/common/inline_status_banner.dart';
import '../widgets/progress/progress_section_card.dart';
import '../widgets/training/training_premium_card.dart';
import '../widgets/training/training_action_card.dart';
import '../widgets/training/training_week_overview_header.dart';
import '../widgets/training/training_tag_widgets.dart';
import 'explore_workouts_screen.dart';
import 'my_plan_screen.dart';
import 'weekly_history_screen.dart';
import 'weekly_programs_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _HeaderLoading extends StatelessWidget {
  const _HeaderLoading();

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta semana tienes 0 entrenamientos asignados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.cfPrimaryTint,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: context.cfBorder),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.cfPrimaryTint,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: context.cfBorder),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 8,
              backgroundColor: CFColors.softGray,
              color: CFColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingScreenState extends State<TrainingScreen>
    with AutomaticKeepAliveClientMixin<TrainingScreen> {
  final _summaryService = TrainingWeekSummaryService();
  late Future<TrainingWeekSummary> _summaryFuture;
  String? _statusMessage;

  static const _kTrainingSummaryCacheVersion = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _bootstrapSummary();
  }

  Future<TrainingWeekSummary> _bootstrapSummary() async {
    final cached = await _restoreCachedSummary();
    if (cached != null) {
      unawaited(_refreshInBackground());
      return cached;
    }
    return _loadFreshSummary();
  }

  String _cacheKey() =>
      'cf_training_week_summary_v$_kTrainingSummaryCacheVersion';

  Future<TrainingWeekSummary?> _restoreCachedSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey());
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final weekStartRaw = decoded['weekStart'];
      final weekStart = DateTime.tryParse(
        weekStartRaw is String ? weekStartRaw : '',
      );
      if (weekStart == null) return null;

      final currentWeekStart = TrainingWeekSummaryService.mondayOf(
        DateTime.now(),
      );
      if (TrainingWeekSummaryService.mondayOf(weekStart) != currentWeekStart) {
        return null;
      }

      return TrainingWeekSummary(
        weekStart: weekStart,
        assignedWorkouts: _intOf(decoded['assignedWorkouts']),
        plannedMinutes: _intOf(decoded['plannedMinutes']),
        plannedActiveDays: _intOf(decoded['plannedActiveDays']),
        activeDays: _intOf(decoded['activeDays']),
        completedPlannedDays: _intOf(decoded['completedPlannedDays']),
      );
    } catch (_) {
      return null;
    }
  }

  int _intOf(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final raw = (value is String ? value : value?.toString())?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  Future<void> _persistSummaryCache(TrainingWeekSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'weekStart': summary.weekStart.toIso8601String(),
          'assignedWorkouts': summary.assignedWorkouts,
          'plannedMinutes': summary.plannedMinutes,
          'plannedActiveDays': summary.plannedActiveDays,
          'activeDays': summary.activeDays,
          'completedPlannedDays': summary.completedPlannedDays,
        }),
      );
    } catch (_) {
      // Ignore cache failures.
    }
  }

  Future<TrainingWeekSummary> _loadFreshSummary() async {
    try {
      final summary = await _summaryService.getCurrentWeekSummary();
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
      unawaited(_persistSummaryCache(summary));
      return summary;
    } catch (_) {
      final cached = await _restoreCachedSummary();
      if (mounted) {
        setState(() {
          _statusMessage = cached != null
              ? 'No se detecta una fuente de internet. Mostrando tu resumen guardado.'
              : 'No se detecta una fuente de internet. Las rutinas volverán a sincronizarse cuando recupere conexión.';
        });
      }
      return cached ??
          TrainingWeekSummary(
            weekStart: TrainingWeekSummaryService.mondayOf(DateTime.now()),
            assignedWorkouts: 0,
            plannedMinutes: 0,
            plannedActiveDays: 0,
            activeDays: 0,
            completedPlannedDays: 0,
          );
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final summary = await _loadFreshSummary();
      if (!mounted) return;
      setState(() {
        _summaryFuture = Future<TrainingWeekSummary>.value(summary);
      });
    } catch (_) {
      // best-effort
    }
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _loadFreshSummary();
    });
  }

  void _openMyWeek() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyPlanScreen()))
        .then((_) => _refresh());
  }

  void _openWeeklyHistory() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WeeklyHistoryScreen()))
        .then((_) => _refresh());
  }

  void _openExplore() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExploreWorkoutsScreen()))
        .then((_) => _refresh());
  }

  void _openWeeklyPrograms() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WeeklyProgramsScreen()))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<TrainingWeekSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data;

              return ListView(
                children: [
                  if (_statusMessage != null) ...[
                    InlineStatusBanner(message: _statusMessage!),
                    const SizedBox(height: 12),
                  ],
                  if (summary == null)
                    const _HeaderLoading()
                  else
                    TrainingWeekOverviewHeader(summary: summary),
                  const SizedBox(height: 18),
                  TrainingActionCard(
                    title: 'Mi semana',
                    subtitle: 'Organiza tu entrenamiento semanal',
                    icon: Icons.event_note_outlined,
                    onTap: _openMyWeek,
                    footer: summary == null
                        ? null
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 380;
                              final historyButton = TextButton(
                                onPressed: _openWeeklyHistory,
                                child: const Text('Historial semanal'),
                              );
                              final tags = Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  TrainingMiniTag(
                                    icon: Icons.calendar_today_outlined,
                                    text: '${summary.plannedActiveDays} días',
                                  ),
                                  TrainingMiniTag(
                                    icon: Icons.timer_outlined,
                                    text: '${summary.plannedMinutes} min',
                                  ),
                                ],
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    tags,
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: historyButton,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: tags),
                                  const SizedBox(width: 8),
                                  historyButton,
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),
                  TrainingActionCard(
                    title: 'Buscar rutinas',
                    subtitle: 'Filtra por lugar, objetivo, nivel y duración',
                    icon: Icons.search_outlined,
                    onTap: _openExplore,
                  ),
                  const SizedBox(height: 14),
                  TrainingActionCard(
                    title: 'Programas semanales',
                    subtitle: 'Programas completos listos para añadir',
                    icon: Icons.calendar_month_outlined,
                    onTap: _openWeeklyPrograms,
                    footer: const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TrainingTagChip(text: '🔥 Popular'),
                        TrainingTagChip(text: '🟢 Principiante'),
                        TrainingTagChip(text: '💪 Intensivo'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const TrainingPremiumCard(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
