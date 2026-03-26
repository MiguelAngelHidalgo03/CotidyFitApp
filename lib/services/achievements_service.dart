import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/achievement_catalog_item.dart';
import '../models/user_achievement.dart';
import '../services/personalized_streak_service.dart';
import '../services/profile_service.dart';
import '../utils/date_utils.dart';

class AchievementViewItem {
  const AchievementViewItem({
    required this.catalog,
    required this.user,
  });

  final AchievementCatalogItem catalog;
  final UserAchievement user;

  double get progressRatio {
    final target = catalog.conditionValue <= 0 ? 1 : catalog.conditionValue;
    return (user.progress / target).clamp(0, 1).toDouble();
  }
}

class AchievementsService {
  AchievementsService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _dbOverride = db,
        _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final ProfileService _profileService = ProfileService();
  final PersonalizedStreakService _streakService =
      const PersonalizedStreakService();

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;
  String? get currentUid => _uid;

  CollectionReference<Map<String, dynamic>> get _catalogCol =>
      _db.collection('achievementsCatalog');

  CollectionReference<Map<String, dynamic>> _userAchievementsCol(String uid) {
    return _db.collection('users').doc(uid).collection('achievements');
  }

  Future<List<AchievementViewItem>> getAchievementsForCurrentUser() async {
    final uid = _uid;
    if (uid == null) {
      return [
        for (final c in _sampleCatalog)
          AchievementViewItem(
            catalog: c,
            user: UserAchievement(
              achievementId: c.id,
              unlocked: false,
              unlockedAt: null,
              progress: 0,
              visible: true,
            ),
          ),
      ];
    }

    await checkAchievements(uid);

    final catalog = await _getCatalog();
    final userMap = await _getUserAchievements(uid);

    final out = <AchievementViewItem>[];
    for (final c in catalog) {
      final user = userMap[c.id] ??
          UserAchievement(
            achievementId: c.id,
            unlocked: false,
            unlockedAt: null,
            progress: 0,
            visible: true,
          );
      if (!user.visible) continue;
      out.add(AchievementViewItem(catalog: c, user: user));
    }

    out.sort((a, b) {
      if (a.user.unlocked != b.user.unlocked) {
        return a.user.unlocked ? -1 : 1;
      }
      return a.catalog.title.compareTo(b.catalog.title);
    });

    return out;
  }

  Future<void> checkAchievements(String userId) async {
    if (!_ready || userId.trim().isEmpty) return;

    await _ensureSampleCatalogIfEmpty();

    final catalog = await _getCatalog();
    if (catalog.isEmpty) return;

    final current = await _getUserAchievements(userId);
    final stats = await _collectStats(userId);

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    var writes = 0;

    for (final item in catalog) {
      final progress = _progressForCondition(
        conditionType: item.conditionType,
        stats: stats,
      );
      final conditionValue = item.conditionValue <= 0 ? 1 : item.conditionValue;
      final shouldUnlock = progress >= conditionValue;

      final existing = current[item.id];
      final alreadyUnlocked = existing?.unlocked == true;
      final unlocked = alreadyUnlocked || shouldUnlock;

      final previousProgress = existing?.progress ?? 0;
      final previousUnlocked = existing?.unlocked == true;
      final previousVisible = existing?.visible ?? true;

      final changed =
          existing == null ||
          previousProgress != progress ||
          previousUnlocked != unlocked;

      if (!changed) continue;

      final payload = <String, Object?>{
        'progress': progress,
        'visible': previousVisible,
        'unlocked': unlocked,
      };

      if (!alreadyUnlocked && unlocked) {
        payload['unlockedAt'] = now;
      }

      final ref = _userAchievementsCol(userId).doc(item.id);
      batch.set(ref, payload, SetOptions(merge: true));
      writes++;
    }

    if (writes == 0) return;
    await batch.commit();
  }

