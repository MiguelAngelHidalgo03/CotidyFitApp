import '../models/workout.dart';
import '../services/achievements_service.dart';
import '../services/workout_history_service.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';

class WorkoutSessionService {
  static const int cfBonus = 20;

  WorkoutSessionService({
    LocalStorageService? storage,
    WorkoutHistoryService? history,
      AchievementsService? achievements,
  })  : _storage = storage ?? LocalStorageService(),
      _history = history ?? WorkoutHistoryService(),
      _achievements = achievements ?? AchievementsService();

  final LocalStorageService _storage;
  final WorkoutHistoryService _history;
    final AchievementsService _achievements;

  Future<bool> isWorkoutCompletedForDate(String dateKey) async {
    final name = await _history.getCompletedWorkoutName(dateKey);
    return name != null;
  }

  Future<void> markWorkoutCompleted({required String dateKey, required String workoutName}) async {
    await _history.upsertCompletedWorkoutForDate(
      dateKey: dateKey,
      workoutName: workoutName,
    );
  }

  Future<String?> getCompletedWorkoutName(String dateKey) async {
    return _history.getCompletedWorkoutName(dateKey);
  }

  Future<void> completeWorkoutAndApplyBonus({required Workout workout}) async {
    final now = DateTime.now();
    final dateKey = DateUtilsCF.toKey(now);

    // Mark completion.
    await markWorkoutCompleted(dateKey: dateKey, workoutName: workout.name);

    // Compute today's base CF.
    final entry = await _storage.getTodayEntry();
    final baseCf = (entry != null && entry.dateKey == dateKey) ? entry.cfIndex : 0;

    // Apply bonus on top of existing history (if any) and base CF.
    final history = await _storage.getCfHistory();
    final existing = history[dateKey] ?? baseCf;

    // Ensure bonus is present exactly once by using (base + bonus) as target,
    // and never decreasing an already higher value.
    final target = (baseCf + cfBonus).clamp(0, 100);
    final finalCf = (existing > target ? existing : target).clamp(0, 100);

    await _storage.upsertCfForDate(dateKey: dateKey, cf: finalCf);

    final uid = _achievements.currentUid;
    if (uid != null) {
      try {
        await _achievements.checkAchievements(uid);
      } catch (_) {}
    }
  }
}
