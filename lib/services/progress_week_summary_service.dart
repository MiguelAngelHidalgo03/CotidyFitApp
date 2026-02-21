import '../models/progress_week_summary.dart';
import '../models/recipe_model.dart';
import '../services/daily_data_service.dart';
import '../services/local_storage_service.dart';
import '../services/my_day_repository.dart';
import '../services/my_day_repository_factory.dart';
import '../services/recipe_repository.dart';
import '../services/recipes_repository_factory.dart';
import '../services/workout_history_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';

class ProgressWeekSummaryService {
  ProgressWeekSummaryService({
    LocalStorageService? storage,
    DailyDataService? daily,
    WorkoutHistoryService? workoutHistory,
    WorkoutService? workouts,
    MyDayRepository? myDay,
    RecipeRepository? recipes,
  })  : _storage = storage ?? LocalStorageService(),
        _daily = daily ?? DailyDataService(),
        _workoutHistory = workoutHistory ?? WorkoutHistoryService(),
        _workouts = workouts ?? const WorkoutService(),
        _myDay = myDay ?? MyDayRepositoryFactory.create(),
        _recipes = recipes ?? RecipesRepositoryFactory.create();

  final LocalStorageService _storage;
  final DailyDataService _daily;
  final WorkoutHistoryService _workoutHistory;
  final WorkoutService _workouts;
  final MyDayRepository _myDay;
  final RecipeRepository _recipes;

  Future<ProgressWeekSummary> getCurrentWeekSummary() async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final weekStart = _mondayOf(today);
    final weekEnd = weekStart.add(const Duration(days: 6));

    final cfHistory = await _storage.getCfHistory();
    final completedByDate = await _workoutHistory.getCompletedWorkoutsByDate();

    // Workouts duration map by name.
    final byName = <String, int>{};
    for (final w in _workouts.getAllWorkouts()) {
      byName[w.name] = w.durationMinutes;
    }

    // Nutrition: fetch all MyDay entries once and group by date.
    final allMyDay = await _myDay.getAll();
    final entriesByDate = <String, List<MealType>>{};
    final recipeIdsByDate = <String, List<String>>{};

    for (final e in allMyDay) {
      final d = e.dateKey;
      entriesByDate.putIfAbsent(d, () => <MealType>[]).add(e.mealType);
      recipeIdsByDate.putIfAbsent(d, () => <String>[]).add(e.recipeId);
    }

    // Recipes for protein estimate.
    final recipeList = await _recipes.getAllRecipes();
    final macrosByRecipeId = <String, RecipeMacros>{};
    for (final r in recipeList) {
      macrosByRecipeId[r.id] = r.macrosPerServing;
    }

    var activeDays = 0;
    var trainedMinutes = 0;

    final energyValues = <int>[];
    var hydrationSum = 0.0;

    var cfSum = 0;
    var cfCount = 0;

    var mealsLogged = 0;
    final mealsTarget = DailyDataService.mealsTarget * 7;

    var proteinTotal = 0;
    var carbsTotal = 0;
    var fatTotal = 0;
    var mealEntriesCount = 0;

    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final key = DateUtilsCF.toKey(d);

      final cf = (cfHistory[key] ?? 0).clamp(0, 100);
      if (cf > 0) {
        cfSum += cf;
        cfCount += 1;
      }

      if (completedByDate.containsKey(key)) {
        activeDays += 1;
        final name = completedByDate[key];
        if (name != null) trainedMinutes += (byName[name] ?? 20);
      }

      final daily = await _daily.getForDateKey(key);
      final e = daily.energy;
      if (e != null) energyValues.add(e.clamp(1, 5));
      hydrationSum += (daily.waterLiters.isNaN || daily.waterLiters.isInfinite)
          ? 0
          : (daily.waterLiters < 0 ? 0 : daily.waterLiters);