  Future<List<AchievementCatalogItem>> _getCatalog() async {
    // Always include the local catalog so the app has a full set of achievements
    // even when the remote catalog exists but is incomplete/outdated.
    final out = _sampleCatalog.toList();
    if (!_ready) return out;

    try {
      final qs = await _catalogCol.orderBy('createdAt').get();
      if (qs.docs.isEmpty) return out;

      final indexById = <String, int>{
        for (var i = 0; i < out.length; i++) out[i].id: i,
      };

      for (final doc in qs.docs) {
        final data = doc.data();
        final remote = AchievementCatalogItem.fromFirestore(
          id: doc.id,
          data: data,
        );
        if (remote.title.isEmpty || remote.conditionType.isEmpty) continue;

        final idx = indexById[remote.id];
        if (idx != null) {
          final base = out[idx];

          final remoteIcon = (data['icon'] as String? ?? '').trim();
          final remoteCategory = (data['category'] as String? ?? '').trim();
          final remoteDifficulty = (data['difficulty'] as String? ?? '').trim();

          out[idx] = AchievementCatalogItem(
            id: remote.id,
            title: remote.title,
            description: remote.description.isNotEmpty
                ? remote.description
                : base.description,
            icon: remoteIcon.isNotEmpty ? remoteIcon : base.icon,
            category:
                remoteCategory.isNotEmpty ? remoteCategory : base.category,
            conditionType: remote.conditionType,
            conditionValue: (data.containsKey('conditionValue') &&
                    remote.conditionValue > 0)
                ? remote.conditionValue
                : base.conditionValue,
            difficulty: remoteDifficulty.isNotEmpty
                ? remoteDifficulty
                : base.difficulty,
            createdAt: remote.createdAt ?? base.createdAt,
          );
        } else {
          out.add(remote);
        }
      }
    } catch (_) {
      // Keep local catalog as fallback.
      return out;
    }

    return out;
  }

  Future<Map<String, UserAchievement>> _getUserAchievements(String uid) async {
    final qs = await _userAchievementsCol(uid).get();
    final out = <String, UserAchievement>{};
    for (final doc in qs.docs) {
      out[doc.id] = UserAchievement.fromFirestore(
        achievementId: doc.id,
        data: doc.data(),
      );
    }
    return out;
  }

