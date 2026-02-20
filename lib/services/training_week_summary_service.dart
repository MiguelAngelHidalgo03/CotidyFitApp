import '../models/training_week_summary.dart';
import '../models/workout_plan.dart';
import '../services/workout_history_service.dart';
import '../services/workout_plan_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';

class TrainingWeekSummaryService {
  TrainingWeekSummaryService({
    WorkoutPlanService? plans,
    WorkoutHistoryService? history,
    WorkoutService? workouts,
  }) : _plans = plans ?? WorkoutPlanService(),
       _history = history ?? WorkoutHistoryService(),
       _workouts = workouts ?? const WorkoutService();

  final WorkoutPlanService _plans;
  final WorkoutHistoryService _history;
  final WorkoutService _workouts;

  static DateTime mondayOf(DateTime d) {
    final day = DateUtilsCF.dateOnly(d);
    final weekday = day.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return day.subtract(Duration(days: delta));
  }

  Future<TrainingWeekSummary> getCurrentWeekSummary() async {
    return getSummaryForWeekStart(mondayOf(DateTime.now()));
  }

  Future<TrainingWeekSummary> getSummaryForWeekStart(DateTime weekStart) async {
    final ws = mondayOf(weekStart);
    final planKey = DateUtilsCF.toKey(ws);
    final plan = await _plans.getPlanForWeekKey(planKey);
    final normalizedPlan =
        plan ?? WeekPlan(weekStart: ws, assignments: const {});

    final assignments = normalizedPlan.assignments;
    final plannedDays = assignments.keys.toSet();

    var plannedMinutes = 0;
    for (final workoutId in assignments.values) {
      final w = _workouts.getWorkoutById(workoutId);
      plannedMinutes += (w?.durationMinutes ?? 0);
    }

    final completedByDate = await _history.getCompletedWorkoutsByDate();

    var activeDays = 0;
    var completedPlannedDays = 0;

    for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
      final day = ws.add(Duration(days: dayIndex));
      final key = DateUtilsCF.toKey(day);
      final completed = completedByDate.containsKey(key);
      if (completed) activeDays++;
      if (completed && plannedDays.contains(dayIndex)) {
        completedPlannedDays++;
      }
    }

    return TrainingWeekSummary(
      weekStart: ws,
      assignedWorkouts: plannedDays.length,
      plannedMinutes: plannedMinutes,
      plannedActiveDays: plannedDays.length,
      activeDays: activeDays,
      completedPlannedDays: completedPlannedDays,
    );
  }
}
