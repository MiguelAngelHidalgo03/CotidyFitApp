import '../models/user_profile.dart';
import '../utils/date_utils.dart';
import 'daily_data_service.dart';

class PersonalizedStreakDaySnapshot {
  const PersonalizedStreakDaySnapshot({
    this.workoutCompleted = false,
    this.steps = 0,
    this.mealsLoggedCount = 0,
    this.meditationMinutes = 0,
    this.waterLiters = 0,
    this.cf = 0,
    this.moodRegistered = false,
    this.hasData = false,
  });

  final bool workoutCompleted;
  final int steps;
  final int mealsLoggedCount;
  final int meditationMinutes;
  final double waterLiters;
  final int cf;
  final bool moodRegistered;
  final bool hasData;

  bool get hasTrackedData =>
      hasData ||
      workoutCompleted ||
      steps > 0 ||
      mealsLoggedCount > 0 ||
      meditationMinutes > 0 ||
      waterLiters > 0 ||
      cf > 0 ||
      moodRegistered;

  bool get dailyChallengeCompleted =>
      workoutCompleted && waterLiters >= 2.0 && meditationMinutes >= 5;

  static PersonalizedStreakDaySnapshot fromDailyStatsMap(
    Map<String, dynamic> stats, {
    bool moodRegistered = false,
    bool hasData = false,
  }) {
    final waterLiters = stats['waterLiters'] is num
        ? (stats['waterLiters'] as num).toDouble()
        : (stats['waterMl'] is num)
            ? ((stats['waterMl'] as num).toDouble() / 1000.0)
            : 0.0;

    return PersonalizedStreakDaySnapshot(
      workoutCompleted: stats['workoutCompleted'] == true,
      steps: _asInt(stats['steps']),
      mealsLoggedCount: _asInt(stats['mealsLoggedCount']),
      meditationMinutes: _asInt(stats['meditationMinutes']),
      waterLiters: waterLiters,
      cf: _asInt(stats['cfIndex']),
      moodRegistered: moodRegistered,
      hasData: hasData || stats.isNotEmpty,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

class PersonalizedStreakService {
  const PersonalizedStreakService();

  UserStreakPreferences preferencesFor(UserProfile? profile) {
    return profile?.effectiveStreakPreferences ??
        UserStreakPreferences.defaultTraining;
  }

  String streakTitleFor(UserProfile? profile) {
    final prefs = preferencesFor(profile);
    if (!prefs.isMultiFocus) return prefs.focusAreas.first.label;
    return prefs.chipLabel;
  }

  String streakSummaryFor(UserProfile? profile) {
    return preferencesFor(profile).summary;
  }

  String shareSummaryFor(
    UserProfile? profile, {
    required int current,
    required int best,
  }) {
    final title = streakTitleFor(profile);
    return 'Racha de $title: $current dias · Mejor: $best dias';
  }

  bool isCompletedDay({
    required UserProfile? profile,
    required PersonalizedStreakDaySnapshot snapshot,
  }) {
    final prefs = preferencesFor(profile);
    final focusAreas = prefs.focusAreas.isEmpty
        ? UserStreakPreferences.defaultTraining.focusAreas
        : prefs.focusAreas;

    final hits = focusAreas
        .where((area) => isFocusAreaCompleted(area, snapshot: snapshot))
        .length;

    if (focusAreas.length <= 1 || prefs.mixMode == UserStreakMixMode.any) {
      return hits > 0;
    }
    return hits == focusAreas.length;
  }

  bool isFocusAreaCompleted(
    UserStreakFocusArea area, {
    required PersonalizedStreakDaySnapshot snapshot,
  }) {
    switch (area) {
      case UserStreakFocusArea.nutrition:
        return snapshot.mealsLoggedCount >= DailyDataService.mealsTarget;
      case UserStreakFocusArea.training:
        return snapshot.workoutCompleted;
      case UserStreakFocusArea.water:
        return snapshot.waterLiters >= DailyDataService.waterLitersTarget;
      case UserStreakFocusArea.steps:
        return snapshot.steps >= DailyDataService.stepsTarget;
      case UserStreakFocusArea.dailyChallenge:
        return snapshot.dailyChallengeCompleted;
    }
  }

  int currentStreak(List<bool> flags) {
    var count = 0;
    for (var i = flags.length - 1; i >= 0; i--) {
      if (!flags[i]) break;
      count += 1;
    }
    return count;
  }

  int bestStreak(List<bool> flags) {
    var best = 0;
    var current = 0;
    for (final flag in flags) {
      if (flag) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  int weeklyStreakFromSnapshots({
    required UserProfile? profile,
    required Map<String, PersonalizedStreakDaySnapshot> snapshots,
    required DateTime today,
    int lookbackWeeks = 52,
  }) {
    final currentWeekStart = _mondayOf(today);
    var streak = 0;

    for (var weekIndex = 0; weekIndex < lookbackWeeks; weekIndex++) {
      final weekStart = currentWeekStart.subtract(Duration(days: weekIndex * 7));
      var completedDays = 0;
      var hasAnyData = false;

      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        final day = weekStart.add(Duration(days: dayOffset));
        if (day.isAfter(today)) continue;
        final snapshot = snapshots[DateUtilsCF.toKey(day)];
        if (snapshot == null) continue;
        if (snapshot.hasTrackedData) hasAnyData = true;
        if (isCompletedDay(profile: profile, snapshot: snapshot)) {
          completedDays += 1;
        }
      }

      if (weekIndex == 0 && !hasAnyData) {
        continue;
      }
      if (completedDays < 4) {
        break;
      }
      streak += 1;
    }

    return streak;
  }

  DateTime _mondayOf(DateTime date) {
    final normalized = DateUtilsCF.dateOnly(date);
    final delta = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta < 0 ? 0 : delta));
  }
}
