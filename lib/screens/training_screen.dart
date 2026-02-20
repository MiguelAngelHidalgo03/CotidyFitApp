import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/training_week_summary.dart';
import '../services/training_week_summary_service.dart';
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
                    color: CFColors.primary.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: CFColors.softGray),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: CFColors.softGray),
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

class _TrainingScreenState extends State<TrainingScreen> {
  final _summaryService = TrainingWeekSummaryService();
  late Future<TrainingWeekSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _summaryService.getCurrentWeekSummary();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _summaryService.getCurrentWeekSummary();
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
                    backgroundColor: CFColors.primary.withValues(alpha: 0.05),
                    borderColor: CFColors.primary.withValues(alpha: 0.18),
                    footer: summary == null
                        ? null
                        : Row(
                            children: [
                              TrainingMiniTag(
                                icon: Icons.calendar_today_outlined,
                                text: '${summary.plannedActiveDays} días',
                              ),
                              const SizedBox(width: 10),
                              TrainingMiniTag(
                                icon: Icons.timer_outlined,
                                text: '${summary.plannedMinutes} min',
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _openWeeklyHistory,
                                child: const Text('Historial semanal'),
                              ),
                            ],
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
