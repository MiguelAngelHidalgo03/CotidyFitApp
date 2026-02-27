import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_data_model.dart';
import '../services/workout_history_service.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/daily_data_service.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../services/my_day_repository.dart';
import '../services/my_day_repository_factory.dart';
import '../services/health_service.dart';
import '../services/workout_session_service.dart';
import '../utils/date_utils.dart';

class DailyDataController extends ChangeNotifier {
  static const _kMoodPromptShownDateKey = 'cf_mood_prompt_shown_date_v1';
  static const _kDailyMissionBonusPrefix = 'cf_daily_mission_bonus_v1_';

  DailyDataController({
    DailyDataService? dailyData,
    LocalStorageService? storage,
    WorkoutSessionService? workoutService,
    MyDayRepository? myDayService,
    AuthService? auth,
    FirestoreService? firestore,
    HealthService? health,
    AchievementsService? achievements,
  })  : _dailyData = dailyData ?? DailyDataService(),
        _storage = storage ?? LocalStorageService(),
        _workoutService = workoutService ?? WorkoutSessionService(),
        _myDayService = myDayService ?? MyDayRepositoryFactory.create(),
      _workoutHistory = WorkoutHistoryService(),
      _auth = auth,
      _firestore = firestore,
      _health = health,
      _achievements = achievements ?? AchievementsService();

  final DailyDataService _dailyData;
  final LocalStorageService _storage;
  final WorkoutSessionService _workoutService;
  final MyDayRepository _myDayService;
  final WorkoutHistoryService _workoutHistory;
  AuthService? _auth;
  FirestoreService? _firestore;
  HealthService? _health;
  final AchievementsService _achievements;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  String _todayKey = DateUtilsCF.toKey(DateTime.now());
  String get todayKey => _todayKey;

  bool _completedToday = false;
  bool get completedToday => _completedToday;

  DailyDataModel _todayData = DailyDataModel.empty(DateUtilsCF.toKey(DateTime.now()));
  DailyDataModel get todayData => _todayData;

  bool _workoutCompleted = false;
  bool get workoutCompleted => _workoutCompleted;

  int _mealsLoggedCount = 0;
  int get mealsLoggedCount => _mealsLoggedCount;

  int? _cfOverride;
  int _weekTrainingMinutes = 0;
  int _weekWaterDays = 0;
  int _weekMeditationDays = 0;

  int get weekTrainingMinutes => _weekTrainingMinutes;
  int get weekWaterDays => _weekWaterDays;
  int get weekMeditationDays => _weekMeditationDays;

  bool get dailyMissionCompleted =>
      _workoutCompleted &&
      _todayData.waterLiters >= 2.0 &&
      _todayData.meditationMinutes >= 5;

  double get dailyMissionProgress {
    var done = 0;
    if (_workoutCompleted) done++;
    if (_todayData.waterLiters >= 2.0) done++;
    if (_todayData.meditationMinutes >= 5) done++;
    return done / 3;
  }

  double get weeklyMissionProgress {
    var done = 0;
    if (_weekTrainingMinutes >= 40) done++;
    if (_weekWaterDays >= 7) done++;
    if (_weekMeditationDays >= 5) done++;
    return done / 3;
  }

  int get computedCfIndex {
    return _dailyData.computeWeightedCf(
      data: _todayData,
      workoutCompleted: _workoutCompleted,
      mealsLoggedCount: _mealsLoggedCount,
    );
  }

  int get displayedCfIndex {
    final base = computedCfIndex;
    final override = _cfOverride;
    if (override == null) return base;
    return (override > base ? override : base).clamp(0, 100);
  }

  int get completedCount {
    return _dailyData.completionCount(
      data: _todayData,
      workoutCompleted: _workoutCompleted,
      mealsLoggedCount: _mealsLoggedCount,
    );
  }

  int get totalCount => _dailyData.totalTrackablesCount();

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      _todayKey = DateUtilsCF.toKey(now);

