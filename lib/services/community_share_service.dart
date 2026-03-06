import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/message_model.dart';
import '../models/recipe_model.dart';
import '../services/achievements_service.dart';
import '../services/daily_data_service.dart';
import '../services/home_dashboard_service.dart';
import '../services/local_storage_service.dart';
import '../services/my_day_repository.dart';
import '../services/my_day_repository_factory.dart';
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

class CommunityShareService {
  CommunityShareService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    LocalStorageService? storage,
    DailyDataService? daily,
    HomeDashboardService? dashboard,
    WorkoutHistoryService? workoutHistory,
    WorkoutPlanService? workoutPlans,
    WorkoutService? workouts,
    MyDayRepository? myDay,
    RecipeRepository? recipes,
    AchievementsService? achievements,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? LocalStorageService(),
       _daily = daily ?? DailyDataService(),
       _dashboard = dashboard ?? HomeDashboardService(),
       _workoutHistory = workoutHistory ?? WorkoutHistoryService(),
       _workoutPlans = workoutPlans ?? WorkoutPlanService(),
       _workouts = workouts ?? WorkoutService(),
       _myDay = myDay ?? MyDayRepositoryFactory.create(),
       _recipes = recipes ?? RecipesRepositoryFactory.create(),
       _achievements = achievements ?? AchievementsService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final LocalStorageService _storage;
  final DailyDataService _daily;
  final HomeDashboardService _dashboard;
  final WorkoutHistoryService _workoutHistory;
  final WorkoutPlanService _workoutPlans;
  final WorkoutService _workouts;
  final MyDayRepository _myDay;
  final RecipeRepository _recipes;
  final AchievementsService _achievements;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;
  String? get _uid => _firebaseReady ? _auth.currentUser?.uid : null;

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
        final payload = '¡Observa mis rachas!\n$summary';
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

    final currentStreak = await _storage.getStreakCount();

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

    final maxStreak = max(existingMaxStreak, currentStreak);

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
          final isActive =
              d['workoutCompleted'] == true ||
              (_readInt(d['steps']) ?? 0) >= 4000 ||
              (_readInt(d['mealsLoggedCount']) ?? 0) >= 2 ||
              (_readInt(d['meditationMinutes']) ?? 0) >= 5 ||
              (_readInt(d['cfIndex']) ?? 0) >= 55;
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

