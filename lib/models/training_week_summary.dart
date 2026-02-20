import 'package:flutter/foundation.dart';

@immutable
class TrainingWeekSummary {
  const TrainingWeekSummary({
    required this.weekStart,
    required this.assignedWorkouts,
    required this.plannedMinutes,
    required this.plannedActiveDays,
    required this.activeDays,
    required this.completedPlannedDays,
  });

  final DateTime weekStart;

  /// Number of days with an assigned workout in the plan.
  final int assignedWorkouts;

  /// Total minutes planned for the week based on assigned workouts.
  final int plannedMinutes;

  /// Days with training assigned (0..7).
  final int plannedActiveDays;

  /// Days with a completed workout in this week (0..7), regardless of assignment.
  final int activeDays;

  /// Days that were both planned and completed (0..7).
  final int completedPlannedDays;

  double get weeklyProgress {
    if (plannedActiveDays <= 0) return 0;
    return (completedPlannedDays / plannedActiveDays).clamp(0.0, 1.0);
  }
}
