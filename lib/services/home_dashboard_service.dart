import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../utils/date_utils.dart';
import 'personalized_streak_service.dart';

class HomeDayStat {
  const HomeDayStat({
    required this.dateKey,
    required this.dayLabel,
    required this.completed,
    required this.cfScore,
    required this.steps,
  });

  final String dateKey;
  final String dayLabel;
  final bool completed;
  final int cfScore;
  final int steps;
}

class WeeklyGoalsProgress {
  const WeeklyGoalsProgress({
    required this.weekId,
    required this.trainingDays,
    required this.stepsDays6000,
    required this.healthyEatingDays,
    required this.meditationDays,
    required this.progress,
    required this.completedGoals,
    required this.totalGoals,
  });

  final String weekId;
  final int trainingDays;
  final int stepsDays6000;
  final int healthyEatingDays;
  final int meditationDays;
  final double progress;
  final int completedGoals;
  final int totalGoals;
}

class WeeklyChallengeData {
  const WeeklyChallengeData({
    required this.id,
    required this.weekId,
    required this.title,
    required this.description,
    required this.targetType,
    required this.targetValue,
    required this.rewardCfBonus,
    required this.progressValue,
    required this.progress,
    required this.completed,
    required this.communityCompletionPct,
  });

  final String id;
  final String weekId;
  final String title;
  final String description;
  final String targetType;
  final int targetValue;
  final int rewardCfBonus;
  final int progressValue;
  final double progress;
  final bool completed;
  final int communityCompletionPct;
}

class HabitItem {
  const HabitItem({
    required this.id,
    required this.name,
    required this.repeatDays,
    required this.cfReward,
    required this.isCompletedToday,
  });

  final String id;
  final String name;
  final List<int> repeatDays;
  final int cfReward;
  final bool isCompletedToday;
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.completed,
    required this.cfReward,
    required this.notificationEnabled,
  });

  final String id;
  final DateTime? dueDate;
  final String title;
  final bool completed;
  final int cfReward;
  final bool notificationEnabled;
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.weekDays,
    required this.streak,
    required this.cfScore,
    required this.hasMoodToday,
    required this.weeklyGoals,
    required this.weeklyChallenge,
    required this.habits,
    required this.tasks,
    required this.weeklyStreak,
    required this.weeklyHabitsCompleted,
    required this.weeklyHabitActiveDays,
  });

  final List<HomeDayStat> weekDays;
  final int streak;
  final int cfScore;
  final bool hasMoodToday;
  final WeeklyGoalsProgress weeklyGoals;
  final WeeklyChallengeData? weeklyChallenge;
  final List<HabitItem> habits;
  final List<TaskItem> tasks;
  final int weeklyStreak;
  final int weeklyHabitsCompleted;
  final int weeklyHabitActiveDays;
}

class HomeDashboardService {
  HomeDashboardService({FirebaseFirestore? db}) : _dbOverride = db;

