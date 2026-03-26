import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/achievement_catalog_item.dart';
import '../models/exercise.dart';
import '../models/message_model.dart';
import '../models/recipe_model.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../services/achievements_service.dart';
import '../services/community_share_card_service.dart';
import '../services/community_share_template_service.dart';
import '../services/daily_data_service.dart';
import '../services/home_dashboard_service.dart';
import '../services/my_day_repository.dart';
import '../services/my_day_repository_factory.dart';
import '../services/personalized_streak_service.dart';
import '../services/profile_service.dart';
import '../services/recipe_repository.dart';
import '../services/recipes_repository_factory.dart';
import '../services/workout_history_service.dart';
import '../services/workout_plan_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';

class CommunityShareOption {
  const CommunityShareOption({
    required this.id,
    required this.title,
    this.subtitle,
    required this.payload,
    this.share,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String payload;
  final Map<String, Object?>? share;
}

enum CommunityExternalShareTarget {
  generic,
  whatsappChat,
  whatsappStatus,
  instagramDirect,
  instagramStory,
  instagramPost,
  instagramReel,
  tiktok,
}

class CommunityExternalShareDraft {
  const CommunityExternalShareDraft({
    required this.subject,
    required this.text,
    required this.shortPhrase,
  });

  final String subject;
  final String text;
  final String shortPhrase;
}

class CommunityPreparedExternalShare {
  const CommunityPreparedExternalShare({
    required this.draft,
    required this.imageBytes,
    required this.imageName,
  });

  final CommunityExternalShareDraft draft;
  final Uint8List imageBytes;
  final String imageName;
}

class CommunityShareService {
  static const String _defaultPublicPromoUrl = 'https://cotidyfit.com';
  static const String _brandLogoAsset = 'assets/branding/share_logo.png';

  CommunityShareService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    DailyDataService? daily,
    HomeDashboardService? dashboard,
    WorkoutHistoryService? workoutHistory,
    WorkoutPlanService? workoutPlans,
    WorkoutService? workouts,
    MyDayRepository? myDay,
    RecipeRepository? recipes,
    AchievementsService? achievements,
    CommunityShareTemplateService? templateService,
    CommunityShareCardService? cardService,
    String? publicPromoUrl,
  }) : _dbOverride = db,
       _authOverride = auth,
       _daily = daily ?? DailyDataService(),
       _dashboard = dashboard ?? HomeDashboardService(),
       _workoutHistory = workoutHistory ?? WorkoutHistoryService(),
       _workoutPlans = workoutPlans ?? WorkoutPlanService(),
       _workouts = workouts ?? WorkoutService(),
       _myDay = myDay ?? MyDayRepositoryFactory.create(),
       _recipes = recipes ?? RecipesRepositoryFactory.create(),
       _achievements = achievements ?? AchievementsService(),
       _templateService = templateService ?? CommunityShareTemplateService(),
       _cardService = cardService ?? CommunityShareCardService(),
       _publicPromoUrl = _normalizePromoUrl(publicPromoUrl);

