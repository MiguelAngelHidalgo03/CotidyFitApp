import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/progress_advanced_analytics.dart';
import '../models/recipe_model.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../models/workout.dart';
import '../services/achievements_service.dart';
import '../services/daily_data_service.dart';
import '../services/local_storage_service.dart';
import '../services/my_day_repository.dart';
import '../services/my_day_repository_factory.dart';
import '../services/personalized_streak_service.dart';
import '../services/progress_service.dart';
import '../services/progress_week_summary_service.dart';
import '../services/recipe_repository.dart';
import '../services/recipes_repository_factory.dart';
import '../services/training_week_summary_service.dart';
import '../services/weight_service.dart';
import '../services/workout_history_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';

class ProgressAdvancedAnalyticsService {
  ProgressAdvancedAnalyticsService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    ProgressService? progress,
    ProgressWeekSummaryService? weekSummary,
    TrainingWeekSummaryService? trainingWeekSummary,
    WorkoutHistoryService? workoutHistory,
    WorkoutService? workouts,
    MyDayRepository? myDay,
    RecipeRepository? recipes,
    DailyDataService? daily,
    WeightService? weight,
    AchievementsService? achievements,
    LocalStorageService? storage,
  }) : _dbOverride = db,
       _authOverride = auth,
       _progress = progress,
       _weekSummary = weekSummary,
       _trainingWeekSummary =
           trainingWeekSummary ?? TrainingWeekSummaryService(),
       _workoutHistory = workoutHistory ?? WorkoutHistoryService(),
       _workouts = workouts ?? WorkoutService(),
       _myDay = myDay ?? MyDayRepositoryFactory.create(),
       _recipes = recipes ?? RecipesRepositoryFactory.create(),
       _daily = daily ?? DailyDataService(),
       _weight = weight ?? WeightService(),
       _achievements = achievements ?? AchievementsService(),
       _storage = storage ?? LocalStorageService();

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  final ProgressService? _progress;
  final ProgressWeekSummaryService? _weekSummary;
  final TrainingWeekSummaryService _trainingWeekSummary;
  final WorkoutHistoryService _workoutHistory;
  final WorkoutService _workouts;
  final MyDayRepository _myDay;
  final RecipeRepository _recipes;
  final DailyDataService _daily;
  final WeightService _weight;
  final AchievementsService _achievements;
  final LocalStorageService _storage;
  final PersonalizedStreakService _streakService =
      const PersonalizedStreakService();

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;

  Future<ProgressAdvancedAnalytics> load({
    required UserProfile? profile,
  }) async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final monthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final recentStart = now.subtract(const Duration(days: 119));

    await _workouts.ensureLoaded();

    final futures = await Future.wait([
      (_progress ?? ProgressService(storage: _storage)).loadProgress(days: 14),
      (_weekSummary ?? ProgressWeekSummaryService(storage: _storage))
          .getCurrentWeekSummary(),
      _trainingWeekSummary.getCurrentWeekSummary(),
      _workoutHistory.getCompletedWorkoutsByDate(),
      _myDay.getAll(),
      _recipes.getAllRecipes(),
      _daily.getAllCustomMealsByDate(),
      _weight.getHistory(),
      _achievements.getAchievementsForCurrentUser(),
      _loadDailySnapshots(from: recentStart, to: now),
      _loadWeeklyGoalsProgress(now: now),
      _loadMonthlyStatsCached(monthStart: monthStart, profile: profile),
      _loadMonthlyStatsCached(monthStart: previousMonthStart, profile: profile),
      _loadMonthlyTimeline(yearStart: yearStart, end: now, profile: profile),
    ]);

    final progressData = futures[0] as ProgressData;
    final weekSummary = futures[1] as dynamic;
    final trainingSummary = futures[2] as dynamic;
    final completedByDate = futures[3] as Map<String, String>;
    final myDayEntries = futures[4] as List<dynamic>;
    final recipes = futures[5] as List<RecipeModel>;
    final customMealsByDate = futures[6] as Map<String, List<dynamic>>;
    final weightHistory = futures[7] as List<WeightEntry>;
    final achievementItems = futures[8] as List<AchievementViewItem>;
    final dailySnapshots = futures[9] as Map<String, _DaySnapshot>;
    final weeklyGoals = futures[10] as ({double current, double previous});
    final monthStatsCurrent = futures[11] as _MonthlyStats;
    final monthStatsPrevious = futures[12] as _MonthlyStats;
    final monthlyTimeline = futures[13] as List<_MonthlyStats>;

    final recipeById = <String, RecipeModel>{for (final r in recipes) r.id: r};
    final workoutByName = <String, Workout>{
      for (final w in _workouts.getAllWorkouts())
        w.name.trim().toLowerCase(): w,
    };

    _applyNutritionToSnapshots(
      snapshots: dailySnapshots,
      myDayEntries: myDayEntries,
      recipeById: recipeById,
      customMealsByDate: customMealsByDate,
    );

    final general = _buildGeneralSummary(
      progressData: progressData,
      monthCurrent: monthStatsCurrent,
      monthPrevious: monthStatsPrevious,
      weeklyGoalsCurrent: weeklyGoals.current,
      weeklyGoalsPrevious: weeklyGoals.previous,
      snapshots: dailySnapshots,
      profile: profile,
      now: now,
      weekTrainedMinutes: weekSummary.trainedMinutes as int? ?? 0,
    );

    final training = _buildTrainingSummary(
      completedByDate: completedByDate,
      workoutByName: workoutByName,
      trainingSummary: trainingSummary,
      now: now,
    );

    final activity = _buildActivitySummary(
      snapshots: dailySnapshots,
      monthStart: monthStart,
      now: now,
      profile: profile,
    );

    final mostRepeatedMealName = _mostRepeatedMealName(
      myDayEntries: myDayEntries,
      recipeById: recipeById,
      customMealsByDate: customMealsByDate,
      from: monthStart,
      to: now,
    );

    final nutrition = _buildNutritionSummary(
      snapshots: dailySnapshots,
      monthStart: monthStart,
      now: now,
      weekSummary: weekSummary,
      weightHistory: weightHistory,
      mostRepeatedMealName: mostRepeatedMealName,
    );

    final goals = _buildGoalsSummary(
      monthCurrent: monthStatsCurrent,
      weeklyGoalsPercent: general.weeklyGoalsPercent,
      weeklyStreak: general.weeklyStreak,
      trainingAdherence: training.programAdherencePercent,
      nutrition: nutrition,
      activity: activity,
      snapshots: dailySnapshots,
      monthStart: monthStart,
      now: now,
    );

    final achievements = _buildAchievementsSummary(achievementItems);

    final advanced = _buildAdvancedSummary(
      training: training,
      nutrition: nutrition,
      goals: goals,
      snapshots: dailySnapshots,
      monthStart: monthStart,
      now: now,
      monthlyTimeline: monthlyTimeline,
      general: general,
    );

    final weight = _buildWeightSummaryExtended(
      weightHistory: weightHistory,
      now: now,
    );

    final insights = _buildInsights(
      snapshots: dailySnapshots,
      now: now,
      training: training,
      nutrition: nutrition,
      advanced: advanced,
      monthlyTimeline: monthlyTimeline,
      weight: weight,
    );

    return ProgressAdvancedAnalytics(
      general: general,
      training: training,
      activity: activity,
      nutrition: nutrition,
      goals: goals,
      achievements: achievements,
      advanced: advanced,
      weight: weight,
      insights: insights,
    );
  }

  Future<ProgressWeightSummaryExtended> loadWeightSummary({
    DateTime? now,
  }) async {
    final normalizedNow = DateUtilsCF.dateOnly(now ?? DateTime.now());
    final history = await _weight.getHistory();
    return _buildWeightSummaryExtended(
      weightHistory: history,
      now: normalizedNow,
    );
  }

  Future<Map<String, _DaySnapshot>> _loadDailySnapshots({
    required DateTime from,
    required DateTime to,
  }) async {
    final out = <String, _DaySnapshot>{};
    final uid = _uid;

    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      final key = DateUtilsCF.toKey(d);
      out[key] = _DaySnapshot(dateKey: key);
    }

    if (uid != null) {
      try {
        final qs = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .where('dateKey', isGreaterThanOrEqualTo: DateUtilsCF.toKey(from))
            .where('dateKey', isLessThanOrEqualTo: DateUtilsCF.toKey(to))
            .orderBy('dateKey')
            .get();

        for (final doc in qs.docs) {
          final data = doc.data();
          final key = (data['dateKey'] as String? ?? doc.id).trim();
          if (!out.containsKey(key)) continue;
          final row = out[key]!;
          row.steps = _asInt(data['steps']);
          row.activeMinutes = _asInt(data['activeMinutes']);
          row.meditationMinutes = _asInt(data['meditationMinutes']);
          row.mealsLoggedCount = _asInt(data['mealsLoggedCount']);
          row.waterLiters = _asDouble(data['waterLiters']);
          row.cf = _asInt(data['cfIndex']);
          row.workoutCompleted = data['workoutCompleted'] == true;
          row.energy = _asInt(data['energy']);
          row.mood = _asInt(data['mood']);
          row.stress = _asInt(data['stress']);
          row.sleep = _asInt(data['sleep']);
          row.hasData = true;
        }
      } catch (_) {}

      try {
        final moodSnap = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyMood')
            .get();
        for (final doc in moodSnap.docs) {
          final key = doc.id.trim();
          if (!out.containsKey(key)) continue;
          final data = doc.data();
          final row = out[key]!;
          row.mood = _asInt(data['mood']);
          row.sleep = _asInt(data['sleep']) > 0
              ? _asInt(data['sleep'])
              : row.sleep;
          row.energy = _asInt(data['energy']) > 0
              ? _asInt(data['energy'])
              : row.energy;
          row.stress = _asInt(data['stress']) > 0
              ? _asInt(data['stress'])
              : row.stress;
          row.hasData = true;
        }
      } catch (_) {}
    }

    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      final key = DateUtilsCF.toKey(d);
      final local = await _daily.getForDateKey(key);
      final row = out[key]!;
      if (row.steps <= 0) row.steps = local.steps;
      if (row.activeMinutes <= 0) row.activeMinutes = local.activeMinutes;
      if (row.meditationMinutes <= 0) {
        row.meditationMinutes = local.meditationMinutes;
      }
      if (row.waterLiters <= 0) row.waterLiters = local.waterLiters;
      row.energy = row.energy > 0 ? row.energy : (local.energy ?? 0);
      row.mood = row.mood > 0 ? row.mood : (local.mood ?? 0);
      row.stress = row.stress > 0 ? row.stress : (local.stress ?? 0);
      row.sleep = row.sleep > 0 ? row.sleep : (local.sleep ?? 0);
      if (local.steps > 0 ||
          local.activeMinutes > 0 ||
          local.waterLiters > 0 ||
          local.customMeals.isNotEmpty) {
        row.hasData = true;
      }
    }

    return out;
  }

  void _applyNutritionToSnapshots({
    required Map<String, _DaySnapshot> snapshots,
    required List<dynamic> myDayEntries,
    required Map<String, RecipeModel> recipeById,
    required Map<String, List<dynamic>> customMealsByDate,
  }) {
    for (final raw in myDayEntries) {
      final dynamic e = raw;
      final key = (e.dateKey as String?) ?? '';
      if (!snapshots.containsKey(key)) continue;
      final row = snapshots[key]!;
      final recipe = recipeById[e.recipeId as String? ?? ''];
      if (recipe == null) continue;
      row.calories += recipe.kcalPerServing;
      row.protein += recipe.macrosPerServing.proteinG;
      row.carbs += recipe.macrosPerServing.carbsG;
      row.fat += recipe.macrosPerServing.fatG;
      row.mealsLoggedCount = max(
        row.mealsLoggedCount,
        row.mealsLoggedCount + 1,
      );
      row.hasData = true;
    }

    for (final e in snapshots.entries) {
      final custom = customMealsByDate[e.key] ?? const [];
      final row = e.value;
      for (final item in custom) {
        final dynamic cm = item;
        row.calories += _asInt(cm.meal.calorias);
        row.protein += _asInt(cm.meal.proteinas);
        row.carbs += _asInt(cm.meal.carbohidratos);
        row.fat += _asInt(cm.meal.grasas);
        row.mealsLoggedCount = max(
          row.mealsLoggedCount,
          row.mealsLoggedCount + 1,
        );
        row.hasData = true;
      }
    }
  }

  String _mostRepeatedMealName({
    required List<dynamic> myDayEntries,
    required Map<String, RecipeModel> recipeById,
    required Map<String, List<dynamic>> customMealsByDate,
    required DateTime from,
    required DateTime to,
  }) {
    final counts = <String, int>{};

    for (final raw in myDayEntries) {
      final dynamic e = raw;
      final dateKey = (e.dateKey as String?)?.trim() ?? '';
      if (dateKey.isEmpty) continue;

      final date = DateUtilsCF.fromKey(dateKey);
      if (date == null || date.isBefore(from) || date.isAfter(to)) continue;

      final recipeId = (e.recipeId as String?)?.trim() ?? '';
      final recipe = recipeById[recipeId];
      final name = recipe?.name.trim() ?? '';
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    for (final entry in customMealsByDate.entries) {
      final date = DateUtilsCF.fromKey(entry.key);
      if (date == null || date.isBefore(from) || date.isAfter(to)) continue;

      for (final item in entry.value) {
        final dynamic cm = item;
        final dynamic meal = cm.meal;
        final name = (meal?.nombre as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return 'Sin datos';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    bool isGenericMealName(String name) {
      final n = name.trim().toLowerCase();
      return n == 'comida' ||
          n == 'desayuno' ||
          n == 'almuerzo' ||
          n == 'merienda' ||
          n == 'cena' ||
          n == 'snack';
    }

    final preferred = sorted.firstWhere(
      (e) => !isGenericMealName(e.key),
      orElse: () => sorted.first,
    );

    return preferred.key;
  }

  ProgressGeneralSummary _buildGeneralSummary({
    required ProgressData progressData,
    required _MonthlyStats monthCurrent,
    required _MonthlyStats monthPrevious,
    required double weeklyGoalsCurrent,
    required double weeklyGoalsPrevious,
    required Map<String, _DaySnapshot> snapshots,
    required UserProfile? profile,
    required DateTime now,
    required int weekTrainedMinutes,
  }) {
    final orderedKeys = snapshots.keys.toList()..sort();

    final activeFlagsOverall = <bool>[];
    final activeFlagsMonth = <bool>[];

    var monthCfTotal = 0;
    var monthCfCount = 0;

    for (final key in orderedKeys) {
      final d = DateUtilsCF.fromKey(key);
      if (d == null || d.isAfter(now)) continue;

      final row = snapshots[key]!;
      final active = _isActiveDay(row, profile: profile);
      activeFlagsOverall.add(active);

      if (!d.isBefore(monthCurrent.monthStart)) {
        activeFlagsMonth.add(active);
        if (row.cf > 0) {
          monthCfTotal += row.cf;
          monthCfCount += 1;
        }
      }
    }

    final currentStreak = _tailConsecutive(activeFlagsOverall);
    final bestStreak = _maxConsecutive(activeFlagsMonth);
    final weeklyStreak = _streakService.weeklyStreakFromSnapshots(
      profile: profile,
      snapshots: {
        for (final entry in snapshots.entries)
          entry.key: _toPersonalizedSnapshot(entry.value),
      },
      today: now,
    );

    final dailyGoalsPct = monthCurrent.registeredDays == 0
        ? 0
        : ((monthCurrent.dailyGoalsDone / monthCurrent.registeredDays) * 100)
              .round()
              .clamp(0, 100);

    final weeklyGoalsPct = (weeklyGoalsCurrent * 100).round().clamp(0, 100);
    final realConstancy = monthCurrent.registeredDays == 0
        ? 0
        : ((monthCurrent.activeDays / monthCurrent.registeredDays) * 100)
              .round()
              .clamp(0, 100);

    final weeklyGlobalScore =
        ((progressData.average7Days * 0.35) +
                (weeklyGoalsPct * 0.30) +
                (monthCurrent.trainingAdherence * 0.20) +
                (monthCurrent.hydrationPercent * 0.15))
            .round()
            .clamp(0, 100);

    final weekRows = snapshots.entries.where((e) {
      final d = DateUtilsCF.fromKey(e.key);
      return d != null &&
          !d.isBefore(now.subtract(const Duration(days: 6))) &&
          !d.isAfter(now);
    }).toList()..sort((a, b) => a.key.compareTo(b.key));

    final weeklyAverageSteps = weekRows.isEmpty
        ? 0
        : (weekRows.fold<int>(0, (a, b) => a + b.value.steps) / weekRows.length)
              .round();

    final stepFlags = [for (final e in weekRows) e.value.steps >= 8000];
    final trainingFlags = [for (final e in weekRows) e.value.workoutCompleted];
    final healthyFlags = [
      for (final e in weekRows) _isHealthyEatingDay(e.value),
    ];

    final weeklyStepsStreak = _tailConsecutive(stepFlags);
    final weeklyWorkoutStreak = _tailConsecutive(trainingFlags);
    final weeklyHealthyStreak = _tailConsecutive(healthyFlags);

    final weeklyWorkouts = trainingFlags.where((x) => x).length;
    final weeklyHealthyDays = healthyFlags.where((x) => x).length;

    final goalCounters = <String, int>{
      'Pasos +8k': stepFlags.where((x) => x).length,
      'Entrenamiento': trainingFlags.where((x) => x).length,
      'Comida sana': healthyFlags.where((x) => x).length,
      'Hidratación': weekRows.where((e) => e.value.waterLiters >= 2.0).length,
      'Meditación': weekRows
          .where((e) => e.value.meditationMinutes >= 5)
          .length,
    };
    final topWeeklyGoal =
        (goalCounters.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    final weekEnergyAvg = _averageRatings([
      for (final e in weekRows) e.value.energy,
    ]);
    final weekStressAvg = _averageRatings([
      for (final e in weekRows) e.value.stress,
    ]);
    final weekMoodAvg = _averageRatings([
      for (final e in weekRows) e.value.mood,
    ]);
    final weekSleepAvg = _averageRatings([
      for (final e in weekRows) e.value.sleep,
    ]);

    final stateParts = <double>[];
    if (weekEnergyAvg > 0) stateParts.add(weekEnergyAvg);
    if (weekMoodAvg > 0) stateParts.add(weekMoodAvg);
    if (weekSleepAvg > 0) stateParts.add(weekSleepAvg);
    if (weekStressAvg > 0) stateParts.add(6 - weekStressAvg);
    final weekStateAvg = stateParts.isEmpty
        ? 0.0
        : stateParts.reduce((a, b) => a + b) / stateParts.length;

    return ProgressGeneralSummary(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      weeklyStreak: weeklyStreak,
      monthlyDailyGoalsPercent: dailyGoalsPct,
      weeklyGoalsPercent: weeklyGoalsPct,
      monthlyAverageCf: monthCfCount == 0
          ? 0
          : (monthCfTotal / monthCfCount).round().clamp(0, 100),
      realConstancyIndex: realConstancy,
      weeklyGlobalScore: weeklyGlobalScore,
      monthlyDailyGoalsTrend: TrendMetric(
        current: dailyGoalsPct.toDouble(),
        previous: monthPrevious.registeredDays == 0
            ? 0
            : ((monthPrevious.dailyGoalsDone / monthPrevious.registeredDays) *
                  100),
      ),
      weeklyGoalsTrend: TrendMetric(
        current: weeklyGoalsCurrent * 100,
        previous: weeklyGoalsPrevious * 100,
      ),
      cfTrend: TrendMetric(
        current: (monthCfCount == 0 ? 0 : (monthCfTotal / monthCfCount))
            .toDouble(),
        previous: monthPrevious.averageCf.toDouble(),
      ),
      weeklyAverageSteps: weeklyAverageSteps,
      weeklyStepsStreakOver8k: weeklyStepsStreak,
      weeklyWorkouts: weeklyWorkouts,
      weeklyWorkoutStreak: weeklyWorkoutStreak,
      weeklyTrainedMinutes: weekTrainedMinutes,
      weeklyHealthyEatingDays: weeklyHealthyDays,
      weeklyHealthyEatingStreak: weeklyHealthyStreak,
      topWeeklyGoal: topWeeklyGoal,
      weekStateAverage: weekStateAvg,
      weekEnergyAverage: weekEnergyAvg,
      weekStressAverage: weekStressAvg,
      weekMoodAverage: weekMoodAvg,
      weekSleepAverage: weekSleepAvg,
    );
  }

  ProgressTrainingSummary _buildTrainingSummary({
    required Map<String, String> completedByDate,
    required Map<String, Workout> workoutByName,
    required dynamic trainingSummary,
    required DateTime now,
  }) {
    final monthAgo = now.subtract(const Duration(days: 30));
    final weekAgo = now.subtract(const Duration(days: 7));
    final prevWeekAgo = now.subtract(const Duration(days: 14));

    var totalWorkouts = 0;
    var totalMinutes = 0;
    final exerciseCounts = <String, int>{};
    final muscleCounts = <String, int>{};
    final weeklyCounts = <String, int>{};

    for (final entry in completedByDate.entries) {
      final date = DateUtilsCF.fromKey(entry.key);
      if (date == null || date.isBefore(monthAgo)) continue;
      totalWorkouts += 1;
      final workout = workoutByName[entry.value.trim().toLowerCase()];
      totalMinutes += workout?.durationMinutes ?? 25;

      for (final ex in workout?.exercises ?? const []) {
        exerciseCounts[ex.name] = (exerciseCounts[ex.name] ?? 0) + 1;
        final muscle = _inferMuscleGroup(ex.name);
        muscleCounts[muscle] = (muscleCounts[muscle] ?? 0) + 1;
      }

      final monday = _mondayOf(DateUtilsCF.dateOnly(date));
      final weekKey = DateUtilsCF.toKey(monday);
      weeklyCounts[weekKey] = (weeklyCounts[weekKey] ?? 0) + 1;
    }

    final sortedExercises = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostExercises = sortedExercises.take(3).map((e) => e.key).toList();

    final sortedMuscles = muscleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMuscle = sortedMuscles.isEmpty
        ? 'General'
        : sortedMuscles.first.key;

    final currentWeekCount = completedByDate.entries.where((e) {
      final d = DateUtilsCF.fromKey(e.key);
      return d != null && !d.isBefore(weekAgo);
    }).length;

    final prevWeekCount = completedByDate.entries.where((e) {
      final d = DateUtilsCF.fromKey(e.key);
      return d != null && d.isBefore(weekAgo) && !d.isBefore(prevWeekAgo);
    }).length;

    final strengthByExercise = <String, List<ChartPoint>>{};
    for (final name in mostExercises) {
      strengthByExercise[name] = _weeklyExerciseSeries(
        exerciseName: name,
        completedByDate: completedByDate,
        workoutByName: workoutByName,
        now: now,
      );
    }

    final prs = _estimatePrCount(strengthByExercise);
    final levelScore = (totalWorkouts * 2) + (prs * 8) + (totalMinutes ~/ 30);
    final estimatedLevel = levelScore >= 120
        ? 'Avanzado'
        : levelScore >= 65
        ? 'Intermedio'
        : 'Principiante';

    return ProgressTrainingSummary(
      totalWorkouts: totalWorkouts,
      totalMinutes: totalMinutes,
      mostPerformedExercises: mostExercises,
      mostTrainedMuscleGroup: topMuscle,
      personalRecords: prs,
      estimatedLevel: estimatedLevel,
      programAdherencePercent:
          ((trainingSummary.weeklyProgress as double? ?? 0) * 100)
              .round()
              .clamp(0, 100),
      weeklyTrend: TrendMetric(
        current: currentWeekCount.toDouble(),
        previous: prevWeekCount.toDouble(),
      ),
      strengthByExercise: strengthByExercise,
    );
  }

  ProgressActivitySummary _buildActivitySummary({
    required Map<String, _DaySnapshot> snapshots,
    required DateTime monthStart,
    required DateTime now,
    required UserProfile? profile,
  }) {
    final monthRows = snapshots.entries
        .where((e) {
          final d = DateUtilsCF.fromKey(e.key);
          return d != null && !d.isBefore(monthStart) && !d.isAfter(now);
        })
        .map((e) => e.value)
        .toList();

    if (monthRows.isEmpty) {
      return const ProgressActivitySummary(
        averageDailySteps: 0,
        bestStepDayLabel: '—',
        bestStepDaySteps: 0,
        totalDistanceKm: 0,
        estimatedStandingMinutes: 0,
        activeDaysStreak: 0,
        daysOver8000: 0,
        stepsChart: [],
        activityHeatmap: [],
      );
    }

    final totalSteps = monthRows.fold<int>(0, (a, b) => a + b.steps);
    final avgSteps = (totalSteps / monthRows.length).round();

    final best = monthRows.toList()..sort((a, b) => b.steps.compareTo(a.steps));
    final bestRow = best.first;
    final bestDate = DateUtilsCF.fromKey(bestRow.dateKey);
    final bestLabel = bestDate == null
        ? '—'
        : '${bestDate.day.toString().padLeft(2, '0')}/${bestDate.month.toString().padLeft(2, '0')}';

    final height = (profile?.heightCm ?? 170).clamp(130, 220);
    final stepMeters = height * 0.415 / 100;
    final distanceKm = (totalSteps * stepMeters) / 1000;

    final daysOver8k = monthRows.where((r) => r.steps >= 8000).length;

    final activeStreak = _maxConsecutive(
      monthRows.map((e) => e.steps >= 8000).toList(),
    );

    final estimatedStandingMinutes = (totalSteps / 100).round();

    final stepsChart = monthRows.map((r) {
      final d = DateUtilsCF.fromKey(r.dateKey);
      return ChartPoint(
        label: d == null ? '' : d.day.toString(),
        value: r.steps.toDouble(),
      );
    }).toList();

    final heatmap = monthRows
        .map((r) => ((r.steps / 12000) * 100).round().clamp(0, 100))
        .toList();

    return ProgressActivitySummary(
      averageDailySteps: avgSteps,
      bestStepDayLabel: bestLabel,
      bestStepDaySteps: bestRow.steps,
      totalDistanceKm: distanceKm,
      estimatedStandingMinutes: estimatedStandingMinutes,
      activeDaysStreak: activeStreak,
      daysOver8000: daysOver8k,
      stepsChart: stepsChart,
      activityHeatmap: heatmap,
    );
  }

  ProgressNutritionSummary _buildNutritionSummary({
    required Map<String, _DaySnapshot> snapshots,
    required DateTime monthStart,
    required DateTime now,
    required dynamic weekSummary,
    required List<WeightEntry> weightHistory,
    required String mostRepeatedMealName,
  }) {
    final monthRows = snapshots.entries
        .where((e) {
          final d = DateUtilsCF.fromKey(e.key);
          return d != null && !d.isBefore(monthStart) && !d.isAfter(now);
        })
        .map((e) => e.value)
        .toList();

    final targetCalories =
        ((weekSummary.proteinTargetDailyG as int) * 4) +
        ((weekSummary.carbsTargetDailyG as int) * 4) +
        ((weekSummary.fatTargetDailyG as int) * 9);

    var monthCaloriesLogged = 0;
    var monthLoggedDays = 0;
    var highProteinDays = 0;
    var daysMeetingGoal = 0;
    var proteinTotal = 0;
    var carbsTotal = 0;
    var fatTotal = 0;

    for (final r in monthRows) {
      proteinTotal += r.protein;
      carbsTotal += r.carbs;
      fatTotal += r.fat;
      if (r.protein >= 100) highProteinDays += 1;
      if (targetCalories > 0 &&
          (r.calories - targetCalories).abs() <= (targetCalories * 0.15)) {
        daysMeetingGoal += 1;
      }

      if (r.calories > 0 || r.mealsLoggedCount > 0) {
        monthCaloriesLogged += r.calories;
        monthLoggedDays += 1;
      }
    }

    final monthlyBalance = monthLoggedDays == 0
        ? 0
        : (monthCaloriesLogged - (targetCalories * monthLoggedDays)).toInt();
    final topMeal = mostRepeatedMealName.trim().isEmpty
        ? 'Sin datos'
        : mostRepeatedMealName.trim();

    final macroTotal = max(1, proteinTotal + carbsTotal + fatTotal);
    final macroDistribution = <String, double>{
      'Proteína': (proteinTotal / macroTotal) * 100,
      'Carbohidratos': (carbsTotal / macroTotal) * 100,
      'Grasas': (fatTotal / macroTotal) * 100,
    };

    final caloriesTrend = monthRows.map((r) {
      final d = DateUtilsCF.fromKey(r.dateKey);
      return ChartPoint(
        label: d == null ? '' : d.day.toString(),
        value: r.calories.toDouble(),
      );
    }).toList();

    return ProgressNutritionSummary(
      weeklyCalorieBalance: monthlyBalance,
      mostRepeatedMeal: topMeal,
      highProteinDays: highProteinDays,
      daysMeetingCalorieGoal: daysMeetingGoal,
      averageMonthlyCalories: monthLoggedDays == 0
          ? 0
          : (monthCaloriesLogged / monthLoggedDays).round(),
      macroDistribution: macroDistribution,
      caloriesTrend: caloriesTrend,
      smoothedWeightTrend: _movingAverageWeight(weightHistory, window: 7),
    );
  }

  ProgressGoalsSummary _buildGoalsSummary({
    required _MonthlyStats monthCurrent,
    required int weeklyGoalsPercent,
    required int weeklyStreak,
    required int trainingAdherence,
    required ProgressNutritionSummary nutrition,
    required ProgressActivitySummary activity,
    required Map<String, _DaySnapshot> snapshots,
    required DateTime monthStart,
    required DateTime now,
  }) {
    final monthRows = snapshots.entries
        .where((e) {
          final d = DateUtilsCF.fromKey(e.key);
          return d != null && !d.isBefore(monthStart) && !d.isAfter(now);
        })
        .map((e) => e.value)
        .toList();

    final mentalDays = monthRows
        .where((r) => r.mood >= 3 || r.meditationMinutes >= 5)
        .length;

    final totalDays = max(1, monthRows.length);
    final categories = <String, int>{
      'Entrenamiento': trainingAdherence.clamp(0, 100).toInt(),
      'Nutrición': ((nutrition.daysMeetingCalorieGoal / totalDays) * 100)
          .round()
          .clamp(0, 100),
      'Salud': ((activity.daysOver8000 / totalDays) * 100).round().clamp(
        0,
        100,
      ),
      'Mental': ((mentalDays / totalDays) * 100).round().clamp(0, 100),
    };

    final dailyCompletion = monthCurrent.registeredDays == 0
        ? 0
        : ((monthCurrent.dailyGoalsDone / monthCurrent.registeredDays) * 100)
              .round()
              .clamp(0, 100);

    return ProgressGoalsSummary(
      dailyCompletionPercent: dailyCompletion,
      weeklyCompletionPercent: weeklyGoalsPercent,
      weeklyStreak: weeklyStreak,
      categoryBreakdown: categories,
    );
  }

  ProgressAchievementsSummary _buildAchievementsSummary(
    List<AchievementViewItem> items,
  ) {
    final unlockedItems = items.where((e) => e.user.unlocked).toList();
    final inProgressItems = items
        .where((e) => !e.user.unlocked && e.progressRatio > 0)
        .toList();

    final rarest = items.toList()
      ..sort(
        (a, b) => b.catalog.conditionValue.compareTo(a.catalog.conditionValue),
      );
    final rarestTitles = rarest.take(3).map((e) => e.catalog.title).toList();

    final byCategory = <String, int>{};
    for (final it in unlockedItems) {
      final category = it.catalog.category.trim().isEmpty
          ? 'General'
          : it.catalog.category;
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    final xp =
        (unlockedItems.length * 50) +
        (inProgressItems.length * 10) +
        items.fold<int>(0, (a, b) => a + (b.progressRatio * 20).round());

    final level = (xp ~/ 250) + 1;
    final nextLevelXp = level * 250;

    return ProgressAchievementsSummary(
      unlocked: unlockedItems.length,
      inProgress: inProgressItems.length,
      rarest: rarestTitles,
      byCategory: byCategory,
      level: level,
      currentXp: xp,
      nextLevelXp: nextLevelXp,
    );
  }

  ProgressAdvancedSummary _buildAdvancedSummary({
    required ProgressTrainingSummary training,
    required ProgressNutritionSummary nutrition,
    required ProgressGoalsSummary goals,
    required Map<String, _DaySnapshot> snapshots,
    required DateTime monthStart,
    required DateTime now,
    required List<_MonthlyStats> monthlyTimeline,
    required ProgressGeneralSummary general,
  }) {
    final monthRows = snapshots.entries
        .where((e) {
          final d = DateUtilsCF.fromKey(e.key);
          return d != null && !d.isBefore(monthStart) && !d.isAfter(now);
        })
        .map((e) => e.value)
        .toList();

    final recovery = monthRows.isEmpty
        ? 0
        : ((monthRows.fold<double>(0, (a, b) => a + b.waterLiters) /
                      monthRows.length) /
                  2.5 *
                  100)
              .round()
              .clamp(0, 100)
              .toInt();

    final mental = goals.categoryBreakdown['Mental'] ?? 0;
    final trainingScore =
        goals.categoryBreakdown['Entrenamiento'] ??
        training.programAdherencePercent;
    final nutritionScore = goals.categoryBreakdown['Nutrición'] ?? 0;

    final healthyLife =
        ((trainingScore * 0.4) + (nutritionScore * 0.35) + (recovery * 0.25))
            .round()
            .clamp(0, 100)
            .toInt();

    final streakTimeline = monthlyTimeline
        .map(
          (m) =>
              ChartPoint(label: m.labelShort, value: m.bestStreak.toDouble()),
        )
        .toList();

    final moodEvolution = monthRows.where((r) => r.mood > 0).map((r) {
      final d = DateUtilsCF.fromKey(r.dateKey);
      return ChartPoint(
        label: d == null ? '' : d.day.toString(),
        value: r.mood.toDouble(),
      );
    }).toList();

    final monthMoodAverage = _averageRatings([
      for (final r in monthRows) r.mood,
    ]);
    final monthEnergyAverage = _averageRatings([
      for (final r in monthRows) r.energy,
    ]);
    final monthStressAverage = _averageRatings([
      for (final r in monthRows) r.stress,
    ]);
    final monthSleepAverage = _averageRatings([
      for (final r in monthRows) r.sleep,
    ]);
    final monthAnimatedAverage = monthMoodAverage;

    final bestMonth = monthlyTimeline.toList()
      ..sort((a, b) => b.combinedScore.compareTo(a.combinedScore));

    final radar = <RadarMetric>[
      RadarMetric(label: 'Training', value: trainingScore.toDouble()),
      RadarMetric(label: 'Nutrition', value: nutritionScore.toDouble()),
      RadarMetric(label: 'Recovery', value: recovery.toDouble()),
      RadarMetric(label: 'Mental', value: mental.toDouble()),
    ];

    final waterTrend = monthRows.reversed.take(14).toList().reversed.map((r) {
      final d = DateUtilsCF.fromKey(r.dateKey);
      return ChartPoint(
        label: d == null ? '' : d.day.toString(),
        value: r.waterLiters,
      );
    }).toList();

    final cfTrend = monthRows.reversed.take(14).toList().reversed.map((r) {
      final d = DateUtilsCF.fromKey(r.dateKey);
      return ChartPoint(
        label: d == null ? '' : d.day.toString(),
        value: r.cf.toDouble(),
      );
    }).toList();

    return ProgressAdvancedSummary(
      healthyLifeBalanceScore: healthyLife,
      historicalStreakTimeline: streakTimeline,
      moodEvolution: moodEvolution,
      bestVersionMonth: bestMonth.isEmpty ? '—' : bestMonth.first.labelLong,
      radarMetrics: radar,
      waterTrend: waterTrend,
      cfTrend: cfTrend,
      monthMoodAverage: monthMoodAverage,
      monthEnergyAverage: monthEnergyAverage,
      monthStressAverage: monthStressAverage,
      monthSleepAverage: monthSleepAverage,
      monthAnimatedAverage: monthAnimatedAverage,
    );
  }

  ProgressWeightSummaryExtended _buildWeightSummaryExtended({
    required List<WeightEntry> weightHistory,
    required DateTime now,
  }) {
    final sorted = weightHistory.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = sorted.length <= 60
        ? sorted
        : sorted.sublist(sorted.length - 60);

    final raw = [
      for (final e in trimmed)
        ChartPoint(label: '${e.date.day}/${e.date.month}', value: e.weight),
    ];

    final smoothed = _movingAverageWeight(trimmed, window: 7);

    final latest = trimmed.isEmpty ? null : trimmed.last;
    final currentWeight = latest?.weight;
    final currentWeightLabel = latest == null
        ? '—'
        : (DateUtilsCF.dateOnly(latest.date) == now
              ? 'Hoy'
              : '${latest.date.day.toString().padLeft(2, '0')}/${latest.date.month.toString().padLeft(2, '0')}');

    final thisMonth = sorted
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonth = sorted
        .where(
          (e) =>
              e.date.year == prevMonthDate.year &&
              e.date.month == prevMonthDate.month,
        )
        .toList();

    final thisAvg = thisMonth.isEmpty
        ? 0
        : thisMonth.fold<double>(0, (a, b) => a + b.weight) / thisMonth.length;
    final prevAvg = prevMonth.isEmpty
        ? thisAvg
        : prevMonth.fold<double>(0, (a, b) => a + b.weight) / prevMonth.length;

    final byMonth = <String, List<double>>{};
    for (final e in sorted) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => <double>[]).add(e.weight);
    }

    var bestMonth = '—';
    var bestAvg = double.infinity;
    for (final entry in byMonth.entries) {
      final avg =
          entry.value.fold<double>(0, (a, b) => a + b) /
          max(1, entry.value.length);
      if (avg < bestAvg) {
        bestAvg = avg;
        bestMonth = entry.key;
      }
    }

    final changePct = prevAvg == 0
        ? 0.0
        : ((thisAvg - prevAvg) / prevAvg) * 100;

    return ProgressWeightSummaryExtended(
      rawTrend: raw,
      smoothedTrend: smoothed,
      monthlyComparison: (thisAvg - prevAvg).toDouble(),
      bestMonth: bestMonth,
      changeFromLastMonthPercent: changePct,
      context: 'El peso fluctúa naturalmente. Observa la tendencia, no el día.',
      currentWeight: currentWeight,
      currentWeightLabel: currentWeightLabel,
    );
  }

  List<ProgressInsightItem> _buildInsights({
    required Map<String, _DaySnapshot> snapshots,
    required DateTime now,
    required ProgressTrainingSummary training,
    required ProgressNutritionSummary nutrition,
    required ProgressAdvancedSummary advanced,
    required List<_MonthlyStats> monthlyTimeline,
    required ProgressWeightSummaryExtended weight,
  }) {
    final out = <ProgressInsightItem>[];

    final last30 = snapshots.entries
        .where((e) {
          final d = DateUtilsCF.fromKey(e.key);
          return d != null &&
              !d.isBefore(now.subtract(const Duration(days: 29))) &&
              !d.isAfter(now);
        })
        .map((e) => e.value)
        .toList();

    final sleepGood = last30.where((d) => d.sleep >= 4).toList();
    if (sleepGood.length >= 6 && training.weeklyTrend.isUp) {
      out.add(
        const ProgressInsightItem(
          'Tu rendimiento mejora cuando duermes más de 7h.',
        ),
      );
    }

    final stepsHigh = last30.where((d) => d.steps >= 8000).length;
    if (stepsHigh >= 12 && weight.monthlyComparison <= 0) {
      out.add(
        const ProgressInsightItem(
          'Pierdes más peso cuando caminas más de 8k pasos.',
        ),
      );
    }

    final weekdayCounts = <int, int>{};
    for (final e in snapshots.entries) {
      final d = DateUtilsCF.fromKey(e.key);
      if (d == null) continue;
      if (!e.value.workoutCompleted) continue;
      weekdayCounts[d.weekday] = (weekdayCounts[d.weekday] ?? 0) + 1;
    }
    if (weekdayCounts.isNotEmpty) {
      final bestDay =
          (weekdayCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
      out.add(
        ProgressInsightItem('Entrenas más los ${_weekdayName(bestDay)}.'),
      );
    }

    if (monthlyTimeline.isNotEmpty) {
      final sorted = monthlyTimeline.toList()
        ..sort((a, b) => b.combinedScore.compareTo(a.combinedScore));
      out.add(
        ProgressInsightItem('Tu mejor mes fue ${sorted.first.labelLong}.'),
      );
    }

    if (!training.weeklyTrend.isUp && training.weeklyTrend.delta < 0) {
      out.add(
        const ProgressInsightItem(
          'Esta semana entrenaste menos que la anterior.',
        ),
      );
    }

    if (nutrition.daysMeetingCalorieGoal >= 5) {
      out.add(
        const ProgressInsightItem(
          'Tu regularidad calórica está mejorando tu consistencia semanal.',
        ),
      );
    }

    if (advanced.healthyLifeBalanceScore >= 75) {
      out.add(
        const ProgressInsightItem(
          'Tu balance de vida saludable está en un nivel alto, sigue ese patrón.',
        ),
      );
    }

    if (out.isEmpty) {
      out.add(
        const ProgressInsightItem(
          'Sigue registrando datos: en pocos días aparecerán insights más precisos.',
        ),
      );
    }

    return out;
  }

  Future<({double current, double previous})> _loadWeeklyGoalsProgress({
    required DateTime now,
  }) async {
    final uid = _uid;
    if (uid == null) return (current: 0.0, previous: 0.0);

    final currentWeek = _mondayOf(now);
    final previousWeek = currentWeek.subtract(const Duration(days: 7));

    final currentSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('weeklyStats')
        .doc(DateUtilsCF.toKey(currentWeek))
        .get();

    final previousSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('weeklyStats')
        .doc(DateUtilsCF.toKey(previousWeek))
        .get();

    final cur = _asDouble(
      currentSnap.data()?['progress'],
    ).clamp(0.0, 1.0).toDouble();
    final prev = _asDouble(
      previousSnap.data()?['progress'],
    ).clamp(0.0, 1.0).toDouble();

    return (current: cur, previous: prev);
  }

  Future<_MonthlyStats> _loadMonthlyStatsCached({
    required DateTime monthStart,
    required UserProfile? profile,
  }) async {
    final uid = _uid;
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final effectiveEnd = monthEnd.isAfter(today) ? today : monthEnd;
    final monthId =
        '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
    final configKey = _streakService.preferencesFor(profile).cacheKey;

    if (uid != null) {
      try {
        final ref = _db
            .collection('users')
            .doc(uid)
            .collection('monthlyStats')
            .doc(monthId);
        final snap = await ref.get();
        final data = snap.data();

        final updatedAt = data?['updatedAt'];
        final updated = _asDateTime(updatedAt);
        final cachedConfigKey = data?['streakConfigKey'] as String?;
        if (data != null && updated != null && cachedConfigKey == configKey) {
          final age = DateTime.now().difference(updated);
          if (age.inHours < 12) {
            final parsed = _MonthlyStats.fromMap(data, monthStart: monthStart);
            if (parsed != null) return parsed;
          }
        }

        final computed = await _computeMonthlyStats(
          monthStart: monthStart,
          monthEnd: effectiveEnd,
          profile: profile,
        );
        await ref.set({
          ...computed.toMap(),
          'streakConfigKey': configKey,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return computed;
      } catch (_) {
        return _computeMonthlyStats(
          monthStart: monthStart,
          monthEnd: effectiveEnd,
          profile: profile,
        );
      }
    }

    return _computeMonthlyStats(
      monthStart: monthStart,
      monthEnd: effectiveEnd,
      profile: profile,
    );
  }

  Future<List<_MonthlyStats>> _loadMonthlyTimeline({
    required DateTime yearStart,
    required DateTime end,
    required UserProfile? profile,
  }) async {
    final out = <_MonthlyStats>[];
    var current = DateTime(yearStart.year, yearStart.month, 1);
    while (!current.isAfter(end)) {
      out.add(await _loadMonthlyStatsCached(monthStart: current, profile: profile));
      current = DateTime(current.year, current.month + 1, 1);
    }
    return out;
  }

  Future<_MonthlyStats> _computeMonthlyStats({
    required DateTime monthStart,
    required DateTime monthEnd,
    required UserProfile? profile,
  }) async {
    final snapshots = await _loadDailySnapshots(from: monthStart, to: monthEnd);
    final rows = snapshots.values.toList();

    var registered = 0;
    var activeDays = 0;
    var dailyGoalsDone = 0;
    var cfTotal = 0;
    var cfCount = 0;
    var hydrationHits = 0;

    final activeFlags = <bool>[];
    for (final r in rows) {
      if (r.hasData) registered += 1;
      final active = _isActiveDay(r, profile: profile);
      if (active) activeDays += 1;
      activeFlags.add(active);

      final goals = [
        r.workoutCompleted,
        r.steps >= 8000,
        r.mealsLoggedCount >= 3,
        r.meditationMinutes >= 5,
        r.waterLiters >= 2.5,
      ].where((x) => x).length;
      if (goals >= 3) dailyGoalsDone += 1;

      if (r.cf > 0) {
        cfTotal += r.cf;
        cfCount += 1;
      }
      if (r.waterLiters >= 2.0) hydrationHits += 1;
    }

    return _MonthlyStats(
      monthStart: monthStart,
      registeredDays: registered,
      activeDays: activeDays,
      dailyGoalsDone: dailyGoalsDone,
      averageCf: cfCount == 0 ? 0 : (cfTotal / cfCount).round().clamp(0, 100),
      currentStreak: _currentConsecutive(activeFlags),
      bestStreak: _maxConsecutive(activeFlags),
      weeklyStreak: max(0, (activeDays / 4).floor()),
      trainingAdherence: rows.isEmpty
          ? 0
          : ((rows.where((r) => r.workoutCompleted).length / rows.length) * 100)
                .round()
                .clamp(0, 100),
      hydrationPercent: rows.isEmpty
          ? 0
          : ((hydrationHits / rows.length) * 100).round().clamp(0, 100),
    );
  }

  bool _isActiveDay(_DaySnapshot row, {required UserProfile? profile}) {
    return _streakService.isCompletedDay(
      profile: profile,
      snapshot: _toPersonalizedSnapshot(row),
    );
  }

  PersonalizedStreakDaySnapshot _toPersonalizedSnapshot(_DaySnapshot row) {
    return PersonalizedStreakDaySnapshot(
      workoutCompleted: row.workoutCompleted,
      steps: row.steps,
      mealsLoggedCount: row.mealsLoggedCount,
      meditationMinutes: row.meditationMinutes,
      waterLiters: row.waterLiters,
      cf: row.cf,
      moodRegistered: row.mood > 0,
      hasData: row.hasData,
    );
  }

  List<ChartPoint> _movingAverageWeight(
    List<WeightEntry> history, {
    required int window,
  }) {
    if (history.isEmpty) return const [];
    final out = <ChartPoint>[];
    for (var i = 0; i < history.length; i++) {
      final start = max(0, i - window + 1);
      final slice = history.sublist(start, i + 1);
      final avg = slice.fold<double>(0, (a, b) => a + b.weight) / slice.length;
      out.add(
        ChartPoint(
          label: '${history[i].date.day}/${history[i].date.month}',
          value: avg,
        ),
      );
    }
    return out;
  }

  List<ChartPoint> _weeklyExerciseSeries({
    required String exerciseName,
    required Map<String, String> completedByDate,
    required Map<String, Workout> workoutByName,
    required DateTime now,
  }) {
    final out = <ChartPoint>[];
    for (var i = 7; i >= 0; i--) {
      final weekStart = _mondayOf(now.subtract(Duration(days: i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));
      var score = 0;

      for (final entry in completedByDate.entries) {
        final date = DateUtilsCF.fromKey(entry.key);
        if (date == null || date.isBefore(weekStart) || date.isAfter(weekEnd)) {
          continue;
        }

        final workout = workoutByName[entry.value.trim().toLowerCase()];
        if (workout == null) continue;
        final contains = workout.exercises.any((e) => e.name == exerciseName);
        if (!contains) continue;
        score += workout.durationMinutes;
      }

      out.add(
        ChartPoint(
          label: '${weekStart.day}/${weekStart.month}',
          value: score.toDouble(),
        ),
      );
    }
    return out;
  }

  int _estimatePrCount(Map<String, List<ChartPoint>> seriesByExercise) {
    var prs = 0;
    for (final series in seriesByExercise.values) {
      if (series.length < 3) continue;
      final recent = series.last.value;
      final previousMax = series
          .sublist(0, series.length - 1)
          .fold<double>(0, (a, b) => max(a, b.value));
      if (recent > previousMax && recent > 0) prs += 1;
    }
    return prs;
  }

  int _maxConsecutive(List<bool> flags) {
    var best = 0;
    var cur = 0;
    for (final f in flags) {
      if (f) {
        cur += 1;
        best = max(best, cur);
      } else {
        cur = 0;
      }
    }
    return best;
  }

  int _tailConsecutive(List<bool> flags) {
    var streak = 0;
    for (var i = flags.length - 1; i >= 0; i--) {
      if (!flags[i]) break;
      streak += 1;
    }
    return streak;
  }

  bool _isHealthyEatingDay(_DaySnapshot row) {
    if (row.mealsLoggedCount >= 3) return true;
    if (row.calories >= 1100 && row.protein >= 70) return true;
    return false;
  }

  double _averageRatings(List<int> values) {
    final filtered = values.where((v) => v > 0).toList();
    if (filtered.isEmpty) return 0.0;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  int _currentConsecutive(List<bool> flags) {
    var cur = 0;
    for (var i = flags.length - 1; i >= 0; i--) {
      if (!flags[i]) break;
      cur += 1;
    }
    return cur;
  }

  String _inferMuscleGroup(String exerciseName) {
    final n = exerciseName.toLowerCase();
    if (n.contains('sentadilla') ||
        n.contains('squat') ||
        n.contains('zancada')) {
      return 'Pierna';
    }
    if (n.contains('press') || n.contains('pecho') || n.contains('push')) {
      return 'Pecho/Hombro';
    }
    if (n.contains('remo') || n.contains('dominada') || n.contains('pull')) {
      return 'Espalda';
    }
    if (n.contains('plancha') ||
        n.contains('core') ||
        n.contains('abdominal')) {
      return 'Core';
    }
    return 'General';
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateUtilsCF.dateOnly(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'lunes';
      case DateTime.tuesday:
        return 'martes';
      case DateTime.wednesday:
        return 'miércoles';
      case DateTime.thursday:
        return 'jueves';
      case DateTime.friday:
        return 'viernes';
      case DateTime.saturday:
        return 'sábados';
      default:
        return 'domingos';
    }
  }

  int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  DateTime? _asDateTime(Object? value) {
    final dynamic raw = value;
    if (raw == null) return null;
    try {
      final dt = raw.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    if (value is DateTime) return value;
    return null;
  }
}

class _DaySnapshot {
  _DaySnapshot({required this.dateKey});

  final String dateKey;

  int steps = 0;
  int activeMinutes = 0;
  int meditationMinutes = 0;
  int mealsLoggedCount = 0;
  double waterLiters = 0;
  int cf = 0;
  int energy = 0;
  int mood = 0;
  int stress = 0;
  int sleep = 0;
  bool workoutCompleted = false;
  bool hasData = false;

  int calories = 0;
  int protein = 0;
  int carbs = 0;
  int fat = 0;
}

class _MonthlyStats {
  const _MonthlyStats({
    required this.monthStart,
    required this.registeredDays,
    required this.activeDays,
    required this.dailyGoalsDone,
    required this.averageCf,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStreak,
    required this.trainingAdherence,
    required this.hydrationPercent,
  });

  final DateTime monthStart;
  final int registeredDays;
  final int activeDays;
  final int dailyGoalsDone;
  final int averageCf;
  final int currentStreak;
  final int bestStreak;
  final int weeklyStreak;
  final int trainingAdherence;
  final int hydrationPercent;

  String get labelShort {
    const names = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return names[(monthStart.month - 1).clamp(0, 11)];
  }

  String get labelLong {
    const names = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${names[(monthStart.month - 1).clamp(0, 11)]} ${monthStart.year}';
  }

  int get combinedScore =>
      ((averageCf * 0.4) +
              (trainingAdherence * 0.35) +
              (hydrationPercent * 0.25))
          .round();

  Map<String, Object?> toMap() => {
    'registeredDays': registeredDays,
    'activeDays': activeDays,
    'dailyGoalsDone': dailyGoalsDone,
    'averageCf': averageCf,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'weeklyStreak': weeklyStreak,
    'trainingAdherence': trainingAdherence,
    'hydrationPercent': hydrationPercent,
  };

  static _MonthlyStats? fromMap(
    Map<String, dynamic> map, {
    required DateTime monthStart,
  }) {
    return _MonthlyStats(
      monthStart: monthStart,
      registeredDays: _toInt(map['registeredDays']),
      activeDays: _toInt(map['activeDays']),
      dailyGoalsDone: _toInt(map['dailyGoalsDone']),
      averageCf: _toInt(map['averageCf']).clamp(0, 100),
      currentStreak: _toInt(map['currentStreak']),
      bestStreak: _toInt(map['bestStreak']),
      weeklyStreak: _toInt(map['weeklyStreak']),
      trainingAdherence: _toInt(map['trainingAdherence']).clamp(0, 100),
      hydrationPercent: _toInt(map['hydrationPercent']).clamp(0, 100),
    );
  }

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
