import 'package:flutter/foundation.dart';

@immutable
class ProgressWeekSummary {
  const ProgressWeekSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.cfWeekAverage,
    required this.activeDays,
    required this.trainedMinutes,
    required this.energyAverage,
    required this.hydrationAverageLiters,
    required this.hydrationAveragePercent,
    required this.nutritionCompliancePercent,
    required this.mealsLogged,
    required this.mealsTarget,
    required this.proteinTotalG,
    required this.carbsTotalG,
    required this.fatTotalG,
    required this.proteinPerMealG,
    required this.nutritionLabel,
    required this.nutritionMessage,
    required this.proteinTargetDailyG,
    required this.carbsTargetDailyG,
    required this.fatTargetDailyG,
    required this.proteinCompliancePercent,
    required this.carbsCompliancePercent,
    required this.fatCompliancePercent,
    required this.nutritionAdjustments,
    required this.todayMealsLogged,
    required this.todayCalories,
    required this.todayCaloriesTarget,
    required this.todayRecommendation,
    required this.todayNeedsNutritionAction,
  });

  final DateTime weekStart;
  final DateTime weekEnd;

  final int cfWeekAverage;

  final int activeDays; // 0..7
  final int trainedMinutes;

  /// Average of daily energy ratings (1..5). Null if no data.
  final double? energyAverage;

  final double hydrationAverageLiters;
  final int hydrationAveragePercent; // 0..100, vs DailyDataService.waterLitersTarget

  final int nutritionCompliancePercent; // 0..100
  final int mealsLogged;
  final int mealsTarget;

  final int proteinTotalG;
  final int carbsTotalG;
  final int fatTotalG;
  final double proteinPerMealG;

  /// One of: "Baja proteína", "Irregularidad", "Buena consistencia".
  final String nutritionLabel;
  final String nutritionMessage;

  final int proteinTargetDailyG;
  final int carbsTargetDailyG;
  final int fatTargetDailyG;

  final int proteinCompliancePercent;
  final int carbsCompliancePercent;
  final int fatCompliancePercent;

  final List<String> nutritionAdjustments;

  final int todayMealsLogged;
  final int todayCalories;
  final int todayCaloriesTarget;
  final String todayRecommendation;
  final bool todayNeedsNutritionAction;
}
