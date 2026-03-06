import 'package:flutter/foundation.dart';

@immutable
class TrendMetric {
  const TrendMetric({required this.current, required this.previous});

  final double current;
  final double previous;

  double get delta => current - previous;
  bool get isUp => delta > 0;
}

@immutable
class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class RadarMetric {
  const RadarMetric({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class ProgressGeneralSummary {
  const ProgressGeneralSummary({
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStreak,
    required this.monthlyDailyGoalsPercent,
    required this.weeklyGoalsPercent,
    required this.monthlyAverageCf,
    required this.realConstancyIndex,
    required this.weeklyGlobalScore,
    required this.monthlyDailyGoalsTrend,
    required this.weeklyGoalsTrend,
    required this.cfTrend,
    required this.weeklyAverageSteps,
    required this.weeklyStepsStreakOver8k,
    required this.weeklyWorkouts,
    required this.weeklyWorkoutStreak,
    required this.weeklyTrainedMinutes,
    required this.weeklyHealthyEatingDays,
    required this.weeklyHealthyEatingStreak,
    required this.topWeeklyGoal,
    required this.weekStateAverage,
    required this.weekEnergyAverage,
    required this.weekStressAverage,
    required this.weekMoodAverage,
    required this.weekSleepAverage,
  });

  final int currentStreak;
  final int bestStreak;
  final int weeklyStreak;
  final int monthlyDailyGoalsPercent;
  final int weeklyGoalsPercent;
  final int monthlyAverageCf;
  final int realConstancyIndex;
  final int weeklyGlobalScore;
  final TrendMetric monthlyDailyGoalsTrend;
  final TrendMetric weeklyGoalsTrend;
  final TrendMetric cfTrend;

  final int weeklyAverageSteps;
  final int weeklyStepsStreakOver8k;
  final int weeklyWorkouts;
  final int weeklyWorkoutStreak;
  final int weeklyTrainedMinutes;
  final int weeklyHealthyEatingDays;
  final int weeklyHealthyEatingStreak;
  final String topWeeklyGoal;
  final double weekStateAverage;
  final double weekEnergyAverage;
  final double weekStressAverage;
  final double weekMoodAverage;
  final double weekSleepAverage;
}

@immutable
class ProgressTrainingSummary {
  const ProgressTrainingSummary({
    required this.totalWorkouts,
    required this.totalMinutes,
    required this.mostPerformedExercises,
    required this.mostTrainedMuscleGroup,
    required this.personalRecords,
    required this.estimatedLevel,
    required this.programAdherencePercent,
    required this.weeklyTrend,
    required this.strengthByExercise,
  });

  final int totalWorkouts;
  final int totalMinutes;
  final List<String> mostPerformedExercises;
  final String mostTrainedMuscleGroup;
  final int personalRecords;
  final String estimatedLevel;
  final int programAdherencePercent;
  final TrendMetric weeklyTrend;
  final Map<String, List<ChartPoint>> strengthByExercise;
}

@immutable
class ProgressActivitySummary {
  const ProgressActivitySummary({
    required this.averageDailySteps,
    required this.bestStepDayLabel,
    required this.bestStepDaySteps,
    required this.totalDistanceKm,
    required this.estimatedStandingMinutes,
    required this.activeDaysStreak,
    required this.daysOver8000,
    required this.stepsChart,
    required this.activityHeatmap,
  });

  final int averageDailySteps;
  final String bestStepDayLabel;
  final int bestStepDaySteps;
  final double totalDistanceKm;
  final int estimatedStandingMinutes;
  final int activeDaysStreak;
  final int daysOver8000;
  final List<ChartPoint> stepsChart;
  final List<int> activityHeatmap;
}

@immutable
class ProgressNutritionSummary {
  const ProgressNutritionSummary({
    required this.weeklyCalorieBalance,
    required this.mostRepeatedMeal,
    required this.highProteinDays,
    required this.daysMeetingCalorieGoal,
    required this.averageMonthlyCalories,
    required this.macroDistribution,
    required this.caloriesTrend,
    required this.smoothedWeightTrend,
  });

  final int weeklyCalorieBalance;
  final String mostRepeatedMeal;
  final int highProteinDays;
  final int daysMeetingCalorieGoal;
  final int averageMonthlyCalories;
  final Map<String, double> macroDistribution;
  final List<ChartPoint> caloriesTrend;
  final List<ChartPoint> smoothedWeightTrend;
}

@immutable
class ProgressGoalsSummary {
  const ProgressGoalsSummary({
    required this.dailyCompletionPercent,
    required this.weeklyCompletionPercent,
    required this.weeklyStreak,
    required this.categoryBreakdown,
  });

  final int dailyCompletionPercent;
  final int weeklyCompletionPercent;
  final int weeklyStreak;
  final Map<String, int> categoryBreakdown;
}

@immutable
class ProgressAchievementsSummary {
  const ProgressAchievementsSummary({
    required this.unlocked,
    required this.inProgress,
    required this.rarest,
    required this.byCategory,
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
  });

  final int unlocked;
  final int inProgress;
  final List<String> rarest;
  final Map<String, int> byCategory;
  final int level;
  final int currentXp;
  final int nextLevelXp;
}

@immutable
class ProgressAdvancedSummary {
  const ProgressAdvancedSummary({
    required this.healthyLifeBalanceScore,
    required this.historicalStreakTimeline,
    required this.moodEvolution,
    required this.bestVersionMonth,
    required this.radarMetrics,
    required this.waterTrend,
    required this.cfTrend,
    required this.monthMoodAverage,
    required this.monthEnergyAverage,
    required this.monthStressAverage,
    required this.monthSleepAverage,
    required this.monthAnimatedAverage,
  });

  final int healthyLifeBalanceScore;
  final List<ChartPoint> historicalStreakTimeline;
  final List<ChartPoint> moodEvolution;
  final String bestVersionMonth;
  final List<RadarMetric> radarMetrics;
  final List<ChartPoint> waterTrend;
  final List<ChartPoint> cfTrend;
  final double monthMoodAverage;
  final double monthEnergyAverage;
  final double monthStressAverage;
  final double monthSleepAverage;
  final double monthAnimatedAverage;
}

@immutable
class ProgressWeightSummaryExtended {
  const ProgressWeightSummaryExtended({
    required this.rawTrend,
    required this.smoothedTrend,
    required this.monthlyComparison,
    required this.bestMonth,
    required this.changeFromLastMonthPercent,
    required this.context,
    required this.currentWeight,
    required this.currentWeightLabel,
  });

  final List<ChartPoint> rawTrend;
  final List<ChartPoint> smoothedTrend;
  final double monthlyComparison;
  final String bestMonth;
  final double changeFromLastMonthPercent;
  final String context;

  final double? currentWeight;
  final String currentWeightLabel;
}

@immutable
class ProgressInsightItem {
  const ProgressInsightItem(this.text);

  final String text;
}

@immutable
class ProgressAdvancedAnalytics {
  const ProgressAdvancedAnalytics({
    required this.general,
    required this.training,
    required this.activity,
    required this.nutrition,
    required this.goals,
    required this.achievements,
    required this.advanced,
    required this.weight,
    required this.insights,
  });

  final ProgressGeneralSummary general;
  final ProgressTrainingSummary training;
  final ProgressActivitySummary activity;
  final ProgressNutritionSummary nutrition;
  final ProgressGoalsSummary goals;
  final ProgressAchievementsSummary achievements;
  final ProgressAdvancedSummary advanced;
  final ProgressWeightSummaryExtended weight;
  final List<ProgressInsightItem> insights;
}
