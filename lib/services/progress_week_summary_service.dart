import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/custom_meal_model.dart';
import '../models/progress_week_summary.dart';
import '../models/recipe_model.dart';
import '../services/custom_meals_firestore_service.dart';
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
    CustomMealsFirestoreService? customMealsCloud,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _storage = storage ?? LocalStorageService(),
       _daily = daily ?? DailyDataService(),
       _workoutHistory = workoutHistory ?? WorkoutHistoryService(),
       _workouts = workouts ?? WorkoutService(),
       _myDay = myDay ?? MyDayRepositoryFactory.create(),
       _recipes = recipes ?? RecipesRepositoryFactory.create(),
       _customMealsCloud = customMealsCloud ?? CustomMealsFirestoreService(),
       _dbOverride = db,
       _authOverride = auth;

  final LocalStorageService _storage;
  final DailyDataService _daily;
  final WorkoutHistoryService _workoutHistory;
  final WorkoutService _workouts;
  final MyDayRepository _myDay;
  final RecipeRepository _recipes;
  final CustomMealsFirestoreService _customMealsCloud;
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;

  Future<ProgressWeekSummary> getCurrentWeekSummary() async {
    await _workouts.ensureLoaded();
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final weekStart = _mondayOf(today);
    final weekEnd = weekStart.add(const Duration(days: 6));

    final cfHistory = await _storage.getCfHistory();
    final completedByDate = await _workoutHistory.getCompletedWorkoutsByDate();
    final weekKeys = [
      for (var i = 0; i < 7; i++)
        DateUtilsCF.toKey(weekStart.add(Duration(days: i))),
    ];

    final uid = _uid;
    final cloudDailyStats = <String, Map<String, dynamic>>{};
    if (uid != null) {
      try {
        final docs = await Future.wait(
          weekKeys.map(
            (k) => _db
                .collection('users')
                .doc(uid)
                .collection('dailyStats')
                .doc(k)
                .get(),
          ),
        );
        for (var i = 0; i < docs.length; i++) {
          final data = docs[i].data();
          if (data != null) cloudDailyStats[weekKeys[i]] = data;
        }
      } catch (_) {
        // Keep local fallback.
      }
    }

    final cloudCustomMealsByDate = <String, List<CustomMealEntryModel>>{};
    if (uid != null) {
      try {
        final customByDay = await Future.wait(
          weekKeys.map((k) => _customMealsCloud.getForDateKey(k)),
        );
        for (var i = 0; i < weekKeys.length; i++) {
          final items = customByDay[i];
          if (items.isNotEmpty) cloudCustomMealsByDate[weekKeys[i]] = items;
        }
      } catch (_) {
        // Keep local fallback.
      }
    }

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
    final recipeById = <String, RecipeModel>{};
    final macrosByRecipeId = <String, RecipeMacros>{};
    for (final r in recipeList) {
      recipeById[r.id] = r;
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
    var todayMealsLogged = 0;
    var todayCalories = 0;
    final todayKey = DateUtilsCF.toKey(today);

    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final key = DateUtilsCF.toKey(d);

      final cloud = cloudDailyStats[key] ?? const <String, dynamic>{};
      final cloudCf = cloud['cfIndex'];
      final cf =
          ((cloudCf is int
                      ? cloudCf
                      : cloudCf is num
                      ? cloudCf.round()
                      : int.tryParse(cloudCf?.toString() ?? '')) ??
                  (cfHistory[key] ?? 0))
              .clamp(0, 100);
      if (cf > 0) {
        cfSum += cf;
        cfCount += 1;
      }

      final cloudWorkoutDone = cloud['workoutCompleted'] == true;
      if (completedByDate.containsKey(key) || cloudWorkoutDone) {
        activeDays += 1;
        final name = completedByDate[key];
        if (name != null) {
          trainedMinutes += (byName[name] ?? 20);
        } else {
          trainedMinutes += cloudWorkoutDone ? 30 : 0;
        }
      }

      final daily = await _daily.getForDateKey(key);
      final eRaw = cloud['energy'];
      final e =
          (eRaw is int
                  ? eRaw
                  : eRaw is num
                  ? eRaw.round()
                  : daily.energy)
              ?.clamp(1, 5);
      if (e != null) energyValues.add(e.clamp(1, 5));
      final waterRaw = cloud['waterLiters'];
      final cloudWater = waterRaw is num ? waterRaw.toDouble() : null;
      final waterLiters = cloudWater ?? daily.waterLiters;
      hydrationSum += (waterLiters.isNaN || waterLiters.isInfinite)
          ? 0
          : (waterLiters < 0 ? 0 : waterLiters);

      final mealTypes = entriesByDate[key] ?? const <MealType>[];
      final customMealsForDay =
          cloudCustomMealsByDate[key] ?? daily.customMeals;
      final customMealTypes = customMealsForDay.map((m) => m.mealType);
      final cloudMeals = cloud['mealsLoggedCount'];
      final cloudMealsInt = cloudMeals is int
          ? cloudMeals
          : cloudMeals is num
          ? cloudMeals.round()
          : int.tryParse(cloudMeals?.toString() ?? '');
      final uniqueMeals =
          cloudMealsInt ?? <MealType>{...mealTypes, ...customMealTypes}.length;
      final capped = uniqueMeals.clamp(0, DailyDataService.mealsTarget);
      mealsLogged += capped;
      if (key == todayKey) {
        todayMealsLogged = capped;
      }

      final recipeIds = recipeIdsByDate[key] ?? const <String>[];
      var dayCalories = 0;
      for (final id in recipeIds) {
        final macros = macrosByRecipeId[id];
        if (macros == null) continue;
        proteinTotal += (macros.proteinG < 0 ? 0 : macros.proteinG);
        carbsTotal += (macros.carbsG < 0 ? 0 : macros.carbsG);
        fatTotal += (macros.fatG < 0 ? 0 : macros.fatG);

        final kcal = recipeById[id]?.kcalPerServing;
        if (kcal != null && kcal > 0) dayCalories += kcal;
      }
      mealEntriesCount += recipeIds.length;

      for (final cm in customMealsForDay) {
        proteinTotal += (cm.meal.proteinas < 0 ? 0 : cm.meal.proteinas);
        carbsTotal += (cm.meal.carbohidratos < 0 ? 0 : cm.meal.carbohidratos);
        fatTotal += (cm.meal.grasas < 0 ? 0 : cm.meal.grasas);
        if (cm.meal.calorias > 0) dayCalories += cm.meal.calorias;
      }
      mealEntriesCount += customMealsForDay.length;

      if (key == todayKey) {
        todayCalories = dayCalories;
      }
    }

    final cfWeekAvg = cfCount == 0
        ? 0
        : (cfSum / cfCount).round().clamp(0, 100);

    final hydrationAvgLiters = hydrationSum / 7;
    final hydrationPercent = DailyDataService.waterLitersTarget <= 0
        ? 0
        : ((hydrationAvgLiters / DailyDataService.waterLitersTarget) * 100)
              .round()
              .clamp(0, 100);

    final energyAvg = energyValues.isEmpty
        ? null
        : (energyValues.reduce((a, b) => a + b) / energyValues.length);

    final nutritionPercent = mealsTarget <= 0
        ? 0
        : ((mealsLogged / mealsTarget) * 100).round().clamp(0, 100);

    final proteinPerMeal = mealEntriesCount == 0
        ? 0.0
        : (proteinTotal / mealEntriesCount);

    final macroTargets = _macroTargets(
      activeDays: activeDays,
      trainedMinutes: trainedMinutes,
    );
    final daysDiv = 7;
    final proteinDaily = (proteinTotal / daysDiv).round();
    final carbsDaily = (carbsTotal / daysDiv).round();
    final fatDaily = (fatTotal / daysDiv).round();

    final proteinCompliance = _compliancePercent(
      proteinDaily,
      macroTargets.protein,
    );
    final carbsCompliance = _compliancePercent(carbsDaily, macroTargets.carbs);
    final fatCompliance = _compliancePercent(fatDaily, macroTargets.fat);

    final nutritionGuidance = _nutritionGuidance(
      nutritionPercent: nutritionPercent,
      proteinPerMeal: proteinPerMeal,
      activeDays: activeDays,
      proteinDaily: proteinDaily,
      carbsDaily: carbsDaily,
      fatDaily: fatDaily,
      targetProtein: macroTargets.protein,
      targetCarbs: macroTargets.carbs,
      targetFat: macroTargets.fat,
    );

    final todayCaloriesTarget =
        (macroTargets.protein * 4) +
        (macroTargets.carbs * 4) +
        (macroTargets.fat * 9);
    final todayRecommendation = _todayRecommendation(
      todayMealsLogged: todayMealsLogged,
      todayCalories: todayCalories,
      targetCalories: todayCaloriesTarget,
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
      nutritionLabel: nutritionGuidance.$1,
      nutritionMessage: nutritionGuidance.$2,
      proteinTargetDailyG: macroTargets.protein,
      carbsTargetDailyG: macroTargets.carbs,
      fatTargetDailyG: macroTargets.fat,
      proteinCompliancePercent: proteinCompliance,
      carbsCompliancePercent: carbsCompliance,
      fatCompliancePercent: fatCompliance,
      nutritionAdjustments: nutritionGuidance.$3,
      todayMealsLogged: todayMealsLogged,
      todayCalories: todayCalories,
      todayCaloriesTarget: todayCaloriesTarget,
      todayRecommendation: todayRecommendation,
      todayNeedsNutritionAction: todayMealsLogged <= 0,
    );
  }

  String _todayRecommendation({
    required int todayMealsLogged,
    required int todayCalories,
    required int targetCalories,
  }) {
    if (todayMealsLogged <= 0) {
      return 'Hoy no has registrado comidas. Empieza con 1 plato base: proteína magra + carbohidrato complejo + fruta o verdura, y añádelo desde Nutrición.';
    }

    final diff = targetCalories - todayCalories;

    if (diff > 350) {
      return 'Te faltan ~${diff.clamp(0, 3000)} kcal para tu objetivo de hoy. Añade una comida completa con proteína (huevo/pollo/legumbres), carbohidrato (avena/arroz/patata) y grasa saludable.';
    }

    if (diff < -350) {
      return 'Vas por encima en ~${(-diff).clamp(0, 3000)} kcal. Para equilibrar, prioriza una cena ligera: verduras + proteína magra y evita extras altos en azúcar.';
    }

    return 'Vas bien hoy: tu consumo está cerca del objetivo. Mantén hidratación y reparte proteína en las comidas restantes.';
  }

  ({int protein, int carbs, int fat}) _macroTargets({
    required int activeDays,
    required int trainedMinutes,
  }) {
    if (activeDays >= 5 || trainedMinutes >= 180) {
      return (protein: 130, carbs: 250, fat: 75);
    }
    if (activeDays >= 3 || trainedMinutes >= 90) {
      return (protein: 115, carbs: 210, fat: 70);
    }
    return (protein: 100, carbs: 180, fat: 65);
  }

  int _compliancePercent(int actual, int target) {
    if (target <= 0) return 0;
    final ratio = (actual / target).clamp(0.0, 1.4);
    return (ratio * 100).round().clamp(0, 100);
  }

  (String, String, List<String>) _nutritionGuidance({
    required int nutritionPercent,
    required double proteinPerMeal,
    required int activeDays,
    required int proteinDaily,
    required int carbsDaily,
    required int fatDaily,
    required int targetProtein,
    required int targetCarbs,
    required int targetFat,
  }) {
    final adjustments = <String>[];
    if (proteinDaily < (targetProtein * 0.9).round()) {
      adjustments.add(
        'Sube proteína: +${(targetProtein - proteinDaily).clamp(8, 45)} g/día.',
      );
    } else if (proteinDaily > (targetProtein * 1.2).round()) {
      adjustments.add(
        'Baja proteína: -${(proteinDaily - targetProtein).clamp(8, 40)} g/día.',
      );
    }

    if (carbsDaily < (targetCarbs * 0.85).round()) {
      adjustments.add(
        'Sube carbohidratos: +${(targetCarbs - carbsDaily).clamp(15, 70)} g/día.',
      );
    } else if (carbsDaily > (targetCarbs * 1.2).round()) {
      adjustments.add(
        'Baja carbohidratos: -${(carbsDaily - targetCarbs).clamp(15, 70)} g/día.',
      );
    }

    if (fatDaily < (targetFat * 0.85).round()) {
      adjustments.add(
        'Sube grasas saludables: +${(targetFat - fatDaily).clamp(6, 30)} g/día.',
      );
    } else if (fatDaily > (targetFat * 1.2).round()) {
      adjustments.add(
        'Baja grasas: -${(fatDaily - targetFat).clamp(6, 30)} g/día.',
      );
    }

    if (nutritionPercent >= 75 && proteinPerMeal >= 20) {
      return (
        'Buena consistencia',
        activeDays >= 3
            ? 'Buena semana: comidas registradas y proteína sólida. Sigue así.'
            : 'Constancia alta. Añadir 1 entreno ligero haría el combo perfecto.',
        adjustments,
      );
    }

    if (nutritionPercent >= 45 && proteinPerMeal < 20) {
      return (
        'Baja proteína',
        'Intenta priorizar recetas con “alta proteína” en 1–2 comidas al día.',
        adjustments,
      );
    }

    return (
      'Irregularidad',
      'Registra tus comidas principales para mejorar el seguimiento semanal.',
      adjustments,
    );
  }

  DateTime _mondayOf(DateTime d) {
    final weekday = d.weekday; // Mon=1..Sun=7
    final delta = weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }
}