      _streakCount = await _storage.getStreakCount();
      final lastKey = await _storage.getLastCompletedDateKey();
      final lastDate = DateUtilsCF.fromKey(lastKey);

      _completedToday = false;

      if (lastDate != null) {
        final today = DateUtilsCF.dateOnly(now);
        final last = DateUtilsCF.dateOnly(lastDate);
        final isToday = DateUtilsCF.isSameDay(last, today);
        final isYesterday = DateUtilsCF.isYesterdayOf(last, today);

        if (!isToday && !isYesterday && _streakCount != 0) {
          _streakCount = 0;
          await _storage.setStreakCount(0);
        }

        if (isToday) {
          _completedToday = true;
        }
      }

      _todayData = await _dailyData.getForDateKey(_todayKey);
      if (_todayData.dateKey != _todayKey) {
        _todayData = DailyDataModel.empty(_todayKey);
      }

      _workoutCompleted = await _workoutService.isWorkoutCompletedForDate(_todayKey);

      final myDayEntries = await _myDayService.getForDate(DateTime.now());
      final mealTypes = <Object?>{};
      for (final e in myDayEntries) {
        mealTypes.add(e.mealType);
      }
      _mealsLoggedCount = mealTypes.length.clamp(0, 10);

      final history = await _storage.getCfHistory();
      _cfOverride = history[_todayKey];

      await _reloadWeeklyMissions();

      // Best-effort: sync steps from Health without blocking initial render.
      _syncStepsFromHealthBestEffort();

      // Best-effort Firestore sync (only when Firebase is configured and user is signed in).
      _syncTodayToFirestore();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncStepsFromHealthBestEffort() async {
    if (_isRunningWidgetTest) return;

    try {
      final health = _health ??= HealthService();
      final synced = await health
          .syncTodaySteps()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (synced == null) return;
      if (synced.dateKey != _todayKey) return;

      _todayData = synced;
      notifyListeners();

      // If the user is signed in, push the updated steps to Firestore.
      _syncTodayToFirestore();
    } catch (_) {
      // Ignore (Health Connect/HealthKit may be unavailable).
    }
  }