  final FirebaseFirestore? _dbOverride;
  final PersonalizedStreakService _streakService =
      const PersonalizedStreakService();

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  Future<String?> getUserPreferredName({
    required String uid,
    String? fallbackEmail,
  }) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};

    String pick(Object? value) {
      final s = (value as String? ?? '').trim();
      if (s.isEmpty || s == 'CotidyFit') return '';
      return s;
    }

    final profileData = data['profileData'];
    String fromProfileName = '';
    if (profileData is Map) {
      fromProfileName = pick(profileData['name']);
    }

    final candidates = [
      fromProfileName,
      pick(data['username']),
      pick(data['displayName']),
      pick(data['name']),
    ];

    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }

    final email = (fallbackEmail ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return null;
  }

  Future<HomeDashboardData> loadDashboard({
    required String uid,
    required String todayKey,
    required int todayCfScore,
    required UserProfile? profile,
  }) async {
    final today =
        DateUtilsCF.fromKey(todayKey) ?? DateUtilsCF.dateOnly(DateTime.now());
    final weekStart = _mondayOf(today);
    final weekDates = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );

    final dayStats = await Future.wait(
      weekDates.map(
        (d) => _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .doc(DateUtilsCF.toKey(d))
            .get(),
      ),
    );

    final weekDays = <HomeDayStat>[];
    var trainDays = 0;
    var steps6000Days = 0;
    var healthyDays = 0;
    var meditationDays = 0;
    var weeklySteps = 0;
    var weeklyWaterMl = 0;
    var activeDays = 0;

    for (var i = 0; i < dayStats.length; i++) {
      final data = dayStats[i].data() ?? const <String, dynamic>{};
      final steps = _asInt(data['steps']);
      final workout = data['workoutCompleted'] == true;
      final meals = _asInt(data['mealsLoggedCount']);
      final meditation = _asInt(data['meditationMinutes']);
      final cf = _asInt(data['cfIndex']);
      final waterMl = _asInt(data['waterMl']);
      final waterLiters = data['waterLiters'];
      final waterFromLitersMl = waterLiters is num
          ? (waterLiters * 1000).round()
          : 0;
      weeklyWaterMl += waterMl > 0 ? waterMl : waterFromLitersMl;
      final completed = _streakService.isCompletedDay(
        profile: profile,
        snapshot: PersonalizedStreakDaySnapshot.fromDailyStatsMap(
          data,
          hasData: data.isNotEmpty,
        ),
      );

      if (workout) trainDays += 1;
      if (steps >= 6000) steps6000Days += 1;
      if (meals >= 3) healthyDays += 1;
      if (meditation >= 5) meditationDays += 1;
      weeklySteps += steps;
      if (completed) activeDays += 1;

      weekDays.add(
        HomeDayStat(
          dateKey: DateUtilsCF.toKey(weekDates[i]),
          dayLabel: _weekdayShort(weekDates[i]),
          completed: completed,
          cfScore: cf,
          steps: steps,
        ),
      );
    }

    final completedGoals = [
      trainDays >= 3,
      steps6000Days >= 7,
      healthyDays >= 3,
      meditationDays >= 2,
    ].where((x) => x).length;

    final weekId = DateUtilsCF.toKey(weekStart);
    final weeklyGoals = WeeklyGoalsProgress(
      weekId: weekId,
      trainingDays: trainDays,
      stepsDays6000: steps6000Days,
      healthyEatingDays: healthyDays,
      meditationDays: meditationDays,
      progress: completedGoals / 4,
      completedGoals: completedGoals,
      totalGoals: 4,
    );

    await _db
        .collection('users')
        .doc(uid)
        .collection('weeklyStats')
        .doc(weekId)
        .set({
          'weekId': weekId,
          'trainingDays': trainDays,
          'stepsDays6000': steps6000Days,
          'healthyEatingDays': healthyDays,
          'meditationDays': meditationDays,
          'completedGoals': completedGoals,
          'totalGoals': 4,
          'progress': completedGoals / 4,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final moodSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyMood')
        .doc(todayKey)
        .get();
    final hasMoodToday = moodSnap.exists;
    final weeklyHabitsStats = await _loadWeeklyHabitsStats(
      uid: uid,
      weekDates: weekDates,
    );

    final challenge = await _loadWeeklyChallenge(
      uid: uid,
      weekId: weekId,
      weeklySteps: weeklySteps,
      weeklyWaterMl: weeklyWaterMl,
      weeklyWorkouts: trainDays,
      weeklyActiveDays: activeDays,
      weeklyHabitsCompleted: weeklyHabitsStats.completed,
      weeklyHabitActiveDays: weeklyHabitsStats.activeDays,
    );

    final habits = await _loadHabits(uid: uid, today: today);
    final tasks = await _loadTasks(uid: uid);
    final streak = await _computeStreak(uid: uid, today: today, profile: profile);
    final weeklyStreak = await _computeWeeklyStreak(
      uid: uid,
      currentWeekStart: weekStart,
      profile: profile,
    );

    return HomeDashboardData(
      weekDays: weekDays,
      streak: streak,
      cfScore: todayCfScore.clamp(0, 100),
      hasMoodToday: hasMoodToday,
      weeklyGoals: weeklyGoals,
      weeklyChallenge: challenge,
      habits: habits,
      tasks: tasks,
      weeklyStreak: weeklyStreak,
      weeklyHabitsCompleted: weeklyHabitsStats.completed,
      weeklyHabitActiveDays: weeklyHabitsStats.activeDays,
    );
  }

  Future<({int completed, int activeDays})> _loadWeeklyHabitsStats({
    required String uid,
    required List<DateTime> weekDates,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    var completed = 0;
    var activeDays = 0;

    for (final day in weekDates) {
      final key = DateUtilsCF.toKey(day);
      final logs = await userRef
          .collection('habitLogs')
          .doc(key)
          .collection('habits')
          .get();
      final count = logs.docs.length;
      completed += count;
      if (count > 0) activeDays += 1;
    }

    return (completed: completed, activeDays: activeDays);
  }

  Future<List<HabitItem>> _loadHabits({
    required String uid,
    required DateTime today,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final habitsSnap = await userRef.collection('habits').get();
    final dateKey = DateUtilsCF.toKey(today);
    final weekday = today.weekday;
    final logsSnap = await userRef
        .collection('habitLogs')
        .doc(dateKey)
        .collection('habits')
        .get();
    final done = <String>{for (final d in logsSnap.docs) d.id};

    final sortedDocs = habitsSnap.docs.toList()
      ..sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });

    return sortedDocs
        .map((doc) {
          final data = doc.data();
          final repeatDays = _asIntList(data['repeatDays']);
          if (repeatDays.isNotEmpty && !repeatDays.contains(weekday)) {
            return null;
          }
          return HabitItem(
            id: doc.id,
            name: (data['name'] as String? ?? '').trim(),
            repeatDays: repeatDays,
            cfReward: _asInt(data['CFReward']) <= 0
                ? 2
                : _asInt(data['CFReward']),
            isCompletedToday: done.contains(doc.id),
          );
        })
        .whereType<HabitItem>()
        .toList();
  }

  Future<List<TaskItem>> _loadTasks({required String uid}) async {
    final tasksSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .limit(80)
        .get();

    final out = tasksSnap.docs.map((doc) {
      final data = doc.data();
      final due = data['dueDate'];
      return TaskItem(
        id: doc.id,
        title: (data['title'] as String? ?? '').trim(),
        dueDate: due is Timestamp ? due.toDate() : null,
        completed: data['completed'] == true,
        cfReward: _asInt(data['CFReward']) <= 0 ? 3 : _asInt(data['CFReward']),
        notificationEnabled: data['notificationEnabled'] == true,
      );
    }).toList();

    out.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      final aMs = a.dueDate?.millisecondsSinceEpoch ?? 253402300799000;
      final bMs = b.dueDate?.millisecondsSinceEpoch ?? 253402300799000;
      return aMs.compareTo(bMs);
    });
    return out.take(20).toList();
  }

  Future<WeeklyChallengeData?> _loadWeeklyChallenge({
    required String uid,
    required String weekId,
    required int weeklySteps,
    required int weeklyWaterMl,
    required int weeklyWorkouts,
    required int weeklyActiveDays,
    required int weeklyHabitsCompleted,
    required int weeklyHabitActiveDays,
  }) async {
    QueryDocumentSnapshot<Map<String, dynamic>>? chosenDoc;

    // 1) If a challenge is explicitly assigned to this week (weekId), use it.
    //    Admins can set weeklyChallenges.{doc}.weekId = current weekId to schedule.
    final byWeekSnap = await _db
        .collection('weeklyChallenges')
        .where('weekId', isEqualTo: weekId)
        .limit(1)
        .get();

    if (byWeekSnap.docs.isNotEmpty) {
      final candidate = byWeekSnap.docs.first;
      final active = candidate.data()['active'];
      if (active != false) {
        chosenDoc = candidate;
      }
    }

    // 2) Otherwise, rotate deterministically over active challenges.
    if (chosenDoc == null) {
      final activeSnap = await _db
          .collection('weeklyChallenges')
          .where('active', isEqualTo: true)
          .get();
      if (activeSnap.docs.isEmpty) return null;

      final docs = activeSnap.docs.toList();
      int orderOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final v = d.data()['order'];
        if (v is int) return v;
        if (v is num) return v.round();
        if (v is String) return int.tryParse(v) ?? 1 << 30;
        return 1 << 30;
      }

      docs.sort((a, b) {
        final ao = orderOf(a);
        final bo = orderOf(b);
        if (ao != bo) return ao.compareTo(bo);
        return a.id.compareTo(b.id);
      });

      final weekStart =
          DateUtilsCF.fromKey(weekId) ?? DateUtilsCF.dateOnly(DateTime.now());
      final weekStartUtc = DateTime.utc(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final anchor = DateTime.utc(2024, 1, 1);
      final weekIndex = weekStartUtc.difference(anchor).inDays ~/ 7;
      final pick = ((weekIndex % docs.length) + docs.length) % docs.length;
      chosenDoc = docs[pick];
    }

    final data = chosenDoc.data();
    final targetType = (data['targetType'] as String? ?? 'steps').trim();
    final targetValue = _asInt(data['targetValue']) <= 0
        ? 30000
        : _asInt(data['targetValue']);

    // Backwards-compat: some seeds used rewardCfBonus instead of rewardCFBonus.
    final rewardRaw = data['rewardCFBonus'] ?? data['rewardCfBonus'];
    final reward = _asInt(rewardRaw) <= 0 ? 10 : _asInt(rewardRaw);

    final type = targetType.toLowerCase();
    var progressValue = 0;
    if (type == 'steps') progressValue = weeklySteps;
    if (type == 'waterml') progressValue = weeklyWaterMl;
    if (type == 'habitscompleted') progressValue = weeklyHabitsCompleted;
    if (type == 'workouts') progressValue = weeklyWorkouts;
    if (type == 'activedays') progressValue = weeklyActiveDays;
    if (type == 'habitactivedays') progressValue = weeklyHabitActiveDays;

    final completed = progressValue >= targetValue;
    final progress = (progressValue / (targetValue <= 0 ? 1 : targetValue))
        .clamp(0.0, 1.0)
        .toDouble();

    final communityWeekId = (data['communityWeekId'] as String? ?? '').trim();
    final communityPctRaw = data['communityCompletionPct'];
    final communityCompletionPct = (communityWeekId == weekId)
        ? _asInt(communityPctRaw).clamp(0, 100).toInt()
        : 0;

    await _db
        .collection('users')
        .doc(uid)
        .collection('weeklyChallengeProgress')
        .doc(chosenDoc.id)
        .set({
          'challengeId': chosenDoc.id,
          'weekId': weekId,
          'targetType': targetType,
          'targetValue': targetValue,
          'progressValue': progressValue,
          'progress': progress,
          'completed': completed,
          'rewardCFBonus': reward,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    return WeeklyChallengeData(
      id: chosenDoc.id,
      weekId: weekId,
      title: (data['title'] as String? ?? 'Reto semanal').trim(),
      description: (data['description'] as String? ?? '').trim(),
      targetType: targetType,
      targetValue: targetValue,
      rewardCfBonus: reward,
      progressValue: progressValue,
      progress: progress,
      completed: completed,
      communityCompletionPct: communityCompletionPct,
    );
  }

  Future<String> createHabit({
    required String uid,
    required String name,
    required List<int> repeatDays,
    required int cfReward,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('habits')
        .add({
          'name': name.trim(),
          'repeatDays': repeatDays,
          'CFReward': cfReward <= 0 ? 2 : cfReward,
          'createdAt': FieldValue.serverTimestamp(),
        });
    return doc.id;
  }

  Future<void> updateHabit({
    required String uid,
    required String habitId,
    required String name,
    required List<int> repeatDays,
    required int cfReward,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('habits')
        .doc(habitId)
        .set({
          'name': name.trim(),
          'repeatDays': repeatDays,
          'CFReward': cfReward <= 0 ? 2 : cfReward,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> deleteHabit({
    required String uid,
    required String habitId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('habits')
        .doc(habitId)
        .delete();
  }

  Future<void> setHabitCompletedToday({
    required String uid,
    required String dateKey,
    required String habitId,
    required bool completed,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('habitLogs')
        .doc(dateKey)
        .collection('habits')
        .doc(habitId);

    if (!completed) {
      await ref.delete();
      return;
    }

    await ref.set({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createTask({
    required String uid,
    required String title,
    DateTime? dueDate,
    required int cfReward,
    required bool notificationEnabled,
  }) async {
    final doc = await _db.collection('users').doc(uid).collection('tasks').add({
      'title': title.trim(),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'completed': false,
      'CFReward': cfReward <= 0 ? 3 : cfReward,
      'notificationEnabled': notificationEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateTask({
    required String uid,
    required String taskId,
    required String title,
    DateTime? dueDate,
    required int cfReward,
    required bool notificationEnabled,
  }) async {
    await _db.collection('users').doc(uid).collection('tasks').doc(taskId).set({
      'title': title.trim(),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'CFReward': cfReward <= 0 ? 3 : cfReward,
      'notificationEnabled': notificationEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setTaskCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  }) async {
    await _db.collection('users').doc(uid).collection('tasks').doc(taskId).set({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTask({required String uid, required String taskId}) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Future<Map<String, dynamic>?> getUserHomeConfig({required String uid}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('home')
        .doc('config')
        .get();
    return snap.data();
  }

  Future<void> saveUserGoals({
    required String uid,
    required Map<String, dynamic> dailyGoal,
    required Map<String, dynamic> weeklyGoal,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('home')
        .doc('config')
        .set({
          'dailyGoal': dailyGoal,
          'weeklyGoal': weeklyGoal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> saveDailyHomeHeader({
    required String uid,
    required String dateKey,
    required String timeOfDay,
    required bool moodRegistered,
    required String moodIcon,
    Map<String, dynamic>? suggestion,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('homeDaily')
        .doc(dateKey)
        .set({
          'dateKey': dateKey,
          'timeOfDay': timeOfDay,
          'moodRegistered': moodRegistered,
          'moodIcon': moodIcon,
          ...?((suggestion == null) ? null : {'suggestion': suggestion}),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> saveDailyStatsSnapshot({
    required String uid,
    required String dateKey,
    required int cfIndex,
    required int steps,
    required int waterMl,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .doc(dateKey)
        .set({
          'dateKey': dateKey,
          'cfIndex': cfIndex.clamp(0, 100),
          'steps': steps < 0 ? 0 : steps,
          'waterLiters': ((waterMl < 0 ? 0 : waterMl) / 1000.0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getDailyHomeHeader({
    required String uid,
    required String dateKey,
  }) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('homeDaily')
        .doc(dateKey)
        .get();
    return snap.data();
  }

  Future<Map<String, dynamic>?> getDailyMood({
    required String uid,
    required String dateKey,
  }) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyMood')
        .doc(dateKey)
        .get();
    return snap.data();
  }

  Future<void> saveDailyMood({
    required String uid,
    required String dateKey,
    required String emoji,
    required int energy,
    required int mood,
    required int stress,
    required int sleep,
    required List<String> tags,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('dailyMood')
        .doc(dateKey)
        .set({
          'dateKey': dateKey,
          'emoji': emoji,
          'energy': energy.clamp(1, 5),
          'mood': mood.clamp(1, 5),
          'stress': stress.clamp(1, 5),
          'sleep': sleep.clamp(1, 5),
          'tags': tags,
          'registered': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getDailyInsight({
    required String uid,
    required String dateKey,
  }) async {
    final dailyStats = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyStats')
        .doc(dateKey)
        .get();
    final dailyMood = await _db
        .collection('users')
        .doc(uid)
        .collection('dailyMood')
        .doc(dateKey)
        .get();
    final homeDaily = await _db
        .collection('users')
        .doc(uid)
        .collection('homeDaily')
        .doc(dateKey)
        .get();

    final s = dailyStats.data() ?? const <String, dynamic>{};
    final m = dailyMood.data() ?? const <String, dynamic>{};
    final h = homeDaily.data() ?? const <String, dynamic>{};

    return {
      'steps': _asInt(s['steps']),
      'waterLiters': (s['waterLiters'] is num)
          ? (s['waterLiters'] as num).toDouble()
          : 0.0,
      'cfIndex': _asInt(s['cfIndex']),
      'workoutCompleted': s['workoutCompleted'] == true,
      'mealsLoggedCount': _asInt(s['mealsLoggedCount']),
      'meditationMinutes': _asInt(s['meditationMinutes']),
      'moodRegistered': m.isNotEmpty || h['moodRegistered'] == true,
      'moodIcon': ((m['emoji'] as String?) ?? (h['moodIcon'] as String?) ?? '')
          .trim(),
      'moodValue': _asInt(m['mood']),
    };
  }

  Future<List<int>> getStepStats({
    required String uid,
    required int days,
  }) async {
    final safeDays = days <= 0 ? 1 : days;
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dates = List<DateTime>.generate(
      safeDays,
      (index) => today.subtract(Duration(days: safeDays - 1 - index)),
    );
    final snapshots = await Future.wait(
      dates.map(
        (date) => _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .doc(DateUtilsCF.toKey(date))
            .get(),
      ),
    );
    return snapshots.map((snap) => _asInt(snap.data()?['steps'])).toList();
  }

  Future<List<int>> getCfStats({required String uid, required int days}) async {
    final safeDays = days <= 0 ? 1 : days;
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dates = List<DateTime>.generate(
      safeDays,
      (index) => today.subtract(Duration(days: safeDays - 1 - index)),
    );
    final snapshots = await Future.wait(
      dates.map(
        (date) => _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .doc(DateUtilsCF.toKey(date))
            .get(),
      ),
    );
    return snapshots.map((snap) => _asInt(snap.data()?['cfIndex'])).toList();
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<int> _asIntList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) {
          if (e is int) return e;
          if (e is num) return e.round();
          return int.tryParse(e.toString());
        })
        .whereType<int>()
        .where((e) => e >= 1 && e <= 7)
        .toList();
  }

  String _weekdayShort(DateTime d) {
    const names = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return names[d.weekday - 1];
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateUtilsCF.dateOnly(d);
    final delta = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: delta < 0 ? 0 : delta));
  }

  Future<int> _computeStreak({
    required String uid,
    required DateTime today,
    required UserProfile? profile,
  }) async {
    var streak = 0;
    for (var i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      final key = DateUtilsCF.toKey(date);
      final userRef = _db.collection('users').doc(uid);
      final statsSnap = await userRef.collection('dailyStats').doc(key).get();
      final homeSnap = await userRef.collection('homeDaily').doc(key).get();
      final moodSnap = await userRef.collection('dailyMood').doc(key).get();

      final stats = statsSnap.data() ?? const <String, dynamic>{};

      // If today has not been persisted yet, don't break streak continuity.
      if (i == 0 && stats.isEmpty) {
        continue;
      }

      final done = _streakService.isCompletedDay(
        profile: profile,
        snapshot: PersonalizedStreakDaySnapshot.fromDailyStatsMap(
          stats,
          moodRegistered: moodSnap.exists || homeSnap.data()?['moodRegistered'] == true,
          hasData: stats.isNotEmpty,
        ),
      );
      if (!done) break;
      streak += 1;
    }
    return streak;
  }

  Future<int> _computeWeeklyStreak({
    required String uid,
    required DateTime currentWeekStart,
    required UserProfile? profile,
  }) async {
    var streak = 0;
    for (var i = 0; i < 10; i++) {
      final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
      final weekId = DateUtilsCF.toKey(weekStart);
      final userRef = _db.collection('users').doc(uid);
      final snap = await userRef.collection('weeklyStats').doc(weekId).get();
      final data = snap.data() ?? const <String, dynamic>{};

      var done =
          _asInt(data['completedGoals']) >= 2 ||
          (data['progress'] is num && (data['progress'] as num) >= 0.5);

      if (!done) {
        final daySnaps = await Future.wait(
          List.generate(
            7,
            (d) => userRef
                .collection('dailyStats')
                .doc(DateUtilsCF.toKey(weekStart.add(Duration(days: d))))
                .get(),
          ),
        );
        var activeDays = 0;
        var anyData = false;
        for (final day in daySnaps) {
          final stats = day.data() ?? const <String, dynamic>{};
          if (stats.isNotEmpty) anyData = true;
          final active = _streakService.isCompletedDay(
            profile: profile,
            snapshot: PersonalizedStreakDaySnapshot.fromDailyStatsMap(
              stats,
              hasData: stats.isNotEmpty,
            ),
          );
          if (active) activeDays += 1;
        }

        if (i == 0 && !anyData) {
          continue;
        }
        done = activeDays >= 4;
      }

      if (!done) break;
      streak += 1;
    }
    return streak;
  }
}