  Future<_AchievementStats> _collectStats(String uid) async {
    final profile = (_uid == uid) ? await _profileService.getProfile() : null;

    var workoutsCompleted = 0;
    final completionKeys = <String>{};
    try {
      final completionsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('workoutCompletions')
          .get();
      workoutsCompleted = completionsSnap.docs.length;
      for (final d in completionsSnap.docs) {
        final key = d.id.trim();
        if (key.isNotEmpty) completionKeys.add(key);
      }
    } catch (_) {
      // Keep defaults.
    }

    final byDay = <String, _MergedDay>{};
    _MergedDay dayForKey(String key) =>
        byDay.putIfAbsent(key, () => _MergedDay());

    try {
      final statsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('dailyStats')
          .get();

      for (final doc in statsSnap.docs) {
        final data = doc.data();
        final key = ((data['dateKey'] as String?) ?? doc.id).trim();
        if (key.isEmpty) continue;

        final d = dayForKey(key);

        final steps = _asInt(data['steps']) ?? 0;
        if (steps > d.steps) d.steps = steps;

        final waterLiters = _asDouble(data['waterLiters']) ?? 0.0;
        if (waterLiters > d.waterLiters) d.waterLiters = waterLiters;

        final meals = _asInt(data['mealsLoggedCount']) ?? 0;
        if (meals > d.mealsLoggedCount) d.mealsLoggedCount = meals;

        final meditation = _asInt(data['meditationMinutes']) ?? 0;
        if (meditation > d.meditationMinutes) d.meditationMinutes = meditation;

        final cf = _asInt(data['cfIndex']) ?? 0;
        if (cf > d.cfIndex) d.cfIndex = cf;

        final activeMinutes = _asInt(data['activeMinutes']) ?? 0;
        if (activeMinutes > d.activeMinutes) d.activeMinutes = activeMinutes;

        if (data['workoutCompleted'] == true) d.workoutCompleted = true;
      }
    } catch (_) {
      // Keep defaults.
    }

    try {
      final dailyDataSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('daily_data')
          .get();

      for (final doc in dailyDataSnap.docs) {
        final data = doc.data();
        final key = ((data['dateKey'] as String?) ?? doc.id).trim();
        if (key.isEmpty) continue;

        final d = dayForKey(key);

        final steps = _asInt(data['steps']) ?? 0;
        if (steps > d.steps) d.steps = steps;

        final waterLiters =
            _asDouble(data['waterLiters']) ?? _asDouble(data['water']) ?? 0.0;
        if (waterLiters > d.waterLiters) d.waterLiters = waterLiters;

        final activeMinutes =
            _asInt(data['minutesActive']) ?? _asInt(data['activeMinutes']) ?? 0;
        if (activeMinutes > d.activeMinutes) d.activeMinutes = activeMinutes;

        final cf = _asInt(data['cfIndex']) ?? _asInt(data['cfScore']) ?? 0;
        if (cf > d.cfIndex) d.cfIndex = cf;

        final meditation = _asInt(data['meditationMinutes']) ?? 0;
        if (meditation > d.meditationMinutes) d.meditationMinutes = meditation;
      }
    } catch (_) {
      // Keep defaults.
    }

    for (final key in completionKeys) {
      dayForKey(key).workoutCompleted = true;
    }

    var streakDays = 0;
    if (byDay.isNotEmpty) {
      final orderedKeys = byDay.keys.toList()..sort();
      final start = DateUtilsCF.fromKey(orderedKeys.first);
      final today = DateUtilsCF.dateOnly(DateTime.now());
      if (start != null) {
        final flags = <bool>[];
        for (var day = start; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
          final key = DateUtilsCF.toKey(day);
          final merged = byDay[key];
          if (merged == null) {
            if (key == DateUtilsCF.toKey(today)) continue;
            flags.add(false);
            continue;
          }
          flags.add(
            _streakService.isCompletedDay(
              profile: profile,
              snapshot: merged.toPersonalizedSnapshot(),
            ),
          );
        }
        streakDays = _streakService.currentStreak(flags);
      }
    }

    var stepsTotal = 0;
    var bestStepsDay = 0;
    var stepsDays8000 = 0;
    var maxWaterMlOneDay = 0;
    var waterDays2000ml = 0;
    var meditationDays = 0;
    var mealsCompleteDays = 0;
    var activeMinutesTotal = 0;
    var activeMinutesDays30 = 0;
    var bestCfDay = 0;

    for (final d in byDay.values) {
      final steps = d.steps.clamp(0, 1000000000);
      stepsTotal += steps;
      bestStepsDay = max(bestStepsDay, steps);
      if (steps >= 8000) stepsDays8000++;

      final safeWater =
          d.waterLiters.isNaN || d.waterLiters.isInfinite
              ? 0.0
              : d.waterLiters;
      final liters = safeWater < 0 ? 0.0 : safeWater;
      final ml = (liters * 1000).round();
      if (ml > maxWaterMlOneDay) maxWaterMlOneDay = ml;
      if (liters >= 2.0) waterDays2000ml++;

      if (d.meditationMinutes > 0) meditationDays++;
      if (d.mealsLoggedCount >= 3) mealsCompleteDays++;

      final active = d.activeMinutes.clamp(0, 1000000000);
      activeMinutesTotal += active;
      if (active >= 30) activeMinutesDays30++;

      bestCfDay = max(bestCfDay, d.cfIndex.clamp(0, 100));
    }

    var weeklyProgramsCompleted = 0;
    try {
      weeklyProgramsCompleted = await _countCompletedWeeks(
        uid: uid,
        completionKeys: completionKeys,
      );
    } catch (_) {
      // Keep default.
    }

    var checkinsDays = 0;
    try {
      final moodSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('dailyMood')
          .get();
      checkinsDays = moodSnap.docs.where((d) => d.data().isNotEmpty).length;
    } catch (_) {
      // Keep default.
    }

    var weightEntries = 0;
    try {
      final weightSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('weightEntries')
          .get();
      weightEntries = weightSnap.docs.length;
    } catch (_) {
      // Keep default.
    }

    return _AchievementStats(
      streakDays: streakDays,
      workoutsCompleted: workoutsCompleted,
      maxWaterMlOneDay: maxWaterMlOneDay,
      waterDays2000ml: waterDays2000ml,
      meditationDays: meditationDays,
      weeklyProgramsCompleted: weeklyProgramsCompleted,
      stepsTotal: stepsTotal,
      bestStepsDay: bestStepsDay,
      stepsDays8000: stepsDays8000,
      activeMinutesTotal: activeMinutesTotal,
      activeMinutesDays30: activeMinutesDays30,
      mealsCompleteDays: mealsCompleteDays,
      checkinsDays: checkinsDays,
      bestCfDay: bestCfDay,
      weightEntries: weightEntries,
    );
  }