  bool get _isRunningWidgetTest {
    // We cannot import `flutter_test` from production code, so detect it by
    // checking the binding runtimeType. This avoids relying on dart-defines.
    try {
      final type = WidgetsBinding.instance.runtimeType.toString();
      return type.contains('TestWidgetsFlutterBinding') ||
          type.contains('AutomatedTestWidgetsFlutterBinding') ||
          type.contains('LiveTestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncTodayToFirestore() async {
    if (Firebase.apps.isEmpty) return;
    final auth = _auth ??= AuthService();
    final user = auth.currentUser;
    if (user == null) return;

    final fs = _firestore ??= FirestoreService();

    try {
      await fs.saveDailyDataFromModel(
        uid: user.uid,
        data: _todayData,
        cfScore: displayedCfIndex,
      );

      await fs.saveDailyTracking(
        uid: user.uid,
        dateKey: _todayKey,
        workoutCompleted: _workoutCompleted,
        steps: _todayData.steps,
        waterLiters: _todayData.waterLiters,
        mealsLoggedCount: _mealsLoggedCount,
        meditationMinutes: _todayData.meditationMinutes,
        cfIndex: displayedCfIndex,
      );
    } catch (_) {
      // Ignore transient sync failures.
    }
  }

  Future<void> setSteps(int value) async {
    if (_completedToday) return;
    final v = value < 0 ? 0 : value;
    _todayData = _todayData.copyWith(steps: v);
    await _persistAndRefreshCf();
    await _reloadWeeklyMissions();
  }

  Future<void> setActiveMinutes(int value) async {
    if (_completedToday) return;
    final v = value < 0 ? 0 : value;
    _todayData = _todayData.copyWith(activeMinutes: v);
    await _persistAndRefreshCf();
  }

  Future<void> setWaterCups(int value) async {
    // Deprecated entry point from earlier Home UI.
    await setWaterLiters((value < 0 ? 0 : value) * 0.25);
  }

  Future<void> setWaterLiters(double value) async {
    if (_completedToday) return;
    final v = value.isNaN || value.isInfinite ? 0.0 : value;
    _todayData = _todayData.copyWith(waterLiters: v < 0 ? 0 : v);
    await _persistAndRefreshCf();
    await _reloadWeeklyMissions();
    await _checkAchievementsBestEffort();
  }

  Future<void> addWater250ml() async {
    if (_completedToday) return;
    final next = (_todayData.waterLiters + 0.25);
    // Keep a sensible upper bound to avoid silly values.
    await setWaterLiters(next > 20 ? 20 : next);
  }

  Future<void> toggleStretchesDone() async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(stretchesDone: !_todayData.stretchesDone);
    await _persistAndRefreshCf();
  }

  Future<void> setEnergy(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(energy: rating.clamp(1, 5));
    await _persistAndRefreshCf();
    await _syncDailyMoodToFirestore();
  }

  Future<void> setMood(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(mood: rating.clamp(1, 5));
    await _persistAndRefreshCf();
    await _syncDailyMoodToFirestore();
  }

  Future<void> setStress(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(stress: rating.clamp(1, 5));
    await _persistAndRefreshCf();
    await _syncDailyMoodToFirestore();
  }

  Future<void> setSleep(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(sleep: rating.clamp(1, 5));
    await _persistAndRefreshCf();
    await _syncDailyMoodToFirestore();
  }

  Future<void> setMeditationMinutes(int value) async {
    if (_completedToday) return;
    final v = value < 0 ? 0 : value;
    _todayData = _todayData.copyWith(meditationMinutes: v);
    await _persistAndRefreshCf();
    await _reloadWeeklyMissions();
    await _syncMeditationToFirestore();
    await _checkAchievementsBestEffort();
  }

  Future<void> addMeditationMinutes({int minutes = 5}) async {
    final safe = minutes <= 0 ? 5 : minutes;
    await setMeditationMinutes(_todayData.meditationMinutes + safe);
  }

  Future<void> confirmToday() async {
    if (_completedToday) return;

    final now = DateTime.now();
    final todayKey = DateUtilsCF.toKey(now);
    final lastKey = await _storage.getLastCompletedDateKey();
    final lastDate = DateUtilsCF.fromKey(lastKey);

    var newStreak = _streakCount;

    if (lastDate == null) {
      newStreak = 1;
    } else if (DateUtilsCF.isSameDay(lastDate, now)) {
      newStreak = _streakCount;
    } else if (DateUtilsCF.isYesterdayOf(lastDate, now)) {
      newStreak = _streakCount + 1;
    } else {
      newStreak = 1;
    }

    final cfToSave = computedCfIndex;
    final existing = (await _storage.getCfHistory())[todayKey] ?? 0;
    final finalCf = (existing > cfToSave ? existing : cfToSave).clamp(0, 100);

    await _storage.upsertCfForDate(dateKey: todayKey, cf: finalCf);
    await _storage.setLastCompletedDateKey(todayKey);
    await _storage.setStreakCount(newStreak);

    _todayKey = todayKey;
    _streakCount = newStreak;
    _completedToday = true;
    _cfOverride = finalCf;
    notifyListeners();
    await _reloadWeeklyMissions();
    await _checkAchievementsBestEffort();
  }

  Future<bool> shouldPromptMoodToday() async {
    final p = await SharedPreferences.getInstance();
    final shownKey = p.getString(_kMoodPromptShownDateKey);
    if (shownKey == _todayKey) return false;

    final hasMood = _todayData.energy != null &&
        _todayData.mood != null &&
        _todayData.stress != null &&
        _todayData.sleep != null;

    return !hasMood;
  }

  Future<void> markMoodPromptShownToday() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMoodPromptShownDateKey, _todayKey);
  }

  Future<bool> applyDailyMissionRewardIfEligible() async {
    if (!dailyMissionCompleted) return false;

    final p = await SharedPreferences.getInstance();
    final key = '$_kDailyMissionBonusPrefix$_todayKey';
    if (p.getBool(key) == true) return false;

    final history = await _storage.getCfHistory();
    final current = (history[_todayKey] ?? displayedCfIndex).clamp(0, 100);
    final boosted = (current + 5).clamp(0, 100);
    await _storage.upsertCfForDate(dateKey: _todayKey, cf: boosted);
    _cfOverride = boosted;
    await p.setBool(key, true);

    notifyListeners();
    _syncTodayToFirestore();
    return true;
  }

  Future<void> _persistAndRefreshCf() async {
    await _dailyData.upsert(_todayData);

    final cf = computedCfIndex;
    final history = await _storage.getCfHistory();
    final existing = history[_todayKey] ?? 0;
    final finalCf = (existing > cf ? existing : cf).clamp(0, 100);

    await _storage.upsertCfForDate(dateKey: _todayKey, cf: finalCf);
    _cfOverride = finalCf;

    notifyListeners();

    _syncTodayToFirestore();
  }

  Future<void> _syncMeditationToFirestore() async {
    if (Firebase.apps.isEmpty) return;
    final auth = _auth ??= AuthService();
    final user = auth.currentUser;
    if (user == null) return;

    final fs = _firestore ??= FirestoreService();
    try {
      await fs.saveMeditationMinutes(
        uid: user.uid,
        dateKey: _todayKey,
        meditationMinutes: _todayData.meditationMinutes,
      );
    } catch (_) {}
  }

  Future<void> _syncDailyMoodToFirestore() async {
    if (Firebase.apps.isEmpty) return;
    final auth = _auth ??= AuthService();
    final user = auth.currentUser;
    if (user == null) return;

    String mapEnergy(int? v) {
      if (v == null) return 'media';
      if (v <= 2) return 'baja';
      if (v >= 4) return 'alta';
      return 'media';
    }

    String mapLevel(int? v) {
      if (v == null) return 'medio';
      if (v <= 2) return 'bajo';
      if (v >= 4) return 'alto';
      return 'medio';
    }

    String mapSleep(int? v) {
      if (v == null) return 'normal';
      if (v <= 2) return 'malo';
      if (v >= 4) return 'bueno';
      return 'normal';
    }

    final fs = _firestore ??= FirestoreService();
    try {
      await fs.saveDailyMood(
        uid: user.uid,
        dateKey: _todayKey,
        energia: mapEnergy(_todayData.energy),
        animo: mapLevel(_todayData.mood),
        estres: mapLevel(_todayData.stress),
        sueno: mapSleep(_todayData.sleep),
      );
    } catch (_) {}
  }

  Future<void> _checkAchievementsBestEffort() async {
    if (Firebase.apps.isEmpty) return;
    final auth = _auth ??= AuthService();
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await _achievements.checkAchievements(user.uid);
    } catch (_) {}
  }

  Future<void> _reloadWeeklyMissions() async {
    final weekStart = _mondayOf(DateUtilsCF.dateOnly(DateTime.now()));

    final completed = await _workoutHistory.getCompletedWorkoutsByDate();
    var trainedDays = 0;
    for (var i = 0; i < 7; i++) {
      final key = DateUtilsCF.toKey(weekStart.add(Duration(days: i)));
      if (completed.containsKey(key)) trainedDays++;
    }
    _weekTrainingMinutes = trainedDays * 20;

    var waterDays = 0;
    var meditationDays = 0;
    for (var i = 0; i < 7; i++) {
      final key = DateUtilsCF.toKey(weekStart.add(Duration(days: i)));
      final day = await _dailyData.getForDateKey(key);
      if (day.waterLiters >= 2.0) waterDays++;
      if (day.meditationMinutes >= 5) meditationDays++;
    }

    _weekWaterDays = waterDays;
    _weekMeditationDays = meditationDays;
    notifyListeners();
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateUtilsCF.dateOnly(d);
    final delta = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: delta));
  }
}
