import '../models/workout.dart';
import '../services/workout_history_service.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';

class WorkoutSessionService {
  static const int cfBonus = 20;

  WorkoutSessionService({
    LocalStorageService? storage,
    WorkoutHistoryService? history,
  })  : _storage = storage ?? LocalStorageService(),
        _history = history ?? WorkoutHistoryService();

  final LocalStorageService _storage;
  final WorkoutHistoryService _history;

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
  }
}