  static String _normalizePromoUrl(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isNotEmpty) return normalized;
    return _defaultPublicPromoUrl;
  }

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  final DailyDataService _daily;
  final HomeDashboardService _dashboard;
  final WorkoutHistoryService _workoutHistory;
  final WorkoutPlanService _workoutPlans;
  final WorkoutService _workouts;
  final MyDayRepository _myDay;
  final RecipeRepository _recipes;
  final AchievementsService _achievements;
  final CommunityShareTemplateService _templateService;
  final CommunityShareCardService _cardService;
  final String _publicPromoUrl;
  final ProfileService _profileService = ProfileService();
  final PersonalizedStreakService _streakService =
      const PersonalizedStreakService();

  bool get _firebaseReady => Firebase.apps.isNotEmpty;
  String? get _uid => _firebaseReady ? _auth.currentUser?.uid : null;
  String get publicPromoUrl => _publicPromoUrl;

  Future<List<CommunityShareOption>> getShareOptions({
    required MessageType type,
  }) async {
    switch (type) {
      case MessageType.text:
        return const <CommunityShareOption>[];
      case MessageType.routine:
        return _routineOptions();
      case MessageType.achievement:
        return _achievementOptions();
      case MessageType.daySummary:
        return _daySummaryOptions();
      case MessageType.diet:
        return _dietOptions();
      case MessageType.streaks:
        final data = await _composeStreaksData();
        final summary = data.text;
        final payload = 'Mi racha en CotidyFit 🔥\n$summary';
        return [
          CommunityShareOption(
            id: 'streaks',
            title: 'Rachas',
            subtitle: summary,
            payload: payload,
            share: {
              'v': 1,
              'currentStreak': data.current,
              'maxStreak': data.best,
              'summary': summary,
              'streakTitle': data.title,
              'avgSteps': data.avgSteps,
              'avgWaterLiters': data.avgWaterLiters,
              'avgCfPoints': data.avgCf,
              'workoutsPerWeek': data.workoutsPerWeek,
              'healthyDays': data.healthyDays,
              'goalDays': data.goalDays,
            },
          ),
        ];
    }
  }

  Future<String?> composeShareText({required MessageType type}) async {
    switch (type) {
      case MessageType.text:
        return null;
      case MessageType.streaks:
        return _composeStreaks();
      case MessageType.daySummary:
        return _composeDaySummary();
      case MessageType.diet:
        return _composeDiet();
      case MessageType.achievement:
        return _composeAchievement();
      case MessageType.routine:
        return _composeRoutine();
    }
  }

  Future<void> syncMyPublicStatsBestEffort() async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateUtilsCF.dateOnly(DateTime.now());
    final todayKey = DateUtilsCF.toKey(now);
    final profile = await _profileService.getProfile();

    final streakData = await _loadPersonalizedStreakStats(profile: profile);
    final currentStreak = streakData.current;

    // Read existing public doc so we can safely keep max streak.
    int existingMaxStreak = 0;
    try {
      final pubSnap = await _db.collection('user_public').doc(uid).get();
      final data = pubSnap.data() ?? const <String, dynamic>{};
      existingMaxStreak =
          _readInt(
            data['maxStreak'] ?? data['maxStreakDays'] ?? data['bestStreak'],
          ) ??
          0;
    } catch (_) {
      existingMaxStreak = 0;
    }

    final maxStreak = max(existingMaxStreak, streakData.best);

    // Workouts count + last workout.
    String? lastWorkoutName;
    int workoutsCount = 0;
    try {
      final completed = await _workoutHistory.getCompletedWorkoutsByDate();
      workoutsCount = completed.length;
      if (completed.isNotEmpty) {
        final keys = completed.keys.toList()..sort();
        lastWorkoutName = completed[keys.last];
      }
      final todayName = completed[todayKey];
      if (todayName != null && todayName.trim().isNotEmpty) {
        lastWorkoutName = todayName.trim();
      }
    } catch (_) {
      // ignore
    }

    // Achievements unlocked.
    int? achievementsUnlocked;
    try {
      final items = await _achievements.getAchievementsForCurrentUser();
      achievementsUnlocked = items.where((a) => a.user.unlocked).length;
    } catch (_) {
      achievementsUnlocked = null;
    }

    // Active days (last 30d) + nutrition compliance (last 7d) from dailyStats.
    int? activeDays30;
    double? nutritionCompliancePct;
    if (_firebaseReady) {
      try {
        final from30 = now.subtract(const Duration(days: 29));
        final qs30 = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .where('dateKey', isGreaterThanOrEqualTo: DateUtilsCF.toKey(from30))
            .where('dateKey', isLessThanOrEqualTo: todayKey)
            .orderBy('dateKey')
            .get();

        var active = 0;
        for (final doc in qs30.docs) {
          final d = doc.data();
          final isActive = _streakService.isCompletedDay(
            profile: profile,
            snapshot: PersonalizedStreakDaySnapshot.fromDailyStatsMap(
              d,
              hasData: d.isNotEmpty,
            ),
          );
          if (isActive) active += 1;
        }
        activeDays30 = active;
      } catch (_) {
        activeDays30 = null;
      }

      try {
        final from7 = now.subtract(const Duration(days: 6));
        final qs7 = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .where('dateKey', isGreaterThanOrEqualTo: DateUtilsCF.toKey(from7))
            .where('dateKey', isLessThanOrEqualTo: todayKey)
            .orderBy('dateKey')
            .get();

        var hits = 0;
        var days = 0;
        for (final doc in qs7.docs) {
          final d = doc.data();
          final meals = (_readInt(d['mealsLoggedCount']) ?? 0).clamp(0, 3);
          if (meals > 0) days += 1;
          if (meals >= DailyDataService.mealsTarget) hits += 1;
        }
        if (days > 0) {
          nutritionCompliancePct = ((hits / days) * 100.0).clamp(0.0, 100.0);
        }
      } catch (_) {
        nutritionCompliancePct = null;
      }
    }

    final authUser = _auth.currentUser;
    final displayName = (authUser?.displayName ?? '').trim();
    final emailPrefix = (authUser?.email ?? '').split('@').first.trim();
    final safeName = displayName.isNotEmpty
        ? displayName
        : (emailPrefix.isNotEmpty ? emailPrefix : null);

    final safeLastWorkoutName =
        (lastWorkoutName == null || lastWorkoutName.trim().isEmpty)
        ? null
        : lastWorkoutName.trim();

    final publicUpdate = <String, dynamic>{
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'workouts': workoutsCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (safeName != null) publicUpdate['displayName'] = safeName;
    if (safeLastWorkoutName != null) {
      publicUpdate['lastWorkoutName'] = safeLastWorkoutName;
    }
    if (achievementsUnlocked != null) {
      publicUpdate['achievementsUnlocked'] = achievementsUnlocked;
    }
    if (activeDays30 != null) publicUpdate['activeDays'] = activeDays30;
    if (nutritionCompliancePct != null) {
      publicUpdate['nutritionCompliancePct'] = nutritionCompliancePct;
    }

    try {
      await _db
          .collection('user_public')
          .doc(uid)
          .set(publicUpdate, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }

    // Presence is separate but also best-effort.
    try {
      await _db.collection('user_public').doc(uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  Future<
    ({
      int current,
      int best,
      String text,
      String title,
      int avgSteps,
      double avgWaterLiters,
      int avgCf,
      int workoutsPerWeek,
      int healthyDays,
      int goalDays,
    })
  >
  _composeStreaksData() async {
    final uid = _uid;
    final profile = await _profileService.getProfile();
    final streakStats = await _loadPersonalizedStreakStats(profile: profile);
    final current = streakStats.current;
    final title = _streakService.streakTitleFor(profile);

    int best = streakStats.best;
    if (uid != null) {
      try {
        final snap = await _db.collection('user_public').doc(uid).get();
        final data = snap.data() ?? const <String, dynamic>{};
        final existing = _readInt(
          data['maxStreak'] ?? data['maxStreakDays'] ?? data['bestStreak'],
        );
        if (existing != null) best = max(best, existing);
      } catch (_) {
        // ignore
      }

      // Keep public doc up to date (best-effort).
      try {
        await _db.collection('user_public').doc(uid).set({
          'currentStreak': current,
          'maxStreak': best,
          'streakTitle': title,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore
      }
    }

    final recent = await _composeRecentWeekStats();

    return (
      current: current,
      best: best,
      text: _streakService.shareSummaryFor(
        profile,
        current: current,
        best: best,
      ),
      title: title,
      avgSteps: recent.avgSteps,
      avgWaterLiters: recent.avgWaterLiters,
      avgCf: recent.avgCf,
      workoutsPerWeek: recent.workoutsPerWeek,
      healthyDays: recent.healthyDays,
      goalDays: recent.goalDays,
    );
  }

  Future<
    ({
      int avgSteps,
      double avgWaterLiters,
      int avgCf,
      int workoutsPerWeek,
      int healthyDays,
      int goalDays,
    })
  >
  _composeRecentWeekStats() async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    var stepsTotal = 0;
    var waterTotal = 0.0;
    var cfTotal = 0;
    var workoutDays = 0;
    var healthyDays = 0;
    var goalDays = 0;

    for (var index = 0; index < 7; index++) {
      final day = today.subtract(Duration(days: index));
      final data = await _composeDaySummaryShareForDate(day);
      stepsTotal += data.steps.clamp(0, 1000000000);
      waterTotal += data.waterLiters.clamp(0.0, 999.0);
      cfTotal += data.cf.clamp(0, 100);
      if (data.workoutCompleted || data.workoutMinutes > 0) {
        workoutDays += 1;
      }
      if (data.meals >= DailyDataService.mealsTarget) {
        healthyDays += 1;
      }
      if (data.goalMet) {
        goalDays += 1;
      }
    }

    return (
      avgSteps: (stepsTotal / 7).round(),
      avgWaterLiters: waterTotal / 7,
      avgCf: (cfTotal / 7).round(),
      workoutsPerWeek: workoutDays,
      healthyDays: healthyDays,
      goalDays: goalDays,
    );
  }

  Future<({int current, int best})> _loadPersonalizedStreakStats({
    required UserProfile? profile,
  }) async {
    final uid = _uid;
    if (uid == null) return (current: 0, best: 0);

    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .orderBy('dateKey')
        .get();

    final byDay = <String, PersonalizedStreakDaySnapshot>{};
    for (final doc in qs.docs) {
      final data = doc.data();
      final key = ((data['dateKey'] as String?) ?? doc.id).trim();
      if (key.isEmpty) continue;
      byDay[key] = PersonalizedStreakDaySnapshot.fromDailyStatsMap(
        data,
        hasData: data.isNotEmpty,
      );
    }

    if (byDay.isEmpty) return (current: 0, best: 0);

    final orderedKeys = byDay.keys.toList()..sort();
    final start = DateUtilsCF.fromKey(orderedKeys.first);
    final today = DateUtilsCF.dateOnly(DateTime.now());
    if (start == null) return (current: 0, best: 0);

    final flags = <bool>[];
    for (
      var day = start;
      !day.isAfter(today);
      day = day.add(const Duration(days: 1))
    ) {
      final key = DateUtilsCF.toKey(day);
      final snapshot = byDay[key];
      if (snapshot == null) {
        if (key == DateUtilsCF.toKey(today)) continue;
        flags.add(false);
        continue;
      }
      flags.add(
        _streakService.isCompletedDay(profile: profile, snapshot: snapshot),
      );
    }

    return (
      current: _streakService.currentStreak(flags),
      best: _streakService.bestStreak(flags),
    );
  }

  Future<String> _composeStreaks() async {
    final summary = (await _composeStreaksData()).text;
    return 'Mi racha en CotidyFit 🔥\n$summary';
  }

  Future<String> _composeDiet() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final data = await _composeDietShareForDay(now);
    final headline = 'Mi registro de comidas 🥗';
    return '$headline\n${data.summary}';
  }

  Future<
    ({
      String summary,
      List<Map<String, Object?>> meals,
      int healthyMeals,
      int kcal,
      int proteinG,
      int carbsG,
      int fatG,
    })
  >
  _composeDietShareForDay(
    DateTime day, {
    Map<String, RecipeModel> recipeById = const {},
  }) async {
    final key = DateUtilsCF.toKey(day);

    final entries = await _myDay.getForDate(day);
    final daily = await _daily.getForDateKey(key);

    final counts = <MealType, int>{};
    final recipeIdsByMeal = <MealType, List<String>>{};
    final customMealsByMeal = <MealType, List<Map<String, Object?>>>{};

    for (final e in entries) {
      counts[e.mealType] = (counts[e.mealType] ?? 0) + 1;
      recipeIdsByMeal.putIfAbsent(e.mealType, () => []).add(e.recipeId);
    }
    for (final cm in daily.customMeals) {
      counts[cm.mealType] = (counts[cm.mealType] ?? 0) + 1;
      customMealsByMeal
          .putIfAbsent(cm.mealType, () => [])
          .add(cm.meal.toJson());
    }

    String summary;
    if (counts.isEmpty) {
      summary = '0/${DailyDataService.mealsTarget} comidas saludables';
    } else {
      final uniqueMeals = counts.keys.length.clamp(
        0,
        DailyDataService.mealsTarget,
      );
      summary =
          '$uniqueMeals/${DailyDataService.mealsTarget} comidas saludables';
    }

    var kcal = 0;
    var proteinG = 0;
    var carbsG = 0;
    var fatG = 0;
    final meals = <Map<String, Object?>>[];
    for (final meal in MealType.values) {
      final recipeIds = recipeIdsByMeal[meal] ?? const <String>[];
      final customMeals =
          customMealsByMeal[meal] ?? const <Map<String, Object?>>[];
      if (recipeIds.isEmpty && customMeals.isEmpty) continue;

      final recipes = <Map<String, Object?>>[
        for (final id in recipeIds)
          {
            'id': id,
            'name': (recipeById[id]?.name ?? '').trim(),
            'kcal': recipeById[id]?.kcalPerServing ?? 0,
            'proteinG': recipeById[id]?.macrosPerServing.proteinG ?? 0,
            'carbsG': recipeById[id]?.macrosPerServing.carbsG ?? 0,
            'fatG': recipeById[id]?.macrosPerServing.fatG ?? 0,
          },
      ];

      for (final recipe in recipes) {
        kcal += _readInt(recipe['kcal']) ?? 0;
        proteinG += _readInt(recipe['proteinG']) ?? 0;
        carbsG += _readInt(recipe['carbsG']) ?? 0;
        fatG += _readInt(recipe['fatG']) ?? 0;
      }
      for (final rawCustomMeal in customMeals) {
        kcal += _readInt(rawCustomMeal['calorias']) ?? 0;
        proteinG += _readInt(rawCustomMeal['proteinas']) ?? 0;
        carbsG += _readInt(rawCustomMeal['carbohidratos']) ?? 0;
        fatG += _readInt(rawCustomMeal['grasas']) ?? 0;
      }

      meals.add({
        'mealType': meal.name,
        'label': meal.label,
        'recipes': recipes,
        'customMeals': customMeals,
        'count': recipeIds.length + customMeals.length,
      });
    }

    return (
      summary: summary,
      meals: meals,
      healthyMeals: counts.keys.length.clamp(0, DailyDataService.mealsTarget),
      kcal: kcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }

  Future<String> _composeDaySummary() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final summary = await _composeDaySummaryForDate(now);
    return 'Mi día en CotidyFit 💪\n$summary';
  }

  Future<
    ({
      String summary,
      int cf,
      int workoutMinutes,
      int steps,
      double waterLiters,
      int meals,
      String moodIcon,
      int moodValue,
      String workoutLabel,
      String? workoutName,
      bool workoutCompleted,
      int completionCount,
      int completionTarget,
      bool goalMet,
    })
  >
  _composeDaySummaryShareForDate(DateTime date) async {
    final uid = _uid;
    final day = DateUtilsCF.dateOnly(date);
    final key = DateUtilsCF.toKey(day);

    final localDaily = await _daily.getForDateKey(key);

    Map<String, dynamic> insight = const <String, dynamic>{};
    if (uid != null) {
      try {
        insight = await _dashboard.getDailyInsight(uid: uid, dateKey: key);
      } catch (_) {
        insight = const <String, dynamic>{};
      }
    }

    final steps = (_readInt(insight['steps']) ?? 0) > 0
        ? _readInt(insight['steps']) ?? 0
        : localDaily.steps;

    final waterLiters = (_readDouble(insight['waterLiters']) ?? 0) > 0
        ? (_readDouble(insight['waterLiters']) ?? 0)
        : localDaily.waterLiters;

    bool workoutCompleted = insight['workoutCompleted'] == true;
    String? workoutName;
    try {
      workoutName = await _workoutHistory.getCompletedWorkoutName(key);
    } catch (_) {
      workoutName = null;
    }
    if (workoutName != null && workoutName.trim().isNotEmpty) {
      workoutCompleted = true;
    }

    int meals = (_readInt(insight['mealsLoggedCount']) ?? 0).clamp(0, 3);
    if (meals <= 0) {
      try {
        final entries = await _myDay.getForDate(day);
        final set = <MealType>{
          for (final e in entries) e.mealType,
          for (final cm in localDaily.customMeals) cm.mealType,
        };
        meals = set.length.clamp(0, 3);
      } catch (_) {
        meals = 0;
      }
    }

    int cf = (_readInt(insight['cfIndex']) ?? 0).clamp(0, 100);
    if (cf <= 0) {
      cf = _daily.computeWeightedCf(
        data: localDaily,
        workoutCompleted: workoutCompleted,
        mealsLoggedCount: meals,
      );
    }

    final moodIcon = (insight['moodIcon'] as String?)?.trim() ?? '';
    final moodValue = (_readInt(insight['moodValue']) ?? localDaily.mood ?? 0)
        .clamp(0, 5);
    final workoutMinutes = max(
      localDaily.activeMinutes,
      _readInt(insight['activeMinutes']) ?? 0,
    );

    final w = waterLiters.isNaN || waterLiters.isInfinite
        ? 0.0
        : (waterLiters < 0 ? 0.0 : waterLiters);
    final waterLabel = w.toStringAsFixed(w >= 10 ? 0 : 1);
    final cleanWorkoutName = workoutName?.trim();
    final workoutLabel = cleanWorkoutName != null && cleanWorkoutName.isNotEmpty
        ? cleanWorkoutName
        : (workoutMinutes > 0 ? '$workoutMinutes min' : 'No entrenado');
    final completionCount = _daily.completionCount(
      data: localDaily,
      workoutCompleted: workoutCompleted,
      mealsLoggedCount: meals,
    );
    final completionTarget = _daily.totalTrackablesCount();
    final goalMet = _didReachDailyGoal(
      completionCount: completionCount,
      completionTarget: completionTarget,
    );

    final parts = <String>[
      'CF $cf',
      'Entreno: $workoutLabel',
      'Pasos: ${steps > 0 ? _formatIntWithDots(steps) : 'Aun sin pasos'}',
      'Agua: ${w > 0 ? '$waterLabel L' : 'Aun sin agua'}',
      'Comidas: $meals/${DailyDataService.mealsTarget}',
    ];

    return (
      summary: parts.join(' · '),
      cf: cf,
      workoutMinutes: workoutMinutes,
      steps: steps,
      waterLiters: w,
      meals: meals,
      moodIcon: moodIcon,
      moodValue: moodValue,
      workoutLabel: workoutLabel,
      workoutName: cleanWorkoutName,
      workoutCompleted: workoutCompleted,
      completionCount: completionCount,
      completionTarget: completionTarget,
      goalMet: goalMet,
    );
  }

  Future<String> _composeDaySummaryForDate(DateTime date) async {
    return (await _composeDaySummaryShareForDate(date)).summary;
  }

  Future<List<CommunityShareOption>> _daySummaryOptions() async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dates = <DateTime>[
      for (var i = 0; i < 7; i++) today.subtract(Duration(days: i)),
    ];

    final out = <CommunityShareOption>[];
    for (final d in dates) {
      final data = await _composeDaySummaryShareForDate(d);
      final summary = data.summary;
      final label = _relativeDayLabel(d, today);
      final dateKey = DateUtilsCF.toKey(d);

      String headline;
      if (label == 'Hoy') {
        headline = 'Mi día en CotidyFit 💪';
      } else if (label == 'Ayer') {
        headline = 'Mi día en CotidyFit 💪';
      } else {
        headline = 'Mi día en CotidyFit 💪';
      }

      final payload = '$headline\n$summary';
      out.add(
        CommunityShareOption(
          id: 'day_$dateKey',
          title: label,
          subtitle: summary,
          payload: payload,
          share: {
            'v': 1,
            'dateKey': dateKey,
            'label': label,
            'summary': summary,
            'cfPoints': data.cf,
            'workoutMinutes': data.workoutMinutes,
            'workoutLabel': data.workoutLabel,
            'workoutName': data.workoutName,
            'steps': data.steps,
            'waterLiters': data.waterLiters,
            'healthyMeals': data.meals,
            'moodIcon': data.moodIcon,
            'moodValue': data.moodValue,
            'workoutCompleted': data.workoutCompleted,
            'completionCount': data.completionCount,
            'completionTarget': data.completionTarget,
            'goalMet': data.goalMet,
          },
        ),
      );
    }
    return out;
  }

  Future<List<CommunityShareOption>> _dietOptions() async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dates = <DateTime>[
      for (var i = 0; i < 7; i++) today.subtract(Duration(days: i)),
    ];

    Map<String, RecipeModel> recipeById = const {};
    try {
      final all = await _recipes.getAllRecipes();
      recipeById = {for (final r in all) r.id: r};
    } catch (_) {
      recipeById = const {};
    }

    final out = <CommunityShareOption>[];
    for (final d in dates) {
      final day = DateUtilsCF.dateOnly(d);
      final dateKey = DateUtilsCF.toKey(day);
      final label = _relativeDayLabel(day, today);

      String summary;
      List<Map<String, Object?>> meals = const [];
      var healthyMeals = 0;
      var kcal = 0;
      var proteinG = 0;
      var carbsG = 0;
      var fatG = 0;
      try {
        final data = await _composeDietShareForDay(day, recipeById: recipeById);
        summary = data.summary;
        meals = data.meals;
        healthyMeals = data.healthyMeals;
        kcal = data.kcal;
        proteinG = data.proteinG;
        carbsG = data.carbsG;
        fatG = data.fatG;
      } catch (_) {
        summary = 'No se pudo cargar la dieta.';
      }

      final hasMeals = meals.isNotEmpty;

      String headline;
      if (label == 'Hoy') {
        headline = 'Mi registro de comidas 🥗';
      } else if (label == 'Ayer') {
        headline = 'Mi registro de comidas 🥗';
      } else {
        headline = 'Mi registro de comidas 🥗';
      }

      final payload = '$headline\n$summary';
      out.add(
        CommunityShareOption(
          id: 'diet_$dateKey',
          title: label,
          subtitle: summary,
          payload: payload,
          share: {
            'v': 1,
            'dateKey': dateKey,
            'label': label,
            'summary': summary,
            'healthyMeals': healthyMeals,
            'kcal': kcal,
            'proteinG': proteinG,
            'carbsG': carbsG,
            'fatG': fatG,
            'goalMet': healthyMeals >= DailyDataService.mealsTarget,
            if (meals.isNotEmpty) 'meals': meals,
          },
        ),
      );
    }
    return out;
  }

  Future<List<CommunityShareOption>> _routineOptions() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final todayKey = DateUtilsCF.toKey(now);
    final from = now.subtract(const Duration(days: 6));

    final out = <CommunityShareOption>[];

    try {
      await _workouts.ensureLoaded();
    } catch (_) {
      // ignore
    }

    Map<String, String> completed = const <String, String>{};
    try {
      completed = await _workoutHistory.getCompletedWorkoutsByDate();
    } catch (_) {
      completed = const <String, String>{};
    }

    Map<String, String> completedIds = const <String, String>{};
    try {
      completedIds = await _workoutHistory.getCompletedWorkoutIdsByDate();
    } catch (_) {
      completedIds = const <String, String>{};
    }

    final completedTodayName = completed[todayKey];
    final hasCompletedToday =
        completedTodayName != null && completedTodayName.trim().isNotEmpty;

    // Option: today's assigned plan.
    if (!hasCompletedToday) {
      try {
        final weekStart = _mondayOf(now);
        final plan = await _workoutPlans.getPlanForWeekKey(
          DateUtilsCF.toKey(weekStart),
        );
        final dayIndex = (now.weekday - DateTime.monday).clamp(0, 6);
        final workoutId = plan?.assignments[dayIndex];
        if (workoutId != null && workoutId.trim().isNotEmpty) {
          final w = _workouts.getWorkoutById(workoutId.trim());
          final name = (w?.name ?? '').trim();
          if (name.isNotEmpty) {
            final payload = 'Rutina de hoy en CotidyFit 💪\nRutina: $name';
            out.add(
              CommunityShareOption(
                id: 'routine_plan_$todayKey',
                title: name,
                subtitle: 'Rutina asignada',
                payload: payload,
                share: {
                  'v': 1,
                  'kind': 'plan',
                  'dateKey': todayKey,
                  'dayLabel': 'Hoy',
                  'workoutId': workoutId.trim(),
                  'workoutName': name,
                  ..._routineShareDataForWorkout(w),
                },
              ),
            );
          }
        }
      } catch (_) {
        // ignore
      }
    }

    // Options: completed workouts in the last 7 days (most recent first).
    if (completed.isNotEmpty) {
      final keys = completed.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in keys) {
        final name = completed[key];
        if (name == null || name.trim().isEmpty) continue;

        final dt = DateUtilsCF.fromKey(key);
        if (dt == null) continue;
        final day = DateUtilsCF.dateOnly(dt);
        if (day.isBefore(from) || day.isAfter(now)) continue;

        final label = _relativeDayLabel(day, now);

        final workoutName = name.trim();
        String headline;
        if (label == 'Hoy') {
          headline = 'Entreno completado en CotidyFit 💪';
        } else if (label == 'Ayer') {
          headline = 'Entreno completado en CotidyFit 💪';
        } else {
          headline = 'Entreno completado en CotidyFit 💪';
        }
        final payload = '$headline\nRutina: $workoutName';

        String? workoutId = completedIds[key];
        if (workoutId != null && workoutId.trim().isEmpty) {
          workoutId = null;
        }

        // Best-effort fallback: match by name if we don't have a stored workoutId.
        if (workoutId == null) {
          try {
            final lower = name.trim().toLowerCase();
            final matched = _findWorkoutByName(lower);
            workoutId = matched?.id;
          } catch (_) {
            // ignore
          }
        }

        final workout = workoutId == null
            ? _findWorkoutByName(workoutName.toLowerCase())
            : _workouts.getWorkoutById(workoutId);

        out.add(
          CommunityShareOption(
            id: 'routine_done_$key',
            title: workoutName,
            subtitle: label,
            payload: payload,
            share: {
              'v': 1,
              'kind': 'completed',
              'dateKey': key,
              'dayLabel': label,
              'workoutName': workoutName,
              'workoutId': workoutId,
              ..._routineShareDataForWorkout(workout),
            },
          ),
        );
      }
    }

    if (out.isEmpty) {
      out.add(
        const CommunityShareOption(
          id: 'routine_fallback',
          title: 'Rutina de hoy',
          subtitle: 'Lista para tu siguiente entreno',
          payload: 'Rutina de hoy en CotidyFit 💪\nRutina: Lista para empezar',
        ),
      );
    }

    return out;
  }

  Future<List<CommunityShareOption>> _achievementOptions() async {
    final items = await _achievements.getAchievementsForCurrentUser();
    final unlocked = items.where((a) => a.user.unlocked).toList();
    if (unlocked.isEmpty) return const <CommunityShareOption>[];

    unlocked.sort((a, b) {
      final ams = a.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      final bms = b.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      return bms.compareTo(ams);
    });

    final out = <CommunityShareOption>[];

    for (final a in unlocked) {
      final title = a.catalog.title.trim().isEmpty
          ? 'Logro desbloqueado'
          : a.catalog.title.trim();
      final desc = a.catalog.description.trim();
      final payload = 'Nuevo logro en CotidyFit 🏆\n$title';
      out.add(
        CommunityShareOption(
          id: 'ach_${a.catalog.id}',
          title: title,
          subtitle: desc.isEmpty ? 'Desbloqueado' : desc,
          payload: payload,
          share: {
            'v': 1,
            'achievementId': a.catalog.id,
            'title': title,
            'description': desc,
            'icon': a.catalog.icon,
            'difficulty': _achievementDifficultyLabel(a.catalog),
            'achievementType': _achievementTypeLabel(a.catalog.category),
            'rarityLabel': _achievementRarityLabel(a.catalog),
            'unlocked': true,
            'progress': a.user.progress,
            'target': a.catalog.conditionValue,
            'pct': 100,
            if (a.user.unlockedAt != null)
              'unlockedAtMs': a.user.unlockedAt!.millisecondsSinceEpoch,
          },
        ),
      );
    }

    return out;
  }

  String _relativeDayLabel(DateTime day, DateTime today) {
    if (DateUtilsCF.isSameDay(day, today)) return 'Hoy';
    if (DateUtilsCF.isYesterdayOf(day, today)) return 'Ayer';
    return _ddMm(day);
  }

  String _ddMm(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Future<String> _composeAchievement() async {
    final items = await _achievements.getAchievementsForCurrentUser();
    if (items.isEmpty) {
      return 'Todavía no he desbloqueado logros para compartir.';
    }

    final unlocked = items.where((a) => a.user.unlocked).toList();
    if (unlocked.isEmpty) {
      return 'Todavía no he desbloqueado logros para compartir.';
    }

    // Prefer the most recent unlocked achievement if timestamps are present.
    unlocked.sort((a, b) {
      final ams = a.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      final bms = b.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      return bms.compareTo(ams);
    });

    final top = unlocked.first;
    final title = top.catalog.title.trim();
    final cleanTitle = title.isEmpty ? 'Logro desbloqueado' : title;
    return 'Nuevo logro en CotidyFit 🏆\n$cleanTitle';
  }

  Future<String> _composeRoutine() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final todayKey = DateUtilsCF.toKey(now);

    String? todayWorkoutName;
    try {
      todayWorkoutName = await _workoutHistory.getCompletedWorkoutName(
        todayKey,
      );
    } catch (_) {
      todayWorkoutName = null;
    }

    if (todayWorkoutName != null && todayWorkoutName.trim().isNotEmpty) {
      return 'Entreno completado en CotidyFit 💪\nRutina: ${todayWorkoutName.trim()}';
    }

    // Try to share today plan assignment.
    try {
      final weekStart = _mondayOf(now);
      final plan = await _workoutPlans.getPlanForWeekKey(
        DateUtilsCF.toKey(weekStart),
      );
      final dayIndex = (now.weekday - DateTime.monday).clamp(0, 6);
      final workoutId = plan?.assignments[dayIndex];
      if (workoutId != null && workoutId.trim().isNotEmpty) {
        await _workouts.ensureLoaded();
        final w = _workouts.getWorkoutById(workoutId.trim());
        if (w != null) {
          return 'Rutina de hoy en CotidyFit 💪\nRutina: ${w.name.trim()}';
        }
        return 'Rutina de hoy en CotidyFit 💪\nRutina: Lista para empezar';
      }
    } catch (_) {
      // ignore
    }

    // Fallback: last completed workout.
    try {
      final completed = await _workoutHistory.getCompletedWorkoutsByDate();
      if (completed.isNotEmpty) {
        final keys = completed.keys.toList()..sort();
        final lastKey = keys.last;
        final lastName = completed[lastKey];
        if (lastName != null && lastName.trim().isNotEmpty) {
          return 'Entreno completado en CotidyFit 💪\nRutina: ${lastName.trim()}';
        }
      }
    } catch (_) {
      // ignore
    }

    return 'Tu siguiente entreno en CotidyFit 💪\nRutina: Lista para empezar';
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateUtilsCF.dateOnly(d);
    final delta = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: delta < 0 ? 0 : delta));
  }

  int? _readInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  String _externalSummaryFor(CommunityShareOption option) {
    final shareSummary = (option.share?['summary'] as String? ?? '').trim();
    if (shareSummary.isNotEmpty) return shareSummary;

    final subtitle = (option.subtitle ?? '').trim();
    if (subtitle.isNotEmpty) return subtitle;

    final lines = option.payload
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length <= 1) {
      return option.payload.trim();
    }

    return lines.skip(1).join(' · ');
  }

  Future<Map<CommunityExternalShareTarget, CommunityExternalShareDraft>>
  composeExternalShareDrafts({
    required MessageType type,
    required CommunityShareOption option,
    Iterable<CommunityExternalShareTarget>? targets,
  }) async {
    final requested = (targets ?? CommunityExternalShareTarget.values).toList(
      growable: false,
    );
    final drafts =
        <CommunityExternalShareTarget, CommunityExternalShareDraft>{};

    for (final target in requested) {
      drafts[target] = await composeExternalShareDraft(
        type: type,
        option: option,
        target: target,
      );
    }

    return drafts;
  }

  Future<CommunityExternalShareDraft> composeExternalShareDraft({
    required MessageType type,
    required CommunityShareOption option,
    required CommunityExternalShareTarget target,
  }) async {
    final resolved = await _templateService.resolve(
      type: type,
      flavor: _templateFlavorForTarget(target),
      replacements: _templateReplacementsFor(type: type, option: option),
      promoUrl: _publicPromoUrl,
    );

    return CommunityExternalShareDraft(
      subject: 'CotidyFit · ${_subjectLabelFor(type)}',
      text: resolved.text.trim(),
      shortPhrase: resolved.shortPhrase.trim(),
    );
  }

  Future<CommunityPreparedExternalShare> prepareExternalShare({
    required MessageType type,
    required CommunityShareOption option,
    required CommunityExternalShareTarget target,
    CommunityExternalShareDraft? draft,
  }) async {
    final resolvedDraft =
        draft ??
        await composeExternalShareDraft(
          type: type,
          option: option,
          target: target,
        );

    final imageBytes = await _cardService.renderCard(
      _buildCardData(
        type: type,
        option: option,
        shortPhrase: resolvedDraft.shortPhrase,
      ),
    );

    return CommunityPreparedExternalShare(
      draft: resolvedDraft,
      imageBytes: imageBytes,
      imageName: _shareImageName(type: type, option: option),
    );
  }

  String _subjectLabelFor(MessageType type) {
    switch (type) {
      case MessageType.daySummary:
        return 'Resumen';
      case MessageType.diet:
        return 'Dieta';
      case MessageType.streaks:
        return 'Rachas';
      case MessageType.routine:
        return 'Rutina';
      case MessageType.achievement:
        return 'Logro';
      case MessageType.text:
        return 'Compartir';
    }
  }

  CommunityShareTemplateFlavor _templateFlavorForTarget(
    CommunityExternalShareTarget target,
  ) {
    switch (target) {
      case CommunityExternalShareTarget.instagramPost:
      case CommunityExternalShareTarget.instagramReel:
        return CommunityShareTemplateFlavor.postReel;
      case CommunityExternalShareTarget.generic:
      case CommunityExternalShareTarget.whatsappChat:
      case CommunityExternalShareTarget.whatsappStatus:
      case CommunityExternalShareTarget.instagramDirect:
      case CommunityExternalShareTarget.instagramStory:
      case CommunityExternalShareTarget.tiktok:
        return CommunityShareTemplateFlavor.storyChat;
    }
  }

  Map<String, String> _templateReplacementsFor({
    required MessageType type,
    required CommunityShareOption option,
  }) {
    final share = option.share ?? const <String, Object?>{};
    final dayLabel = _shareDayLabel(option);
    final cfPoints = _readInt(share['cfPoints']) ?? 0;
    final workoutMinutes = _readInt(share['workoutMinutes']) ?? 0;
    final steps = _readInt(share['steps']) ?? 0;
    final waterLiters = _readDouble(share['waterLiters']) ?? 0.0;
    final healthyMeals = (_readInt(share['healthyMeals']) ?? 0).clamp(
      0,
      DailyDataService.mealsTarget,
    );
    final moodIcon = _shareString(share['moodIcon']);
    final moodValue = _readInt(share['moodValue']) ?? 0;
    final workoutName = _shareString(share['workoutName']);
    final workoutLabel = _workoutShareLabel(share, dayLabel: dayLabel);
    final routineDurationMinutes = _readInt(share['durationMinutes']) ?? 0;
    final routineObjective =
        _nullableText(share['objective']) ?? 'Trabajo completo';
    final routineDifficulty =
        _nullableText(share['difficulty']) ?? 'A tu ritmo';
    final routineDuration = routineDurationMinutes > 0
        ? '$routineDurationMinutes min'
        : 'A tu ritmo';
    final routineDurationIntensity = _durationIntensityLabel(
      durationMinutes: routineDurationMinutes,
      difficulty: _shareString(share['difficulty']),
    );
    final routineMuscle =
        _nullableText(share['muscleGroup']) ?? 'Trabajo general';
    final achievementTitle = _shareString(share['title']).isEmpty
        ? option.title
        : _shareString(share['title']);
    final achievementDescription = _shareString(share['description']).isEmpty
        ? (option.subtitle ?? '').trim()
        : _shareString(share['description']);
    final achievementDifficulty =
        _nullableText(share['difficulty']) ?? 'Personal';
    final achievementType =
        _nullableText(share['achievementType']) ?? 'General';
    final kcal = _readInt(share['kcal']) ?? 0;
    final proteinG = _readInt(share['proteinG']) ?? 0;
    final carbsG = _readInt(share['carbsG']) ?? 0;
    final fatG = _readInt(share['fatG']) ?? 0;
    final goalMet = share['goalMet'] == true;
    final dateLabel = _shareCalendarDateLabel(option);
    final streakTitle = '';
    final streakCurrent = _readInt(share['currentStreak']) ?? 0;
    final streakBest = _readInt(share['maxStreak']) ?? streakCurrent;

    final cfText = '$cfPoints';
    final workoutText = _workoutShareLabel(share, dayLabel: dayLabel);
    final stepsText = _stepsDisplay(steps, dayLabel: dayLabel);
    final waterText = _waterDisplay(waterLiters, dayLabel: dayLabel);
    final kcalText = _formatIntWithDots(kcal);
    final proteinText = '$proteinG';
    final carbsText = '$carbsG';
    final fatText = '$fatG';

    return {
      '[Puntuaje]': cfText,
      '[Puntos CF]': cfText,
      '[Entreno]': workoutText,
      '[Tipo de entreno o "—"]': workoutText,
      '[Número de pasos]': stepsText,
      '[Pasos]': stepsText,
      '[Agua]': waterText,
      '[Litros de agua]': waterText,
      '[Litros]': waterText,
      '[Fecha]': dateLabel,
      '[Comidas saludables completadas]': '$healthyMeals',
      '[Comidas]': '$healthyMeals',
      '[Objetivo diario]': goalMet ? 'Sí' : 'No',
      '[Bueno/Normal/Retador]': '',
      '[Estado]': moodIcon.isNotEmpty
          ? '$moodIcon ${_moodLabel(moodValue: moodValue, moodIcon: moodIcon)}'
          : _moodLabel(moodValue: moodValue, moodIcon: moodIcon),
      '[Emoji]': moodIcon.isEmpty ? 'Sin registrar' : moodIcon,
      '[Nombre de la rutina]': workoutName.isEmpty ? option.title : workoutName,
      '[Objetivo]': routineObjective,
      '[Dificultad]': type == MessageType.achievement
          ? achievementDifficulty
          : routineDifficulty,
      '[Duración]': routineDuration,
      '[Duración/Intensidad]': routineDurationIntensity,
      '[Grupo muscular]': routineMuscle,
      '[Descripción del logro]': achievementDescription.isEmpty
          ? achievementTitle
          : achievementDescription,
      '[Nombre del logro]': achievementTitle,
      '[Tipo]': achievementType,
      '[Tipo de logro]': achievementType,
      '[Objetivo conseguido]': goalMet ? 'Conseguido' : 'En proceso',
      '[Kcal]': kcalText,
      '[Proteínas]': proteinText,
      '[Carbohidratos]': carbsText,
      '[Grasas]': fatText,
      '[Comidas registradas]': '$healthyMeals',
      '[Nombre de la racha]': streakTitle,
      '[Número]': '$streakCurrent',
      '[[RACHA_ACTUAL]]': '$streakCurrent',
      '[[RACHA_MEJOR]]': '$streakBest',
    };
  }

  CommunityShareCardData _buildCardData({
    required MessageType type,
    required CommunityShareOption option,
    required String shortPhrase,
  }) {
    final share = option.share ?? const <String, Object?>{};

    switch (type) {
      case MessageType.routine:
        return _buildRoutineCardData(
          option: option,
          share: share,
          shortPhrase: shortPhrase,
        );
      case MessageType.achievement:
        return _buildAchievementCardData(
          option: option,
          share: share,
          shortPhrase: shortPhrase,
        );
      case MessageType.daySummary:
        return _buildDaySummaryCardData(
          option: option,
          share: share,
          shortPhrase: shortPhrase,
        );
      case MessageType.diet:
        return _buildDietCardData(
          option: option,
          share: share,
          shortPhrase: shortPhrase,
        );
      case MessageType.streaks:
        return _buildStreakCardData(share: share, shortPhrase: shortPhrase);
      case MessageType.text:
        return CommunityShareCardData(
          brandName: 'CotidyFit',
          brandUrl: _compactPromoUrl(),
          logoAssetPath: _brandLogoAsset,
          title: 'Compartir',
          headline: option.title,
          accentColor: _cardAccentFor(type),
          metrics: const <CommunityShareCardMetric>[],
          motivationLabel: '',
          motivation: '',
        );
    }
  }

  CommunityShareCardData _buildRoutineCardData({
    required CommunityShareOption option,
    required Map<String, Object?> share,
    required String shortPhrase,
  }) {
    final isPlan = _shareString(share['kind']) == 'plan';
    final dayLabel = _shareDayLabel(option);
    final workoutName = _shareString(share['workoutName']).isEmpty
        ? option.title
        : _shareString(share['workoutName']);
    final durationMinutes = _readInt(share['durationMinutes']) ?? 0;
    final exerciseCount = _readInt(share['exerciseCount']) ?? 0;
    final difficulty = _nullableText(share['difficulty']);
    final muscleGroup = _nullableText(share['muscleGroup']);
    final insight = _routineInsight(share);
    final volumeLabel = _routineVolumeLabel(
      durationMinutes: durationMinutes,
      exerciseCount: exerciseCount,
    );
    final supportingParts = <String>[
      if (!isPlan) dayLabel,
      if (volumeLabel.isNotEmpty) volumeLabel,
    ];

    return CommunityShareCardData(
      brandName: 'CotidyFit',
      brandUrl: _compactPromoUrl(),
      logoAssetPath: _brandLogoAsset,
      title: isPlan ? 'Rutina lista' : 'Entrenamiento completado',
      headlineLabel: '',
      headline: workoutName,
      headlineSupportingText: supportingParts.join(' · '),
      accentColor: _cardAccentFor(MessageType.routine),
      statusBadge: _routineStatusBadge(share),
      metrics: _collectMetrics(<CommunityShareCardMetric?>[
        durationMinutes > 0
            ? CommunityShareCardMetric(
                icon: Icons.schedule_outlined,
                label: 'Duracion',
                value: '$durationMinutes min',
              )
            : null,
        difficulty == null
            ? null
            : CommunityShareCardMetric(
                icon: Icons.trending_up_outlined,
                label: 'Dificultad',
                value: difficulty,
              ),
        muscleGroup == null
            ? null
            : CommunityShareCardMetric(
                icon: Icons.accessibility_new_outlined,
                label: 'Grupo muscular',
                value: muscleGroup,
              ),
        volumeLabel.isEmpty
            ? null
            : CommunityShareCardMetric(
                icon: Icons.stacked_bar_chart_outlined,
                label: 'Volumen',
                value: volumeLabel,
              ),
        insight.isEmpty
            ? null
            : CommunityShareCardMetric(
                icon: Icons.lightbulb_outline,
                label: 'Insight',
                value: insight,
                columnSpan: 2,
                tone: CommunityShareCardMetricTone.narrative,
              ),
      ]),
      motivationLabel: '',
      motivation: '',
    );
  }

  CommunityShareCardData _buildAchievementCardData({
    required CommunityShareOption option,
    required Map<String, Object?> share,
    required String shortPhrase,
  }) {
    final title = _shareString(share['title']).isEmpty
        ? option.title
        : _shareString(share['title']);
    final description = _nullableText(share['description']);
    final difficulty = _nullableText(share['difficulty']);
    final achievementType = _nullableText(share['achievementType']);
    final rarityLabel =
        _nullableText(share['rarityLabel']) ?? 'Logro conseguido';
    final unlockedAtMs = _readInt(share['unlockedAtMs']) ?? 0;
    final supportingParts = <String>[
      ?achievementType,
      ?difficulty,
      if (unlockedAtMs > 0) _dateLabelFromMs(unlockedAtMs),
    ];

    return CommunityShareCardData(
      brandName: 'CotidyFit',
      brandUrl: _compactPromoUrl(),
      logoAssetPath: _brandLogoAsset,
      title: 'Logro conseguido',
      headlineLabel: '',
      headline: title,
      headlineSupportingText: supportingParts.join(' · '),
      accentColor: _cardAccentFor(MessageType.achievement),
      statusBadge: rarityLabel,
      metrics: _collectMetrics(<CommunityShareCardMetric?>[
        difficulty == null
            ? null
            : CommunityShareCardMetric(
                icon: Icons.workspace_premium_outlined,
                label: 'Dificultad',
                value: difficulty,
              ),
        achievementType == null
            ? null
            : CommunityShareCardMetric(
                icon: Icons.category_outlined,
                label: 'Tipo',
                value: achievementType,
              ),
        description == null
            ? null
            : CommunityShareCardMetric(
                icon: Icons.notes_outlined,
                label: 'Que significa',
                value: description,
                columnSpan: 2,
                tone: CommunityShareCardMetricTone.narrative,
              ),
      ]),
      motivationLabel: '',
      motivation: '',
    );
  }

  CommunityShareCardData _buildDaySummaryCardData({
    required CommunityShareOption option,
    required Map<String, Object?> share,
    required String shortPhrase,
  }) {
    final cfPoints = _readInt(share['cfPoints']) ?? 0;
    final dayLabel = _shareDayLabel(option);
    final steps = _readInt(share['steps']) ?? 0;
    final waterLiters = _readDouble(share['waterLiters']) ?? 0;
    final workoutMinutes = _readInt(share['workoutMinutes']) ?? 0;
    final completionCount = _readInt(share['completionCount']) ?? 0;
    final completionTarget = _readInt(share['completionTarget']) ?? 0;
    final healthyMeals = (_readInt(share['healthyMeals']) ?? 0).clamp(
      0,
      DailyDataService.mealsTarget,
    );
    final goalMet = share['goalMet'] == true;
    final summaryInsight = _daySummaryInsight(
      steps: steps,
      waterLiters: waterLiters,
      goalMet: goalMet,
      healthyMeals: healthyMeals,
      workoutMinutes: workoutMinutes,
      cfPoints: cfPoints,
    );
    final progressText = completionTarget > 0
        ? '$completionCount/$completionTarget hábitos completados'
        : (goalMet
              ? 'Objetivo del día conseguido'
              : 'Todavía puedes mejorar este día');

    return CommunityShareCardData(
      brandName: 'CotidyFit',
      brandUrl: _compactPromoUrl(),
      logoAssetPath: _brandLogoAsset,
      title: 'Resumen de mi dia en CotidyFit',
      headlineLabel: dayLabel == 'Hoy'
          ? 'Puntuación del día'
          : 'Puntuación de $dayLabel',
      headline: '$cfPoints puntos',
      headlineSupportingText: '',
      accentColor: _cardAccentFor(MessageType.daySummary),
      statusBadge: summaryInsight,
      metrics: _collectMetrics(<CommunityShareCardMetric?>[
        CommunityShareCardMetric(
          icon: Icons.timer_outlined,
          label: 'Entreno',
          value: _workoutShareLabel(share, dayLabel: dayLabel),
        ),
        CommunityShareCardMetric(
          icon: Icons.directions_walk_outlined,
          label: 'Pasos',
          value: _stepsDisplay(steps, dayLabel: dayLabel),
        ),
        CommunityShareCardMetric(
          icon: Icons.water_drop_outlined,
          label: 'Agua',
          value: _waterDisplay(waterLiters, dayLabel: dayLabel),
        ),
        CommunityShareCardMetric(
          icon: Icons.restaurant_outlined,
          label: 'Comidas',
          value: '$healthyMeals/${DailyDataService.mealsTarget}',
        ),
        CommunityShareCardMetric(
          icon: Icons.insights_outlined,
          label: 'Balance del dia',
          value: progressText,
          columnSpan: 2,
          tone: CommunityShareCardMetricTone.narrative,
        ),
      ]),
      motivationLabel: '',
      motivation: '',
    );
  }

  CommunityShareCardData _buildDietCardData({
    required CommunityShareOption option,
    required Map<String, Object?> share,
    required String shortPhrase,
  }) {
    final healthyMeals = (_readInt(share['healthyMeals']) ?? 0).clamp(
      0,
      DailyDataService.mealsTarget,
    );
    final kcal = _readInt(share['kcal']) ?? 0;
    final proteinG = _readInt(share['proteinG']) ?? 0;
    final carbsG = _readInt(share['carbsG']) ?? 0;
    final fatG = _readInt(share['fatG']) ?? 0;
    final mealsSummary = _dietMealsSummary(option);
    final dietBadge = healthyMeals >= DailyDataService.mealsTarget
        ? 'Día completo registrado'
        : 'Registro en marcha';

    return CommunityShareCardData(
      brandName: 'CotidyFit',
      brandUrl: _compactPromoUrl(),
      logoAssetPath: _brandLogoAsset,
      title: 'Mi registro de comidas del ${_shareCalendarDateLabel(option)}',
      headlineLabel: 'Comidas registradas',
      headline: '$healthyMeals/${DailyDataService.mealsTarget} comidas',
      headlineSupportingText: mealsSummary.isNotEmpty
          ? mealsSummary
          : 'Tu alimentacion del dia',
      accentColor: _cardAccentFor(MessageType.diet),
      statusBadge: dietBadge,
      metrics: <CommunityShareCardMetric>[
        CommunityShareCardMetric(
          icon: Icons.local_fire_department_outlined,
          label: 'Kcal',
          value: '${_formatIntWithDots(kcal)} kcal',
        ),
        CommunityShareCardMetric(
          icon: Icons.bolt_outlined,
          label: 'Proteinas',
          value: _gramsDisplay(proteinG),
        ),
        CommunityShareCardMetric(
          icon: Icons.grain_outlined,
          label: 'Carbohidratos',
          value: _gramsDisplay(carbsG),
        ),
        CommunityShareCardMetric(
          icon: Icons.opacity_outlined,
          label: 'Grasas',
          value: _gramsDisplay(fatG),
        ),
      ],
      notesTitle: 'Comidas del día',
      notes: _dietMealLines(option),
      motivationLabel: '',
      motivation: '',
    );
  }

  CommunityShareCardData _buildStreakCardData({
    required Map<String, Object?> share,
    required String shortPhrase,
  }) {
    final current = _readInt(share['currentStreak']) ?? 0;
    final best = _readInt(share['maxStreak']) ?? current;
    final avgSteps = _readInt(share['avgSteps']) ?? 0;
    final avgWaterLiters = _readDouble(share['avgWaterLiters']) ?? 0.0;
    final avgCf = _readInt(share['avgCfPoints']) ?? 0;
    final workoutsPerWeek = _readInt(share['workoutsPerWeek']) ?? 0;
    final healthyDays = _readInt(share['healthyDays']) ?? 0;
    final goalDays = _readInt(share['goalDays']) ?? 0;
    final streakBadge = current <= 0
        ? 'Constancia en marcha'
        : _streakStatusBadge(current);
    final weeklySummary =
        '$workoutsPerWeek entrenos · $healthyDays/7 días saludables · $goalDays/7 objetivos';

    return CommunityShareCardData(
      brandName: 'CotidyFit',
      brandUrl: _compactPromoUrl(),
      logoAssetPath: _brandLogoAsset,
      title: 'Mi racha en CotidyFit',
      headlineLabel: 'Racha actual',
      headline: current <= 0 ? 'Hoy empiezas' : '$current días',
      headlineSupportingText: current <= 0
          ? 'Una nueva racha empieza con este día.'
          : 'Tu mejor racha: $best días',
      accentColor: _cardAccentFor(MessageType.streaks),
      statusBadge: streakBadge,
      metrics: <CommunityShareCardMetric>[
        CommunityShareCardMetric(
          icon: Icons.workspace_premium_outlined,
          label: 'Racha actual',
          value: current <= 0 ? '0 días' : '$current días',
        ),
        CommunityShareCardMetric(
          icon: Icons.auto_graph_outlined,
          label: 'Media CF',
          value: '$avgCf',
        ),
        CommunityShareCardMetric(
          icon: Icons.directions_walk_outlined,
          label: 'Media pasos',
          value: _formatIntWithDots(avgSteps),
        ),
        CommunityShareCardMetric(
          icon: Icons.water_drop_outlined,
          label: 'Media agua',
          value: '${_waterLabel(avgWaterLiters)} L',
        ),
        CommunityShareCardMetric(
          icon: Icons.insights_outlined,
          label: 'Últimos 7 días',
          value: weeklySummary,
          columnSpan: 2,
          tone: CommunityShareCardMetricTone.narrative,
        ),
      ],
      motivationLabel: '',
      motivation: '',
    );
  }

  List<CommunityShareCardMetric> _collectMetrics(
    List<CommunityShareCardMetric?> metrics,
  ) {
    return metrics.whereType<CommunityShareCardMetric>().toList(
      growable: false,
    );
  }

  String? _nullableText(Object? value) {
    final text = _shareString(value);
    return text.isEmpty ? null : text;
  }

  String _routineInsight(Map<String, Object?> share) {
    final muscle = _shareString(share['muscleGroup']).toLowerCase();
    final difficulty = _shareString(share['difficulty']).toLowerCase();
    final objective = _shareString(share['objective']).toLowerCase();
    final durationMinutes = _readInt(share['durationMinutes']) ?? 0;
    final exerciseCount = _readInt(share['exerciseCount']) ?? 0;

    if (muscle.contains('pierna') || muscle.contains('glute')) {
      return 'Entrenamiento centrado en tren inferior.';
    }
    if (muscle.contains('pecho') ||
        muscle.contains('espalda') ||
        muscle.contains('hombro') ||
        muscle.contains('bice') ||
        muscle.contains('trice')) {
      return 'Trabajo enfocado en tren superior.';
    }
    if (muscle.contains('abdomen') || muscle.contains('core')) {
      return 'Sesion centrada en core y estabilidad.';
    }
    if (objective.contains('cardio')) {
      return 'Sesion pensada para subir pulsaciones y activar el cardio.';
    }
    if (objective.contains('movilidad') || objective.contains('flexibilidad')) {
      return 'Buen bloque para ganar movilidad y soltar el cuerpo.';
    }
    if (difficulty.contains('experto') || durationMinutes >= 45) {
      return 'Alta intensidad para un dia de empuje fuerte.';
    }
    if (exerciseCount >= 8 || durationMinutes >= 30) {
      return 'Buen volumen de trabajo para una sesion completa.';
    }
    if (difficulty.contains('moderado')) {
      return 'Intensidad media para mantener el ritmo con buena tecnica.';
    }
    if (difficulty.contains('leve')) {
      return 'Sesion accesible para sumar constancia sin sobrecargarte.';
    }
    if (objective.isNotEmpty) {
      return 'Entrenamiento orientado a ${_shareString(share['objective'])}.';
    }
    if (durationMinutes > 0) {
      return 'Sesion pensada para seguir sumando minutos de calidad.';
    }
    return '';
  }

  String _routineStatusBadge(Map<String, Object?> share) {
    final difficulty = _shareString(share['difficulty']).toLowerCase();
    final durationMinutes = _readInt(share['durationMinutes']) ?? 0;
    final exerciseCount = _readInt(share['exerciseCount']) ?? 0;
    if (difficulty.contains('experto') || durationMinutes >= 45) {
      return 'Alta intensidad';
    }
    if (difficulty.contains('leve')) return 'Sesión ligera';
    if (exerciseCount >= 8 || durationMinutes >= 30) return 'Buen volumen';
    return 'Constancia en marcha';
  }

  String _routineVolumeLabel({
    required int durationMinutes,
    required int exerciseCount,
  }) {
    if (exerciseCount > 0 && durationMinutes > 0) {
      return '$exerciseCount ejercicios · $durationMinutes min';
    }
    if (exerciseCount > 0) return '$exerciseCount ejercicios';
    if (durationMinutes > 0) return '$durationMinutes min';
    return '';
  }

  String _daySummaryInsight({
    required int steps,
    required double waterLiters,
    required bool goalMet,
    required int healthyMeals,
    required int workoutMinutes,
    required int cfPoints,
  }) {
    if (goalMet && cfPoints >= 70) return 'Buen progreso';
    if (waterLiters <= 0.3) return 'Día bajo en hidratación';
    if (steps >= DailyDataService.stepsTarget) return 'Buen progreso en pasos';
    if (workoutMinutes > 0 && healthyMeals >= 2) return 'Balance sólido';
    if (cfPoints <= 35) return 'Balance mejorable';
    return 'Constancia en marcha';
  }

  String _streakStatusBadge(int current) {
    if (current >= 21) return 'Gran constancia';
    if (current >= 7) return 'Muy buen ritmo';
    if (current >= 3) return 'Constancia en marcha';
    return 'Buen comienzo';
  }

  Color _cardAccentFor(MessageType type) {
    switch (type) {
      case MessageType.routine:
        return const Color(0xFF3763A6);
      case MessageType.achievement:
        return const Color(0xFFBE7A1A);
      case MessageType.daySummary:
        return const Color(0xFF29836B);
      case MessageType.diet:
        return const Color(0xFF8F5A2A);
      case MessageType.streaks:
        return const Color(0xFFC44B2C);
      case MessageType.text:
        return const Color(0xFF36506C);
    }
  }

  String _dietCardTitle(CommunityShareOption option) {
    return 'Dieta del día ${_shareCalendarDateLabel(option)}';
  }

  String _dietMealsSummary(CommunityShareOption option) {
    final names = <String>[];
    final rawMeals = option.share?['meals'];
    if (rawMeals is! List) return '';

    for (final raw in rawMeals) {
      if (raw is! Map) continue;
      final meal = <String, Object?>{
        for (final entry in raw.entries) entry.key.toString(): entry.value,
      };

      final recipes = meal['recipes'];
      if (recipes is List) {
        for (final rawRecipe in recipes) {
          if (rawRecipe is! Map) continue;
          final name = _shareString(rawRecipe['name']);
          if (name.isNotEmpty && !names.contains(name)) names.add(name);
        }
      }

      final customMeals = meal['customMeals'];
      if (customMeals is List) {
        for (final rawCustomMeal in customMeals) {
          if (rawCustomMeal is! Map) continue;
          final name = _shareString(rawCustomMeal['nombre']);
          if (name.isNotEmpty && !names.contains(name)) names.add(name);
        }
      }
    }

    if (names.isEmpty) return '';
    final visible = names.take(3).toList(growable: true);
    if (names.length > 3) {
      visible.add('+${names.length - 3}');
    }
    return visible.join(', ');
  }

  List<String> _dietMealLines(CommunityShareOption option) {
    final rawMeals = option.share?['meals'];
    final labels = <String>['Desayuno', 'Comida', 'Merienda', 'Cena'];
    final values = <String, String>{};

    if (rawMeals is List) {
      for (final raw in rawMeals) {
        if (raw is! Map) continue;
        final casted = <String, Object?>{
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        };
        final label = _shareString(casted['label']);
        if (label.isEmpty) continue;
        values[label] = _mealItemsLabel(casted);
      }
    }

    return [
      for (final label in labels)
        if ((values[label] ?? '').trim().isNotEmpty)
          '$label · ${values[label]!.trim()}',
    ];
  }

  String _mealItemsLabel(Map<String, Object?> meal) {
    final names = <String>[];

    final recipes = meal['recipes'];
    if (recipes is List) {
      for (final rawRecipe in recipes) {
        if (rawRecipe is! Map) continue;
        final name = _shareString(rawRecipe['name']);
        if (name.isNotEmpty) names.add(name);
      }
    }

    final customMeals = meal['customMeals'];
    if (customMeals is List) {
      for (final rawCustomMeal in customMeals) {
        if (rawCustomMeal is! Map) continue;
        final name = _shareString(rawCustomMeal['nombre']);
        if (name.isNotEmpty) names.add(name);
      }
    }

    if (names.isEmpty) return '';
    final visible = names.take(2).toList(growable: true);
    if (names.length > 2) {
      visible.add('+${names.length - 2}');
    }
    return visible.join(', ');
  }

  String _shareImageName({
    required MessageType type,
    required CommunityShareOption option,
  }) {
    final safeId = option.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return 'cotidyfit_${type.name}_$safeId.png';
  }

  String _shareDayLabel(CommunityShareOption option) {
    final label = (option.share?['label'] as String? ?? '').trim();
    if (label.isNotEmpty) return label;
    return option.title.trim().isEmpty ? 'Hoy' : option.title.trim();
  }

  String _shareCalendarDateLabel(CommunityShareOption option) {
    final dateKey = _shareString(option.share?['dateKey']);
    if (RegExp(r'^\d{8}$').hasMatch(dateKey)) {
      final year = int.tryParse(dateKey.substring(0, 4));
      final month = int.tryParse(dateKey.substring(4, 6));
      final day = int.tryParse(dateKey.substring(6, 8));
      if (year != null && month != null && day != null) {
        final shortYear = (year % 100).toString().padLeft(2, '0');
        return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$shortYear';
      }
    }
    return _shareDayLabel(option);
  }

  String _dateLabelFromMs(int millisecondsSinceEpoch) {
    final date = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$shortYear';
  }

  String _workoutShareLabel(Map<String, Object?> share, {String? dayLabel}) {
    final explicit = _shareString(share['workoutLabel']);
    if (explicit.isNotEmpty) return explicit;

    final workoutName = _shareString(share['workoutName']);
    if (workoutName.isNotEmpty) return workoutName;

    final workoutMinutes = _readInt(share['workoutMinutes']) ?? 0;
    if (workoutMinutes > 0) return '$workoutMinutes min';

    if (dayLabel == 'Hoy') return 'Hoy no has entrenado';
    if (dayLabel == 'Ayer') return 'Ayer no entrenaste';
    return 'Ese día no entrenaste';
  }

  String _durationLabel(int minutes) {
    if (minutes <= 0) return '';
    return '$minutes min';
  }

  String _durationIntensityLabel({
    required int durationMinutes,
    required String difficulty,
  }) {
    final duration = _durationLabel(durationMinutes);
    if (duration.isNotEmpty && difficulty.trim().isNotEmpty) {
      return '$duration · $difficulty';
    }
    if (difficulty.trim().isNotEmpty) return difficulty.trim();
    if (duration.isNotEmpty) return duration;
    return 'A tu ritmo';
  }

  String _waterLabel(double liters) {
    final safeValue = liters.isNaN || liters.isInfinite
        ? 0.0
        : liters.clamp(0.0, 999.0);
    return safeValue.toStringAsFixed(safeValue >= 10 ? 0 : 1);
  }

  String _dayToneLabel({
    required int cfPoints,
    required int moodValue,
    required int workoutMinutes,
  }) {
    final adjusted =
        cfPoints + (moodValue >= 4 ? 8 : 0) + (workoutMinutes > 0 ? 6 : 0);
    if (adjusted >= 75) return 'Bueno';
    if (adjusted >= 40) return 'Normal';
    return 'Retador';
  }

  String _moodLabel({required int moodValue, required String moodIcon}) {
    if (moodValue >= 4) return 'Contento';
    if (moodValue == 3) return 'Neutral';
    if (moodValue > 0) return 'Bajo';
    if (moodIcon == '😄' || moodIcon == '🙂' || moodIcon == ':D') {
      return 'Contento';
    }
    if (moodIcon == '😐') return 'Neutral';
    if (moodIcon == '🙁') return 'Bajo';
    if (moodIcon == '😩') return 'Cansado';
    return 'Sin registrar';
  }

  String _compactPromoUrl() {
    final uri = Uri.tryParse(_publicPromoUrl.trim());
    final host = (uri?.host ?? '').trim();
    if (host.isNotEmpty) {
      return host.startsWith('www.') ? host.substring(4) : host;
    }
    return _publicPromoUrl
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  String _shareString(Object? value) {
    return value == null ? '' : value.toString().trim();
  }

  String _textOr(Object? value, {required String fallback}) {
    final text = _shareString(value);
    return text.isEmpty ? fallback : text;
  }

  bool _didReachDailyGoal({
    required int completionCount,
    required int completionTarget,
  }) {
    if (completionTarget <= 0) return false;
    return completionCount >= ((completionTarget + 1) ~/ 2);
  }

  String _stepsDisplay(int steps, {String? dayLabel}) {
    if (steps <= 0) {
      if (dayLabel == 'Hoy') return 'Todavía no has dado pasos';
      if (dayLabel == 'Ayer') return 'Ayer no registraste pasos';
      return 'Ese día no registraste pasos';
    }
    return _formatIntWithDots(steps);
  }

  String _waterDisplay(double liters, {String? dayLabel}) {
    if (liters <= 0) {
      if (dayLabel == 'Hoy') return 'Todavía no has bebido agua';
      if (dayLabel == 'Ayer') return 'Ayer no registraste agua';
      return 'Ese día no registraste agua';
    }
    return '${_waterLabel(liters)} L';
  }

  String _gramsDisplay(int grams) {
    if (grams <= 0) return '0 g';
    return '$grams g';
  }

  String _formatIntWithDots(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  Workout? _findWorkoutByName(String lowerName) {
    final query = lowerName.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final workout in _workouts.getAllWorkouts()) {
      if (workout.name.trim().toLowerCase() == query) {
        return workout;
      }
    }

    return null;
  }

  Map<String, Object?> _routineShareDataForWorkout(Workout? workout) {
    if (workout == null) return const <String, Object?>{};
    return {
      'objective': _workoutGoalLabel(workout),
      'difficulty': workout.difficulty.label,
      'durationMinutes': workout.durationMinutes,
      'muscleGroup': _workoutMuscleLabel(workout),
      'exerciseCount': workout.exercises.length,
    };
  }

  String _workoutGoalLabel(Workout workout) {
    if (workout.goals.isNotEmpty) return workout.goals.first.label;
    if (workout.category.trim().isNotEmpty) return workout.category.trim();
    if (workout.level.trim().isNotEmpty) return workout.level.trim();
    return 'General';
  }

  String _workoutMuscleLabel(Workout workout) {
    final labels =
        workout.muscleGroups
            .map((group) => group.label)
            .where((label) => label.trim().isNotEmpty)
            .toList()
          ..sort();
    if (labels.isEmpty) return 'Full body';
    if (labels.length == 1) return labels.first;
    return '${labels.first} · ${labels[1]}';
  }

  String _achievementDifficultyLabel(AchievementCatalogItem item) {
    switch (item.difficulty.trim().toLowerCase()) {
      case 'easy':
        return 'Fácil';
      case 'medium':
        return 'Media';
      case 'hard':
        return 'Difícil';
    }

    final target = item.conditionValue;
    if (target >= 30) return 'Difícil';
    if (target >= 10) return 'Media';
    return 'Fácil';
  }

  String _achievementRarityLabel(AchievementCatalogItem item) {
    final difficulty = _achievementDifficultyLabel(item);
    if (difficulty == 'Difícil') return 'Logro poco común';
    if (difficulty == 'Media') return 'Logro con mérito';
    if (item.conditionValue >= 5) return 'Buen hito';
    return 'Buen comienzo';
  }

  String _achievementTypeLabel(String rawCategory) {
    switch (rawCategory.trim().toLowerCase()) {
      case 'progreso':
        return 'Progreso';
      case 'racha':
      case 'rachas':
        return 'Constancia';
      case 'nutricion':
      case 'nutrición':
        return 'Nutrición';
      case 'entreno':
      case 'workout':
      case 'training':
        return 'Entrenamiento';
      default:
        final text = rawCategory.trim();
        if (text.isEmpty) return 'General';
        return text[0].toUpperCase() + text.substring(1);
    }
  }

  double? _readDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) {
      final normalized = v.trim().replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }
}
