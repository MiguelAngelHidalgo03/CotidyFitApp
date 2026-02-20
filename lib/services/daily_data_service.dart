import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_meal_model.dart';
import '../models/daily_data_model.dart';
import '../models/recipe_model.dart';

class DailyDataService {
  static const _kDailyDataByDateKey = 'cf_daily_data_by_date_v1';
  static const _kFeelingsOnboardingShown = 'cf_feelings_onboarding_shown_v1';

  static const int stepsTarget = 8000;
  static const int activeMinutesTarget = 30;
  static const double waterLitersTarget = 2.5;
  static const int mealsTarget = 3;

  static const double _wTraining = 0.22;
  static const double _wMovement = 0.22;
  static const double _wHydration = 0.14;
  static const double _wNutrition = 0.14;
  static const double _wRest = 0.14;
  static const double _wEmotional = 0.14;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<DailyDataModel> getForDateKey(String dateKey) async {
    final all = await _getAllRaw();
    final raw = all[dateKey];
    if (raw == null || raw.trim().isEmpty) return DailyDataModel.empty(dateKey);

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return DailyDataModel.empty(dateKey);

    final map = <String, Object?>{};
    for (final e in decoded.entries) {
      if (e.key is String) map[e.key as String] = e.value;
    }

    final model = DailyDataModel.fromJson(map);
    return model.dateKey.trim().isEmpty ? DailyDataModel.empty(dateKey) : model;
  }

  Future<void> upsert(DailyDataModel model) async {
    final all = await _getAllRaw();
    all[model.dateKey] = jsonEncode(model.toJson());
    final p = await _prefs();
    await p.setString(_kDailyDataByDateKey, jsonEncode(all));
  }

  Future<void> addCustomMeal({
    required String dateKey,
    required MealType mealType,
    required CustomMealModel meal,
  }) async {
    final current = await getForDateKey(dateKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = CustomMealEntryModel(
      id: 'cm_${now}_${meal.id}',
      mealType: mealType,
      meal: meal,
      addedAtMs: now,
    );

    final updated = [entry, ...current.customMeals];
    await upsert(current.copyWith(customMeals: updated));
  }

  Future<void> removeCustomMeal({
    required String dateKey,
    required String entryId,
  }) async {
    final current = await getForDateKey(dateKey);
    final updated = current.customMeals.where((e) => e.id != entryId).toList();
    await upsert(current.copyWith(customMeals: updated));
  }

  int computeWeightedCf({
    required DailyDataModel data,
    required bool workoutCompleted,
    required int mealsLoggedCount,
  }) {
    final training = workoutCompleted ? 100 : 0;

    final stepsScore = _scoreProgress(data.steps, stepsTarget);
    final activeScore = _scoreProgress(data.activeMinutes, activeMinutesTarget);
    final movement = ((stepsScore + activeScore) / 2).round().clamp(0, 100);

    final hydration = _hydrationScoreFromLiters(data.waterLiters);

    final mealsScore = _scoreProgress(mealsLoggedCount, mealsTarget);
    final stretchesScore = data.stretchesDone ? 100 : 0;
    final nutrition = ((mealsScore * 0.75) + (stretchesScore * 0.25)).round().clamp(0, 100);

    final sleepScore = _ratingToScore(data.sleep);
    final rest = sleepScore;

    final energyScore = _ratingToScore(data.energy);
    final moodScore = _ratingToScore(data.mood);
    final stressScore = _ratingToInverseScore(data.stress);
    final emotional = ((energyScore + moodScore + stressScore) / 3).round().clamp(0, 100);

    final cf = (training * _wTraining) +
        (movement * _wMovement) +
        (hydration * _wHydration) +
        (nutrition * _wNutrition) +
        (rest * _wRest) +
        (emotional * _wEmotional);

    return cf.round().clamp(0, 100);
  }

  bool isFeelingsOnboardingShownSync(SharedPreferences p) {
    return p.getBool(_kFeelingsOnboardingShown) ?? false;
  }

  Future<bool> isFeelingsOnboardingShown() async {
    final p = await _prefs();
    return isFeelingsOnboardingShownSync(p);
  }

  Future<void> setFeelingsOnboardingShown(bool value) async {
    final p = await _prefs();
    await p.setBool(_kFeelingsOnboardingShown, value);
  }

  int completionCount({
    required DailyDataModel data,
    required bool workoutCompleted,
    required int mealsLoggedCount,
  }) {
    var count = 0;
    if (workoutCompleted) count++;
    if (data.steps >= stepsTarget) count++;
    if (data.activeMinutes >= activeMinutesTarget) count++;
    if (data.waterLiters >= waterLitersTarget) count++;
    if (mealsLoggedCount >= mealsTarget) count++;
    if (data.stretchesDone) count++;
    return count;
  }

  int totalTrackablesCount() => 6;

  int _scoreProgress(int value, int target) {
    if (target <= 0) return 0;
    final v = value < 0 ? 0 : value;
    final score = ((v / target) * 100).round();
    return score.clamp(0, 100);
  }

  int _hydrationScoreFromLiters(double liters) {
    final l = liters < 0 ? 0 : liters;

    // Bucket points (0..15) then normalize to 0..100 for the weighted CF formula.
    final points = l < 0.5
        ? 0
        : (l < 1.5
            ? 5
            : (l < 2.5 ? 10 : 15));

    return ((points / 15) * 100).round().clamp(0, 100);
  }

  int _ratingToScore(int? rating) {
    if (rating == null) return 0;
    return (((rating.clamp(1, 5) - 1) / 4) * 100).round().clamp(0, 100);
  }

  int _ratingToInverseScore(int? rating) {
    if (rating == null) return 0;
    final r = rating.clamp(1, 5);
    return (((5 - r) / 4) * 100).round().clamp(0, 100);
  }

  Future<Map<String, String>> _getAllRaw() async {
    final p = await _prefs();
    final raw = p.getString(_kDailyDataByDateKey);
    if (raw == null || raw.trim().isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final out = <String, String>{};
    for (final e in decoded.entries) {
      final k = e.key;
      final v = e.value;
      if (k is String && v is String) out[k] = v;
    }
    return out;
  }
}
