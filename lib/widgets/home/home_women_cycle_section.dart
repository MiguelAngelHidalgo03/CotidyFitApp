import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/recipe_model.dart';
import '../../models/user_profile.dart';
import '../../models/workout.dart';
import '../../screens/women_cycle_history_screen.dart';
import '../../screens/nutrition/recipe_detail_screen.dart';
import '../../screens/workout_detail_screen.dart';
import '../../services/recipe_repository.dart';
import '../../services/recipes_repository_factory.dart';
import '../../services/training_recommendation_service.dart';
import '../../services/women_cycle_service.dart';
import '../../services/workout_service.dart';
import '../../utils/date_utils.dart';
import '../progress/progress_section_card.dart';

class HomeWomenCycleSection extends StatefulWidget {
  const HomeWomenCycleSection({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<HomeWomenCycleSection> createState() => _HomeWomenCycleSectionState();
}

class _HomeWomenCycleSectionState extends State<HomeWomenCycleSection> {
  late final WomenCycleService _womenCycleService;
  late final RecipeRepository _recipes;
  late final WorkoutService _workouts;

  WomenCycleData? _cycleData;
  List<WomenCycleFoodTip> _cycleTips = const [];
  List<Workout> _allWorkouts = const [];
  List<({Workout workout, String reason})> _cycleWorkoutTips = const [];

  @override
  void initState() {
    super.initState();
    _womenCycleService = WomenCycleService();
    _recipes = RecipesRepositoryFactory.create();
    _workouts = WorkoutService();
    _load();
  }

  bool get _isFemale => widget.profile.sex == UserSex.mujer;

  Future<void> _load() async {
    if (!_isFemale) return;

    final cycleData = await _womenCycleService.getCurrentCycle();
    final isActive = cycleData != null && cycleData.end == null;

    if (!isActive) {
      if (!mounted) return;
      setState(() {
        _cycleData = cycleData;
        _cycleTips = const [];
        _allWorkouts = const [];
        _cycleWorkoutTips = const [];
      });
      return;
    }

    final recipes = await _recipes.getAllRecipes();
    final workouts = await _workouts.refreshFromFirestore();
    final tips = _womenCycleService.buildFoodTips(
      now: DateTime.now(),
      recipes: recipes,
    );
    final workoutTips = _buildWomenCycleWorkoutTips(
      cycle: cycleData,
      profile: widget.profile,
      workouts: workouts,
    );

    if (!mounted) return;
    setState(() {
      _cycleData = cycleData;
      _cycleTips = tips;
      _allWorkouts = workouts;
      _cycleWorkoutTips = workoutTips;
    });
  }

  List<({Workout workout, String reason})> _buildWomenCycleWorkoutTips({
    required WomenCycleData? cycle,
    required UserProfile? profile,
    required List<Workout> workouts,
  }) {
    if (workouts.isEmpty) return const [];

    final isActive = cycle != null && cycle.end == null;

    final scored = workouts
        .map(
          (w) => (
            workout: w,
            rec: TrainingRecommendationService.scoreWorkout(
              profile: profile,
              workout: w,
            ),
          ),
        )
        .where((e) => e.rec.score >= 0)
        .toList();

    if (scored.isEmpty) return const [];

    var candidates = scored;
    if (isActive) {
      final low = scored.where((e) {
        final w = e.workout;
        final name = w.name.toLowerCase();
        final category = w.category.toLowerCase();
        final hasMobility =
            w.goals.contains(WorkoutGoal.movilidad) ||
            w.goals.contains(WorkoutGoal.flexibilidad) ||
            name.contains('estir') ||
            name.contains('movil') ||
            name.contains('yoga') ||
            category.contains('estir') ||
            category.contains('movil') ||
            category.contains('yoga');

        final isLight =
            w.difficulty == WorkoutDifficulty.leve ||
            w.durationMinutes <= 20 ||
            w.level.toLowerCase().contains('princip');
        return hasMobility || isLight;
      }).toList();
      if (low.isNotEmpty) candidates = low;
    }

    candidates.sort((a, b) {
      final byScore = b.rec.score.compareTo(a.rec.score);
      if (byScore != 0) return byScore;
      return a.workout.durationMinutes.compareTo(b.workout.durationMinutes);
    });

    String activeReason(Workout w, TrainingRecommendation rec) {
      final tags = <String>[];
      if (w.goals.contains(WorkoutGoal.movilidad)) tags.add('movilidad');
      if (w.goals.contains(WorkoutGoal.flexibilidad)) tags.add('flexibilidad');
      if (w.difficulty == WorkoutDifficulty.leve) tags.add('leve');
      if (w.durationMinutes > 0) tags.add('${w.durationMinutes} min');
      final tagText = tags.isEmpty
          ? 'baja intensidad'
          : tags.take(3).join(' · ');
      return 'Días de regla: $tagText. ${rec.explanation}';
    }

    return [
      for (final e in candidates.take(2))
        (
          workout: e.workout,
          reason: isActive ? activeReason(e.workout, e.rec) : e.rec.explanation,
        ),
    ];
  }

  Future<void> _openRecipeDetail(String recipeId) async {
    final id = recipeId.trim();
    if (id.isEmpty) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)));
  }

  Future<void> _openWorkoutDetail(Workout workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout)),
    );
  }

  Future<void> _openCycleHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WomenCycleHistoryScreen(profile: widget.profile),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFemale) return const SizedBox.shrink();

    final cycle = _cycleData;
    final now = DateUtilsCF.dateOnly(DateTime.now());

    final isActive = cycle != null && cycle.end == null;

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    String statusText() {
      if (cycle == null) return 'Pulsa "Tengo la regla" cuando empiece.';
      if (cycle.end == null) {
        final days = now.difference(cycle.start).inDays + 1;
        return 'Regla activa · día ${days < 1 ? 1 : days}.';
      }

      final daysAgo = now.difference(cycle.end!).inDays;
      if (daysAgo <= 0) return 'Última regla terminó hoy.';
      if (daysAgo == 1) return 'Última regla terminó ayer.';
      return 'Última regla terminó hace $daysAgo día(s).';
    }

    return GestureDetector(
      onTap: _openCycleHistory,
      child: ProgressSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              const Icon(Icons.female_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ciclo y nutrición femenino',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.cfTextSecondary,
              ),
              const SizedBox(width: 8),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.45),
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    'Regla activa',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusText(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Toca esta tarjeta para ver tu historial y tus fechas guardadas.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.cfTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (cycle != null) ...[
            const SizedBox(height: 4),
            Text(
              cycle.end == null
                  ? 'Inicio: ${fmt(cycle.start)}'
                  : 'Inicio: ${fmt(cycle.start)} · Fin: ${fmt(cycle.end!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: isActive
                    ? FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.endPeriod();
                          if (!mounted || next == null) return;
                          setState(() {
                            _cycleData = next;
                            _cycleTips = const [];
                            _allWorkouts = const [];
                            _cycleWorkoutTips = const [];
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Fin de regla guardado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Se me acabó la regla'),
                      )
                    : FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.startPeriod();
                          if (!mounted) return;
                          setState(() {
                            _cycleData = next;
                          });
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Regla iniciada.')),
                          );
                          await _load();
                        },
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Tengo la regla'),
                      ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openCycleHistory,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Ver historial'),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.restaurant_outlined, color: CFColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comidas recomendadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final tip in _cycleTips.take(3)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 16,
                      color: CFColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.cfTextPrimary,
                              ),
                        ),
                        Text(
                          tip.reason,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (context) {
                final seen = <String>{};
                final items = <RecipeModel>[];
                for (final tip in _cycleTips) {
                  for (final r in tip.recipes) {
                    if (!seen.add(r.id)) continue;
                    items.add(r);
                    if (items.length >= 2) break;
                  }
                  if (items.length >= 2) break;
                }

                if (items.isEmpty) {
                  return Text(
                    'Sin recomendaciones de recetas todavía.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Column(
                  children: [
                    for (final r in items) ...[
                      ProgressSectionCard(
                        padding: const EdgeInsets.all(12),
                        boxShadow: const [],
                        backgroundColor: context.cfSoftSurface,
                        borderColor: context.cfBorder,
                        child: InkWell(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(18),
                          ),
                          onTap: () => _openRecipeDetail(r.id),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.restaurant_menu_outlined,
                                color: CFColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r.durationMinutes} min · ${r.kcalPerServing} kcal/ración',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'P ${r.macrosPerServing.proteinG}g · C ${r.macrosPerServing.carbsG}g · G ${r.macrosPerServing.fatG}g',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: context.cfTextSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right,
                                color: context.cfTextSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.self_improvement_outlined,
                  color: CFColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ejercicios y estiramientos recomendados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cycleWorkoutTips.isEmpty)
              Text(
                'Sin recomendaciones de entreno todavía.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final entry in _cycleWorkoutTips) ...[
                ProgressSectionCard(
                  padding: const EdgeInsets.all(12),
                  boxShadow: const [],
                  backgroundColor: context.cfSoftSurface,
                  borderColor: context.cfBorder,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    onTap: () => _openWorkoutDetail(entry.workout),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.fitness_center_outlined,
                          color: CFColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.workout.name,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.workout.durationMinutes} min · ${entry.workout.level}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: context.cfTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          color: context.cfTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
          ],
        ),
      ),
    );
  }
}
