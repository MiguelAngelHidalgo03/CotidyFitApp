import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/daily_data_model.dart';
import '../services/auth_service.dart';
import '../services/daily_data_service.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../services/my_day_local_service.dart';
import '../services/health_service.dart';
import '../services/workout_session_service.dart';
import '../utils/date_utils.dart';

class DailyDataController extends ChangeNotifier {
  DailyDataController({
    DailyDataService? dailyData,
    LocalStorageService? storage,
    WorkoutSessionService? workoutService,
    MyDayLocalService? myDayService,
    AuthService? auth,
    FirestoreService? firestore,
    HealthService? health,
  })  : _dailyData = dailyData ?? DailyDataService(),
        _storage = storage ?? LocalStorageService(),
        _workoutService = workoutService ?? WorkoutSessionService(),
        _myDayService = myDayService ?? MyDayLocalService(),
      _auth = auth,
      _firestore = firestore,
      _health = health;

  final DailyDataService _dailyData;
  final LocalStorageService _storage;
  final WorkoutSessionService _workoutService;
  final MyDayLocalService _myDayService;
  AuthService? _auth;
  FirestoreService? _firestore;
  HealthService? _health;

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

    _isLoading = false;
    notifyListeners();

    // Best-effort: sync steps from Health without blocking initial render.
    _syncStepsFromHealthBestEffort();

    // Best-effort Firestore sync (only when Firebase is configured and user is signed in).
    _syncTodayToFirestore();
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
    } catch (_) {
      // Ignore transient sync failures.
    }
  }

  Future<void> setSteps(int value) async {
    if (_completedToday) return;
    final v = value < 0 ? 0 : value;
    _todayData = _todayData.copyWith(steps: v);
    await _persistAndRefreshCf();
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
  }

  Future<void> setMood(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(mood: rating.clamp(1, 5));
    await _persistAndRefreshCf();
  }

  Future<void> setStress(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(stress: rating.clamp(1, 5));
    await _persistAndRefreshCf();
  }

  Future<void> setSleep(int rating) async {
    if (_completedToday) return;
    _todayData = _todayData.copyWith(sleep: rating.clamp(1, 5));
    await _persistAndRefreshCf();
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
}