  Future<int> _countCompletedWeeks({
    required String uid,
    required Set<String> completionKeys,
  }) async {
    final plansSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('workoutPlans')
        .get();

    var completed = 0;

    for (final planDoc in plansSnap.docs) {
      final data = planDoc.data();
      final weekKeyRaw = data['weekStartKey'];
      final weekKey = weekKeyRaw is String ? weekKeyRaw : planDoc.id;
      final start = DateUtilsCF.fromKey(weekKey);
      if (start == null) continue;

      final assignmentsRaw = data['assignments'];
      if (assignmentsRaw is! Map) continue;

      final assignedDays = <int>[];
      for (final e in assignmentsRaw.entries) {
        final day = int.tryParse(e.key.toString());
        final workoutId = e.value;
        if (day == null || day < 0 || day > 6) continue;
        if (workoutId is! String || workoutId.trim().isEmpty) continue;
        assignedDays.add(day);
      }

      if (assignedDays.isEmpty) continue;

      var completedDays = 0;
      for (final day in assignedDays) {
        final dateKey = DateUtilsCF.toKey(start.add(Duration(days: day)));
        if (completionKeys.contains(dateKey)) completedDays++;
      }

      if (completedDays >= assignedDays.length) {
        completed++;
      }
    }

    return completed;
  }

  int _progressForCondition({
    required String conditionType,
    required _AchievementStats stats,
  }) {
    switch (conditionType) {
      case 'streak_days':
        return stats.streakDays;
      case 'workouts_completed':
        return stats.workoutsCompleted;
      case 'water_ml':
        return stats.maxWaterMlOneDay;
      case 'water_days_2000ml':
        return stats.waterDays2000ml;
      case 'meditation_days':
        return stats.meditationDays;
      case 'weekly_program_completed':
      case 'completed_first_week_program':
        return stats.weeklyProgramsCompleted;
      case 'completed_first_workout':
        return stats.workoutsCompleted > 0 ? 1 : 0;
      case 'steps_total':
        return stats.stepsTotal;
      case 'steps_best_day':
        return stats.bestStepsDay;
      case 'steps_days_8000':
        return stats.stepsDays8000;
      case 'active_minutes_total':
        return stats.activeMinutesTotal;
      case 'active_minutes_days_30':
        return stats.activeMinutesDays30;
      case 'meals_complete_days':
        return stats.mealsCompleteDays;
      case 'checkins_days':
        return stats.checkinsDays;
      case 'cf_best_day':
        return stats.bestCfDay;
      case 'weight_entries':
        return stats.weightEntries;
      default:
        return 0;
    }
  }