  Future<({int current, int best, String text})> _composeStreaksData() async {
    final uid = _uid;

    final current = await _storage.getStreakCount();

    int best = current;
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
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore
      }
    }

    return (
      current: current,
      best: best,
      text: 'Racha actual: $current días · Racha máx: $best días',
    );
  }

  Future<String> _composeStreaks() async {
    final summary = (await _composeStreaksData()).text;
    return '¡Observa mis rachas!\n$summary';
  }

  Future<String> _composeDiet() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final data = await _composeDietShareForDay(now);
    final headline =
        data.meals.isNotEmpty ? '¡Hoy he comido esto!' : '¡Mira mi dieta de hoy!';
    return '$headline\n${data.summary}';
  }

  Future<({String summary, List<Map<String, Object?>> meals})>
  _composeDietShareForDay(
    DateTime day, {
    Map<String, String> recipeNameById = const {},
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

    final today = DateUtilsCF.dateOnly(DateTime.now());
    final label = _relativeDayLabel(day, today);

    String summary;
    if (counts.isEmpty) {
      if (label == 'Hoy') {
        summary = 'Todavía no he registrado comidas.';
      } else {
        summary = 'No registré comidas.';
      }
    } else {
      final uniqueMeals = counts.keys.length;
      final totalItems = counts.values.fold<int>(0, (acc, v) => acc + v);

      final labels = counts.keys.map((m) => m.label).toList()..sort();
      final mealsLabel = labels.join(', ');

      summary = '$uniqueMeals comidas ($mealsLabel) · $totalItems registros';
    }

    final meals = <Map<String, Object?>>[];
    for (final meal in MealType.values) {
      final recipeIds = recipeIdsByMeal[meal] ?? const <String>[];
      final customMeals =
          customMealsByMeal[meal] ?? const <Map<String, Object?>>[];
      if (recipeIds.isEmpty && customMeals.isEmpty) continue;

      final recipes = <Map<String, Object?>>[
        for (final id in recipeIds)
          {'id': id, 'name': (recipeNameById[id] ?? '').trim()},
      ];

      meals.add({
        'mealType': meal.name,
        'label': meal.label,
        'recipes': recipes,
        'customMeals': customMeals,
        'count': recipeIds.length + customMeals.length,
      });
    }

    return (summary: summary, meals: meals);
  }

  Future<String> _composeDaySummary() async {
    final now = DateUtilsCF.dateOnly(DateTime.now());
    final summary = await _composeDaySummaryForDate(now);
    return '¡Observa mi resumen del día!\n$summary';
  }

  Future<String> _composeDaySummaryForDate(DateTime date) async {
    final uid = _uid;
    final day = DateUtilsCF.dateOnly(date);
    final key = DateUtilsCF.toKey(day);

    // Always read local daily data.
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

    // Meals: prefer dailyStats if it has a value; otherwise compute from MyDay + custom meals.
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

    final w = waterLiters.isNaN || waterLiters.isInfinite
        ? 0.0
        : (waterLiters < 0 ? 0.0 : waterLiters);
    final waterLabel = w.toStringAsFixed(w >= 10 ? 0 : 1);

    final workoutLabel = workoutCompleted ? '✅' : '—';

    final parts = <String>[
      if (moodIcon.isNotEmpty) moodIcon,
      'CF $cf',
      'Entreno $workoutLabel',
      '$steps pasos',
      '$waterLabel L agua',
      '$meals/${DailyDataService.mealsTarget} comidas',
    ];

    // If we have a workout name, make it explicit.
    if (workoutName != null && workoutName.trim().isNotEmpty) {
      parts.add('Rutina: ${workoutName.trim()}');
    }

    return parts.join(' · ');
  }

  Future<List<CommunityShareOption>> _daySummaryOptions() async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dates = <DateTime>[
      for (var i = 0; i < 7; i++) today.subtract(Duration(days: i)),
    ];

    final out = <CommunityShareOption>[];
    for (final d in dates) {
      final summary = await _composeDaySummaryForDate(d);
      final label = _relativeDayLabel(d, today);
      final dateKey = DateUtilsCF.toKey(d);

      String headline;
      if (label == 'Hoy') {
        headline = '¡Observa mi resumen de hoy!';
      } else if (label == 'Ayer') {
        headline = '¡Observa mi resumen de ayer!';
      } else {
        headline = '¡Observa mi resumen del día $label!';
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

    Map<String, String> recipeNameById = const {};
    try {
      final all = await _recipes.getAllRecipes();
      recipeNameById = {for (final r in all) r.id: r.name};
    } catch (_) {
      recipeNameById = const {};
    }

    final out = <CommunityShareOption>[];
    for (final d in dates) {
      final day = DateUtilsCF.dateOnly(d);
      final dateKey = DateUtilsCF.toKey(day);
      final label = _relativeDayLabel(day, today);

      String summary;
      List<Map<String, Object?>> meals = const [];
      try {
        final data = await _composeDietShareForDay(
          day,
          recipeNameById: recipeNameById,
        );
        summary = data.summary;
        meals = data.meals;
      } catch (_) {
        summary = 'No se pudo cargar la dieta.';
      }

      final hasMeals = meals.isNotEmpty;

      String headline;
      if (label == 'Hoy') {
        headline = hasMeals ? '¡Hoy he comido esto!' : '¡Mira mi dieta de hoy!';
      } else if (label == 'Ayer') {
        headline = hasMeals
            ? '¡Ayer comí esto!'
            : '¡Mira mi dieta de ayer!';
      } else {
        headline = hasMeals
            ? '¡El $label comí esto!'
            : '¡Mira mi dieta del $label!';
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
          await _workouts.ensureLoaded();
          final w = _workouts.getWorkoutById(workoutId.trim());
          final name = (w?.name ?? '').trim();
          if (name.isNotEmpty) {
            final payload = '¡Mira qué entreno me toca hoy!\n$name';
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
          headline = '¡Mira qué entreno hice hoy!';
        } else if (label == 'Ayer') {
          headline = '¡Mira qué entreno hice ayer!';
        } else {
          headline = '¡Mira qué entreno hice el $label!';
        }
        final payload = '$headline\n$workoutName';

        String? workoutId = completedIds[key];
        if (workoutId != null && workoutId.trim().isEmpty) {
          workoutId = null;
        }

        // Best-effort fallback: match by name if we don't have a stored workoutId.
        if (workoutId == null) {
          try {
            await _workouts.ensureLoaded();
            final lower = name.trim().toLowerCase();
            // Avoid importing extra helpers; keep it simple.
            for (final w in _workouts.getAllWorkouts()) {
              if (w.name.trim().toLowerCase() == lower) {
                workoutId = w.id;
                break;
              }
            }
          } catch (_) {
            // ignore
          }
        }

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
            },
          ),
        );
      }
    }

    if (out.isEmpty) {
      out.add(
        const CommunityShareOption(
          id: 'routine_fallback',
          title: 'Rutina',
          subtitle: 'Sin datos',
          payload: '¡Hoy toca moverse!',
        ),
      );
    }

    return out;
  }

  Future<List<CommunityShareOption>> _achievementOptions() async {
    final items = await _achievements.getAchievementsForCurrentUser();
    if (items.isEmpty) {
      return const [
        CommunityShareOption(
          id: 'ach_fallback',
          title: 'Logros',
          subtitle: 'Sin datos',
          payload: '¡Estoy trabajando en mis logros!',
        ),
      ];
    }

    final unlocked = items.where((a) => a.user.unlocked).toList();
    unlocked.sort((a, b) {
      final ams = a.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      final bms = b.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
      return bms.compareTo(ams);
    });

    final inProgress = items.where((a) => !a.user.unlocked).toList();
    inProgress.sort((a, b) => b.progressRatio.compareTo(a.progressRatio));

    final out = <CommunityShareOption>[];

    for (final a in unlocked) {
      final title = a.catalog.title.trim().isEmpty
          ? 'Logro desbloqueado'
          : a.catalog.title.trim();
      final desc = a.catalog.description.trim();
      final payload = '¡He obtenido un logro nuevo!\n$title';
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

    for (final a in inProgress) {
      final title = a.catalog.title.trim().isEmpty
          ? 'Logro'
          : a.catalog.title.trim();
      final pct = (a.progressRatio * 100).round().clamp(0, 100);
      final payload = '¡Estoy avanzando en un logro!\n$title ($pct%)';
      out.add(
        CommunityShareOption(
          id: 'ach_${a.catalog.id}',
          title: title,
          subtitle: 'En progreso · $pct%',
          payload: payload,
          share: {
            'v': 1,
            'achievementId': a.catalog.id,
            'title': title,
            'description': a.catalog.description.trim(),
            'icon': a.catalog.icon,
            'unlocked': false,
            'progress': a.user.progress,
            'target': a.catalog.conditionValue,
            'pct': pct,
          },
        ),
      );
    }

    return out.isEmpty
        ? const [
            CommunityShareOption(
              id: 'ach_fallback2',
              title: 'Logros',
              subtitle: 'Sin datos',
              payload: '¡Estoy trabajando en mis logros!',
            ),
          ]
        : out;
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
    if (items.isEmpty) return '¡Estoy trabajando en mis logros!';

    final unlocked = items.where((a) => a.user.unlocked).toList();

    // Prefer the most recent unlocked achievement if timestamps are present.
    if (unlocked.isNotEmpty) {
      unlocked.sort((a, b) {
        final ams = a.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
        final bms = b.user.unlockedAt?.millisecondsSinceEpoch ?? 0;
        return bms.compareTo(ams);
      });

      final top = unlocked.first;
      final title = top.catalog.title.trim();
      final cleanTitle = title.isEmpty ? 'Logro desbloqueado' : title;
      return '¡He obtenido un logro nuevo!\n$cleanTitle';
    }

    // Otherwise, share the best in-progress one.
    final inProgress = [...items];
    inProgress.sort((a, b) => b.progressRatio.compareTo(a.progressRatio));
    final top = inProgress.first;

    final title = top.catalog.title.trim();
    final pct = (top.progressRatio * 100).round().clamp(0, 100);

    final detail = title.isEmpty ? 'Progreso: $pct%' : '$title ($pct%)';
    return '¡Estoy avanzando en un logro!\n$detail';
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
      return '¡Mira qué entreno hice hoy!\n${todayWorkoutName.trim()}';
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
          return '¡Mira qué entreno me toca hoy!\n${w.name.trim()}';
        }
        return '¡Hoy toca entrenar!\nRutina asignada';
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
          return '¡Mira mi último entreno!\n${lastName.trim()}';
        }
      }
    } catch (_) {
      // ignore
    }

    return '¡Hoy toca moverse!';
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
