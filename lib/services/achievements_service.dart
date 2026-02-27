import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/achievement_catalog_item.dart';
import '../models/user_achievement.dart';
import '../services/local_storage_service.dart';
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
    LocalStorageService? storage,
  })  : _dbOverride = db,
        _authOverride = auth,
        _storage = storage ?? LocalStorageService();

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final LocalStorageService _storage;

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
            user: const UserAchievement(
              achievementId: '',
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

      final payload = <String, Object?>{
        'progress': progress,
        'visible': existing?.visible ?? true,
        'unlocked': unlocked,
      };

      if (!alreadyUnlocked && unlocked) {
        payload['unlockedAt'] = now;
      }

      final ref = _userAchievementsCol(userId).doc(item.id);
      batch.set(ref, payload, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<List<AchievementCatalogItem>> _getCatalog() async {
    if (!_ready) return _sampleCatalog;

    final qs = await _catalogCol.orderBy('createdAt').get();
    if (qs.docs.isEmpty) return _sampleCatalog;

    final out = <AchievementCatalogItem>[];
    for (final doc in qs.docs) {
      final item = AchievementCatalogItem.fromFirestore(
        id: doc.id,
        data: doc.data(),
      );
      if (item.title.isEmpty || item.conditionType.isEmpty) continue;
      out.add(item);
    }

    return out.isEmpty ? _sampleCatalog : out;
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
    final streakDays = (_uid == uid) ? await _storage.getStreakCount() : 0;

    final completionsSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('workoutCompletions')
        .get();
    final workoutsCompleted = completionsSnap.docs.length;

    final completionKeys = <String>{
      for (final d in completionsSnap.docs) d.id,
    };

    var maxWaterMlOneDay = 0;
    final dailyDataSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_data')
        .get();
    for (final doc in dailyDataSnap.docs) {
      final data = doc.data();
      final liters = _asDouble(data['waterLiters']) ?? _asDouble(data['water']) ?? 0;
      final ml = (liters * 1000).round();
      if (ml > maxWaterMlOneDay) maxWaterMlOneDay = ml;
    }

    final meditationSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .where('meditationMinutes', isGreaterThan: 0)
        .get();
    final meditationDays = meditationSnap.docs.length;

    final weeklyProgramsCompleted = await _countCompletedWeeks(
      uid: uid,
      completionKeys: completionKeys,
    );

    return _AchievementStats(
      streakDays: streakDays,
      workoutsCompleted: workoutsCompleted,
      maxWaterMlOneDay: maxWaterMlOneDay,
      meditationDays: meditationDays,
      weeklyProgramsCompleted: weeklyProgramsCompleted,
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
      case 'meditation_days':
        return stats.meditationDays;
      case 'weekly_program_completed':
      case 'completed_first_week_program':
        return stats.weeklyProgramsCompleted;
      case 'completed_first_workout':
        return stats.workoutsCompleted > 0 ? 1 : 0;
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

  static const List<AchievementCatalogItem> _sampleCatalog = [
    AchievementCatalogItem(
      id: 'first_workout',
      title: 'Primer entrenamiento',
      description: 'Completa tu primer entrenamiento.',
      icon: 'fitness_center_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 1,
    ),
    AchievementCatalogItem(
      id: 'streak_7_days',
      title: 'Constante 7 días',
      description: 'Mantén una racha de 7 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 7,
    ),
    AchievementCatalogItem(
      id: 'hydrated_2000',
      title: 'Hidratado',
      description: 'Llega a 2000 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'nutricion',
      conditionType: 'water_ml',
      conditionValue: 2000,
    ),
    AchievementCatalogItem(
      id: 'mind_strong',
      title: 'Mente fuerte',
      description: 'Registra meditación en 5 días.',
      icon: 'self_improvement_outlined',
      category: 'mentalidad',
      conditionType: 'meditation_days',
      conditionValue: 5,
    ),
    AchievementCatalogItem(
      id: 'workouts_10',
      title: '10 entrenamientos',
      description: 'Completa 10 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 10,
    ),
    AchievementCatalogItem(
      id: 'first_week_program',
      title: 'Primera semana completada',
      description: 'Completa todos los entrenamientos de una semana planificada.',
      icon: 'event_available_outlined',
      category: 'progreso',
      conditionType: 'weekly_program_completed',
      conditionValue: 1,
    ),
  ];
}

class _AchievementStats {
  const _AchievementStats({
    required this.streakDays,
    required this.workoutsCompleted,
    required this.maxWaterMlOneDay,
    required this.meditationDays,
    required this.weeklyProgramsCompleted,
  });

  final int streakDays;
  final int workoutsCompleted;
  final int maxWaterMlOneDay;
  final int meditationDays;
  final int weeklyProgramsCompleted;
}