  Future<void> _ensureSampleCatalogIfEmpty() async {
    if (!_ready) return;
    final existing = await _catalogCol.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final item in _sampleCatalog) {
      final ref = _catalogCol.doc(item.id);
      batch.set(ref, {
        ...item.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } catch (_) {
      // If current user is not admin, rules may reject this. Catalog fallback still works.
    }
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static const List<AchievementCatalogItem> _sampleCatalog = [
    AchievementCatalogItem(
      id: 'first_workout',
      title: 'Primer entrenamiento',
      description: 'Completa tu primer entrenamiento.',
      icon: 'fitness_center_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 1,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'workouts_5',
      title: '5 entrenamientos',
      description: 'Completa 5 entrenamientos.',
      icon: 'fitness_center_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 5,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'streak_7_days',
      title: 'Constante 7 días',
      description: 'Mantén una racha de 7 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'workouts_10',
      title: '10 entrenamientos',
      description: 'Completa 10 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 10,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'hydrated_2000',
      title: 'Hidratado',
      description: 'Llega a 2000 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_ml',
      conditionValue: 2000,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'mind_strong',
      title: 'Mente fuerte',
      description: 'Registra meditación en 5 días.',
      icon: 'self_improvement_outlined',
      category: 'meditacion',
      conditionType: 'meditation_days',
      conditionValue: 5,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'first_week_program',
      title: 'Primera semana completada',
      description: 'Completa todos los entrenamientos de una semana planificada.',
      icon: 'event_available_outlined',
      category: 'programas',
      conditionType: 'weekly_program_completed',
      conditionValue: 1,
      difficulty: 'easy',
    ),

    // Entrenamiento
    AchievementCatalogItem(
      id: 'workouts_25',
      title: '25 entrenamientos',
      description: 'Completa 25 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 25,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'workouts_50',
      title: '50 entrenamientos',
      description: 'Completa 50 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 50,
      difficulty: 'hard',
    ),
    AchievementCatalogItem(
      id: 'workouts_100',
      title: '100 entrenamientos',
      description: 'Completa 100 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 100,
      difficulty: 'hard',
    ),

    // Rachas
    AchievementCatalogItem(
      id: 'streak_3_days',
      title: 'Constante 3 días',
      description: 'Mantén una racha de 3 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 3,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'streak_14_days',
      title: 'Constante 14 días',
      description: 'Mantén una racha de 14 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'streak_30_days',
      title: 'Constante 30 días',
      description: 'Mantén una racha de 30 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 30,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'streak_60_days',
      title: 'Constante 60 días',
      description: 'Mantén una racha de 60 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 60,
      difficulty: 'hard',
    ),
    AchievementCatalogItem(
      id: 'streak_100_days',
      title: 'Constante 100 días',
      description: 'Mantén una racha de 100 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 100,
      difficulty: 'hard',
    ),

    // Hidratación (máximo en un día)
    AchievementCatalogItem(
      id: 'hydrated_1500',
      title: 'Hidratación 1500 ml',
      description: 'Llega a 1500 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_ml',
      conditionValue: 1500,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'hydrated_2500',
      title: 'Hidratación 2500 ml',
      description: 'Llega a 2500 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_ml',
      conditionValue: 2500,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'hydrated_3000',
      title: 'Hidratación 3000 ml',
      description: 'Llega a 3000 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_ml',
      conditionValue: 3000,
      difficulty: 'hard',
    ),

    // Hidratación (días con 2000 ml)
    AchievementCatalogItem(
      id: 'hydration_days_7',
      title: '7 días hidratado',
      description: 'Alcanza 2000 ml de agua en 7 días (acumulados).',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_days_2000ml',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'hydration_days_14',
      title: '14 días hidratado',
      description: 'Alcanza 2000 ml de agua en 14 días (acumulados).',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_days_2000ml',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'hydration_days_30',
      title: '30 días hidratado',
      description: 'Alcanza 2000 ml de agua en 30 días (acumulados).',
      icon: 'water_drop_outlined',
      category: 'hidratacion',
      conditionType: 'water_days_2000ml',
      conditionValue: 30,
      difficulty: 'hard',
    ),

    // Meditación
    AchievementCatalogItem(
      id: 'meditation_1_day',
      title: 'Primer día de meditación',
      description: 'Registra meditación en 1 día.',
      icon: 'self_improvement_outlined',
      category: 'meditacion',
      conditionType: 'meditation_days',
      conditionValue: 1,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'meditation_10_days',
      title: '10 días de meditación',
      description: 'Registra meditación en 10 días.',
      icon: 'self_improvement_outlined',
      category: 'meditacion',
      conditionType: 'meditation_days',
      conditionValue: 10,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'meditation_25_days',
      title: '25 días de meditación',
      description: 'Registra meditación en 25 días.',
      icon: 'self_improvement_outlined',
      category: 'meditacion',
      conditionType: 'meditation_days',
      conditionValue: 25,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'meditation_50_days',
      title: '50 días de meditación',
      description: 'Registra meditación en 50 días.',
      icon: 'self_improvement_outlined',
      category: 'meditacion',
      conditionType: 'meditation_days',
      conditionValue: 50,
      difficulty: 'hard',
    ),

    // Programas
    AchievementCatalogItem(
      id: 'week_program_4',
      title: '4 semanas completadas',
      description: 'Completa 4 semanas planificadas.',
      icon: 'event_available_outlined',
      category: 'programas',
      conditionType: 'weekly_program_completed',
      conditionValue: 4,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'week_program_12',
      title: '12 semanas completadas',
      description: 'Completa 12 semanas planificadas.',
      icon: 'event_available_outlined',
      category: 'programas',
      conditionType: 'weekly_program_completed',
      conditionValue: 12,
      difficulty: 'hard',
    ),

    // Pasos (total)
    AchievementCatalogItem(
      id: 'steps_total_50000',
      title: '50.000 pasos',
      description: 'Acumula 50.000 pasos.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_total',
      conditionValue: 50000,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'steps_total_150000',
      title: '150.000 pasos',
      description: 'Acumula 150.000 pasos.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_total',
      conditionValue: 150000,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_total_300000',
      title: '300.000 pasos',
      description: 'Acumula 300.000 pasos.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_total',
      conditionValue: 300000,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_total_500000',
      title: '500.000 pasos',
      description: 'Acumula 500.000 pasos.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_total',
      conditionValue: 500000,
      difficulty: 'hard',
    ),
    AchievementCatalogItem(
      id: 'steps_total_1000000',
      title: '1.000.000 pasos',
      description: 'Acumula 1.000.000 de pasos.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_total',
      conditionValue: 1000000,
      difficulty: 'hard',
    ),

    // Pasos (mejor día)
    AchievementCatalogItem(
      id: 'steps_best_8000',
      title: 'Día de 8.000 pasos',
      description: 'Alcanza 8.000 pasos en un día.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_best_day',
      conditionValue: 8000,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'steps_best_12000',
      title: 'Día de 12.000 pasos',
      description: 'Alcanza 12.000 pasos en un día.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_best_day',
      conditionValue: 12000,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_best_16000',
      title: 'Día de 16.000 pasos',
      description: 'Alcanza 16.000 pasos en un día.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_best_day',
      conditionValue: 16000,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_best_20000',
      title: 'Día de 20.000 pasos',
      description: 'Alcanza 20.000 pasos en un día.',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_best_day',
      conditionValue: 20000,
      difficulty: 'hard',
    ),

    // Pasos (días con 8.000)
    AchievementCatalogItem(
      id: 'steps_days_7',
      title: '7 días de 8.000 pasos',
      description: 'Alcanza 8.000 pasos en 7 días (acumulados).',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_days_8000',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'steps_days_14',
      title: '14 días de 8.000 pasos',
      description: 'Alcanza 8.000 pasos en 14 días (acumulados).',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_days_8000',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_days_30',
      title: '30 días de 8.000 pasos',
      description: 'Alcanza 8.000 pasos en 30 días (acumulados).',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_days_8000',
      conditionValue: 30,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'steps_days_60',
      title: '60 días de 8.000 pasos',
      description: 'Alcanza 8.000 pasos en 60 días (acumulados).',
      icon: 'directions_walk_outlined',
      category: 'pasos',
      conditionType: 'steps_days_8000',
      conditionValue: 60,
      difficulty: 'hard',
    ),

    // Actividad (minutos activos)
    AchievementCatalogItem(
      id: 'active_total_300',
      title: '300 minutos activos',
      description: 'Acumula 300 minutos activos.',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_total',
      conditionValue: 300,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'active_total_600',
      title: '600 minutos activos',
      description: 'Acumula 600 minutos activos.',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_total',
      conditionValue: 600,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'active_total_1200',
      title: '1200 minutos activos',
      description: 'Acumula 1200 minutos activos.',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_total',
      conditionValue: 1200,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'active_days_7',
      title: '7 días con 30 min activos',
      description: 'Registra 30 minutos activos en 7 días (acumulados).',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_days_30',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'active_days_14',
      title: '14 días con 30 min activos',
      description: 'Registra 30 minutos activos en 14 días (acumulados).',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_days_30',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'active_days_30',
      title: '30 días con 30 min activos',
      description: 'Registra 30 minutos activos en 30 días (acumulados).',
      icon: 'timer_outlined',
      category: 'actividad',
      conditionType: 'active_minutes_days_30',
      conditionValue: 30,
      difficulty: 'medium',
    ),

    // Nutrición (días completos)
    AchievementCatalogItem(
      id: 'meals_complete_3',
      title: '3 días completos',
      description: 'Registra 3 comidas en 3 días (acumulados).',
      icon: 'restaurant_outlined',
      category: 'nutricion',
      conditionType: 'meals_complete_days',
      conditionValue: 3,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'meals_complete_7',
      title: '7 días completos',
      description: 'Registra 3 comidas en 7 días (acumulados).',
      icon: 'restaurant_outlined',
      category: 'nutricion',
      conditionType: 'meals_complete_days',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'meals_complete_14',
      title: '14 días completos',
      description: 'Registra 3 comidas en 14 días (acumulados).',
      icon: 'restaurant_outlined',
      category: 'nutricion',
      conditionType: 'meals_complete_days',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'meals_complete_30',
      title: '30 días completos',
      description: 'Registra 3 comidas en 30 días (acumulados).',
      icon: 'restaurant_outlined',
      category: 'nutricion',
      conditionType: 'meals_complete_days',
      conditionValue: 30,
      difficulty: 'medium',
    ),

    // Bienestar (check-ins)
    AchievementCatalogItem(
      id: 'checkins_3',
      title: '3 check-ins',
      description: 'Registra 3 check-ins de bienestar.',
      icon: 'emoji_emotions_outlined',
      category: 'bienestar',
      conditionType: 'checkins_days',
      conditionValue: 3,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'checkins_7',
      title: '7 check-ins',
      description: 'Registra 7 check-ins de bienestar.',
      icon: 'emoji_emotions_outlined',
      category: 'bienestar',
      conditionType: 'checkins_days',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'checkins_14',
      title: '14 check-ins',
      description: 'Registra 14 check-ins de bienestar.',
      icon: 'emoji_emotions_outlined',
      category: 'bienestar',
      conditionType: 'checkins_days',
      conditionValue: 14,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'checkins_30',
      title: '30 check-ins',
      description: 'Registra 30 check-ins de bienestar.',
      icon: 'emoji_emotions_outlined',
      category: 'bienestar',
      conditionType: 'checkins_days',
      conditionValue: 30,
      difficulty: 'medium',
    ),

    // CotidyFit (mejor día)
    AchievementCatalogItem(
      id: 'cf_best_60',
      title: 'CF 60+',
      description: 'Consigue un CF de 60 o más en un día.',
      icon: 'auto_graph_outlined',
      category: 'cotidyfit',
      conditionType: 'cf_best_day',
      conditionValue: 60,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'cf_best_70',
      title: 'CF 70+',
      description: 'Consigue un CF de 70 o más en un día.',
      icon: 'auto_graph_outlined',
      category: 'cotidyfit',
      conditionType: 'cf_best_day',
      conditionValue: 70,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'cf_best_80',
      title: 'CF 80+',
      description: 'Consigue un CF de 80 o más en un día.',
      icon: 'auto_graph_outlined',
      category: 'cotidyfit',
      conditionType: 'cf_best_day',
      conditionValue: 80,
      difficulty: 'medium',
    ),
    AchievementCatalogItem(
      id: 'cf_best_90',
      title: 'CF 90+',
      description: 'Consigue un CF de 90 o más en un día.',
      icon: 'auto_graph_outlined',
      category: 'cotidyfit',
      conditionType: 'cf_best_day',
      conditionValue: 90,
      difficulty: 'hard',
    ),

    // Peso
    AchievementCatalogItem(
      id: 'weight_1_entry',
      title: 'Primer registro de peso',
      description: 'Registra tu peso por primera vez.',
      icon: 'monitor_weight_outlined',
      category: 'peso',
      conditionType: 'weight_entries',
      conditionValue: 1,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'weight_7_entries',
      title: '7 registros de peso',
      description: 'Registra tu peso 7 veces.',
      icon: 'monitor_weight_outlined',
      category: 'peso',
      conditionType: 'weight_entries',
      conditionValue: 7,
      difficulty: 'easy',
    ),
    AchievementCatalogItem(
      id: 'weight_30_entries',
      title: '30 registros de peso',
      description: 'Registra tu peso 30 veces.',
      icon: 'monitor_weight_outlined',
      category: 'peso',
      conditionType: 'weight_entries',
      conditionValue: 30,
      difficulty: 'medium',
    ),
  ];
}

class _MergedDay {
  int steps = 0;
  double waterLiters = 0.0;
  int activeMinutes = 0;
  int mealsLoggedCount = 0;
  int meditationMinutes = 0;
  int cfIndex = 0;
  bool workoutCompleted = false;

  PersonalizedStreakDaySnapshot toPersonalizedSnapshot() {
    return PersonalizedStreakDaySnapshot(
      workoutCompleted: workoutCompleted,
      steps: steps,
      mealsLoggedCount: mealsLoggedCount,
      meditationMinutes: meditationMinutes,
      waterLiters: waterLiters,
      cf: cfIndex,
      hasData: steps > 0 ||
          waterLiters > 0 ||
          activeMinutes > 0 ||
          mealsLoggedCount > 0 ||
          meditationMinutes > 0 ||
          cfIndex > 0 ||
          workoutCompleted,
    );
  }
}

class _AchievementStats {
  const _AchievementStats({
    required this.streakDays,
    required this.workoutsCompleted,
    required this.maxWaterMlOneDay,
    required this.waterDays2000ml,
    required this.meditationDays,
    required this.weeklyProgramsCompleted,
    required this.stepsTotal,
    required this.bestStepsDay,
    required this.stepsDays8000,
    required this.activeMinutesTotal,
    required this.activeMinutesDays30,
    required this.mealsCompleteDays,
    required this.checkinsDays,
    required this.bestCfDay,
    required this.weightEntries,
  });

  final int streakDays;
  final int workoutsCompleted;
  final int maxWaterMlOneDay;
  final int waterDays2000ml;
  final int meditationDays;
  final int weeklyProgramsCompleted;
  final int stepsTotal;
  final int bestStepsDay;
  final int stepsDays8000;
  final int activeMinutesTotal;
  final int activeMinutesDays30;
  final int mealsCompleteDays;
  final int checkinsDays;
  final int bestCfDay;
  final int weightEntries;
}