      final mealTypes = entriesByDate[key] ?? const <MealType>[];
        final customMealTypes = daily.customMeals.map((m) => m.mealType);
        final uniqueMeals = <MealType>{...mealTypes, ...customMealTypes}.length;
      final capped = uniqueMeals.clamp(0, DailyDataService.mealsTarget);
      mealsLogged += capped;

      final recipeIds = recipeIdsByDate[key] ?? const <String>[];
      for (final id in recipeIds) {
        final macros = macrosByRecipeId[id];
        if (macros == null) continue;
        proteinTotal += (macros.proteinG < 0 ? 0 : macros.proteinG);
        carbsTotal += (macros.carbsG < 0 ? 0 : macros.carbsG);
        fatTotal += (macros.fatG < 0 ? 0 : macros.fatG);
      }
      mealEntriesCount += recipeIds.length;

      for (final cm in daily.customMeals) {
        proteinTotal += (cm.meal.proteinas < 0 ? 0 : cm.meal.proteinas);
        carbsTotal += (cm.meal.carbohidratos < 0 ? 0 : cm.meal.carbohidratos);
        fatTotal += (cm.meal.grasas < 0 ? 0 : cm.meal.grasas);
      }
      mealEntriesCount += daily.customMeals.length;
    }

    final cfWeekAvg = cfCount == 0 ? 0 : (cfSum / cfCount).round().clamp(0, 100);

    final hydrationAvgLiters = hydrationSum / 7;
    final hydrationPercent = DailyDataService.waterLitersTarget <= 0
        ? 0
        : ((hydrationAvgLiters / DailyDataService.waterLitersTarget) * 100)
            .round()
            .clamp(0, 100);

    final energyAvg = energyValues.isEmpty ? null : (energyValues.reduce((a, b) => a + b) / energyValues.length);

    final nutritionPercent = mealsTarget <= 0 ? 0 : ((mealsLogged / mealsTarget) * 100).round().clamp(0, 100);

    final proteinPerMeal = mealEntriesCount == 0 ? 0.0 : (proteinTotal / mealEntriesCount);

    final (nutritionLabel, nutritionMessage) = _nutritionAnalysis(
      nutritionPercent: nutritionPercent,
      proteinPerMeal: proteinPerMeal,
      activeDays: activeDays,
    );

    return ProgressWeekSummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      cfWeekAverage: cfWeekAvg,
      activeDays: activeDays.clamp(0, 7),
      trainedMinutes: trainedMinutes < 0 ? 0 : trainedMinutes,
      energyAverage: energyAvg,
      hydrationAverageLiters: hydrationAvgLiters < 0 ? 0 : hydrationAvgLiters,
      hydrationAveragePercent: hydrationPercent,
      nutritionCompliancePercent: nutritionPercent,
      mealsLogged: mealsLogged,
      mealsTarget: mealsTarget,
      proteinTotalG: proteinTotal,
      carbsTotalG: carbsTotal,
      fatTotalG: fatTotal,
      proteinPerMealG: proteinPerMeal,
      nutritionLabel: nutritionLabel,
      nutritionMessage: nutritionMessage,
    );
  }

  (String, String) _nutritionAnalysis({
    required int nutritionPercent,
    required double proteinPerMeal,
    required int activeDays,
  }) {
    if (nutritionPercent >= 75 && proteinPerMeal >= 20) {
      return (
        'Buena consistencia',
        activeDays >= 3
            ? 'Buena semana: comidas registradas y proteína sólida. Sigue así.'
            : 'Constancia alta. Añadir 1 entreno ligero haría el combo perfecto.',
      );
    }

    if (nutritionPercent >= 45 && proteinPerMeal < 20) {
      return (
        'Baja proteína',
        'Intenta priorizar recetas con “alta proteína” en 1–2 comidas al día.',
      );
    }

    return (
      'Irregularidad',
      'Registra tus comidas principales para mejorar el seguimiento semanal.',
    );
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }
}
