import 'package:flutter/foundation.dart';

import '../models/daily_entry.dart';
import '../services/local_storage_service.dart';
import '../services/workout_session_service.dart';
import '../utils/date_utils.dart';

class DailyCheckInController extends ChangeNotifier {
  DailyCheckInController({required LocalStorageService storage})
      : _storage = storage;

  final LocalStorageService _storage;

  static const actions = <String>[
    'Entrenamiento',
    'Caminar',
    'Comer bien',
    'Dormir 7h',
    'Beber suficiente agua',
    'Estiramientos',
  ];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  String _todayKey = DateUtilsCF.toKey(DateTime.now());
  String get todayKey => _todayKey;

  bool _completedToday = false;
  bool get completedToday => _completedToday;

  final Set<String> _selectedActions = {};
  Set<String> get selectedActions => Set.unmodifiable(_selectedActions);

  int? _cfOverride;
  int get displayedCfIndex {
    final override = _cfOverride;
    if (override == null) return cfIndex;
    return (override > cfIndex ? override : cfIndex).clamp(0, 100);
  }

  int get cfIndex {
    final value = (_selectedActions.length / actions.length) * 100;
    return value.round().clamp(0, 100);
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    _todayKey = DateUtilsCF.toKey(now);

    _streakCount = await _storage.getStreakCount();
    final lastKey = await _storage.getLastCompletedDateKey();
    final lastDate = DateUtilsCF.fromKey(lastKey);

    _completedToday = false;

    // Reset streak if chain was broken (last completion older than yesterday).
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

    // Load today's selection if it matches today.
    final storedEntry = await _storage.getTodayEntry();
    _selectedActions
      ..clear()
      ..addAll(
        (storedEntry != null && storedEntry.dateKey == _todayKey)
            ? storedEntry.completedActions
            : const <String>[],
      );

    final history = await _storage.getCfHistory();
    _cfOverride = history[_todayKey];

    _isLoading = false;
    notifyListeners();
  }

  void toggleAction(String action) {
    if (_completedToday) return;
    if (!actions.contains(action)) return;

    _cfOverride = null;

    if (_selectedActions.contains(action)) {
      _selectedActions.remove(action);
    } else {
      _selectedActions.add(action);
    }
    notifyListeners();
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
      // already completed today; keep streak
      newStreak = _streakCount;
    } else if (DateUtilsCF.isYesterdayOf(lastDate, now)) {
      newStreak = _streakCount + 1;
    } else {
      newStreak = 1;
    }

    final entry = DailyEntry(
      dateKey: todayKey,
      completedActions: _selectedActions.toList()..sort(),
    );

    await _storage.setTodayEntry(entry);

    var cfToSave = entry.cfIndex;
    final workoutDone = await WorkoutSessionService().isWorkoutCompletedForDate(todayKey);
    if (workoutDone) {
      cfToSave = (cfToSave + WorkoutSessionService.cfBonus).clamp(0, 100);
    }

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
}
