import 'package:cotidyfitapp/models/progress_advanced_analytics.dart';
import 'package:cotidyfitapp/widgets/progress/progress_advanced_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analytics = ProgressAdvancedAnalytics(
    general: ProgressGeneralSummary(
      currentStreak: 3,
      bestStreak: 7,
      weeklyStreak: 2,
      monthlyDailyGoalsPercent: 54,
      weeklyGoalsPercent: 61,
      monthlyAverageCf: 68,
      realConstancyIndex: 50,
      weeklyGlobalScore: 57,
      monthlyDailyGoalsTrend: TrendMetric(current: 54, previous: 49),
      weeklyGoalsTrend: TrendMetric(current: 61, previous: 55),
      cfTrend: TrendMetric(current: 68, previous: 63),
      weeklyAverageSteps: 7200,
      weeklyStepsStreakOver8k: 2,
      weeklyWorkouts: 3,
      weeklyWorkoutStreak: 2,
      weeklyTrainedMinutes: 95,
      weeklyHealthyEatingDays: 4,
      weeklyHealthyEatingStreak: 2,
      topWeeklyGoal: 'Entrenamiento',
      weekStateAverage: 3.6,
      weekEnergyAverage: 3.8,
      weekStressAverage: 2.2,
      weekMoodAverage: 3.7,
      weekSleepAverage: 3.4,
    ),
    training: ProgressTrainingSummary(
      totalWorkouts: 8,
      totalMinutes: 220,
      mostPerformedExercises: <String>['Sentadilla'],
      mostTrainedMuscleGroup: 'Pierna',
      personalRecords: 1,
      estimatedLevel: 'Intermedio',
      programAdherencePercent: 72,
      weeklyTrend: TrendMetric(current: 3, previous: 2),
      strengthByExercise: <String, List<ChartPoint>>{},
    ),
    activity: ProgressActivitySummary(
      averageDailySteps: 7200,
      bestStepDayLabel: 'Lunes',
      bestStepDaySteps: 10420,
      totalDistanceKm: 18.4,
      estimatedStandingMinutes: 310,
      activeDaysStreak: 3,
      daysOver8000: 2,
      stepsChart: <ChartPoint>[ChartPoint(label: 'Hoy', value: 7200)],
      activityHeatmap: <int>[1, 0, 1, 1, 0, 0, 1],
    ),
    nutrition: ProgressNutritionSummary(
      weeklyCalorieBalance: 120,
      mostRepeatedMeal: 'Pollo con arroz',
      highProteinDays: 4,
      daysMeetingCalorieGoal: 3,
      averageMonthlyCalories: 1980,
      macroDistribution: <String, double>{
        'Proteínas': 32,
        'Carbos': 43,
        'Grasas': 25,
      },
      caloriesTrend: <ChartPoint>[ChartPoint(label: 'Hoy', value: 1980)],
      smoothedWeightTrend: <ChartPoint>[],
    ),
    goals: ProgressGoalsSummary(
      dailyCompletionPercent: 54,
      weeklyCompletionPercent: 61,
      weeklyStreak: 2,
      categoryBreakdown: <String, int>{
        'Entrenamiento': 84,
        'Nutrición': 62,
        'Salud': 48,
        'Mental': 40,
      },
    ),
    achievements: ProgressAchievementsSummary(
      unlocked: 3,
      inProgress: 1,
      rarest: <String>[],
      byCategory: <String, int>{},
      level: 1,
      currentXp: 10,
      nextLevelXp: 100,
    ),
    advanced: ProgressAdvancedSummary(
      healthyLifeBalanceScore: 58,
      historicalStreakTimeline: <ChartPoint>[],
      moodEvolution: <ChartPoint>[],
      bestVersionMonth: 'Marzo',
      radarMetrics: <RadarMetric>[],
      waterTrend: <ChartPoint>[],
      cfTrend: <ChartPoint>[],
      monthMoodAverage: 3.4,
      monthEnergyAverage: 3.5,
      monthStressAverage: 2.3,
      monthSleepAverage: 3.2,
      monthAnimatedAverage: 0,
    ),
    weight: ProgressWeightSummaryExtended(
      rawTrend: <ChartPoint>[],
      smoothedTrend: <ChartPoint>[],
      monthlyComparison: 0,
      bestMonth: 'Marzo',
      changeFromLastMonthPercent: 0,
      context: 'Sin datos',
      currentWeight: null,
      currentWeightLabel: 'Sin datos',
    ),
    insights: <ProgressInsightItem>[
      ProgressInsightItem('Buen ritmo esta semana.'),
    ],
  );

  testWidgets('Goals chart compacts labels on narrow mobile widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressAdvancedDashboard(
              analytics: analytics,
              onAddWeight: () {},
              userName: 'Tester',
              currentCf: 68,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Entreno'), findsOneWidget);
    expect(find.text('Nutri.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
