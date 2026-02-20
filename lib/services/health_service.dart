import 'package:health/health.dart';

import '../models/daily_data_model.dart';
import '../services/daily_data_service.dart';
import '../services/firestore_service.dart';
import '../utils/date_utils.dart';

class HealthService {
  final Health _health;
  final DailyDataService _daily;
  final FirestoreService? _firestore;
  Future<void>? _configureFuture;

  HealthService({
    Health? health,
    DailyDataService? daily,
    FirestoreService? firestore,
  })  : _health = health ?? Health(),
        _daily = daily ?? DailyDataService(),
        _firestore = firestore;

  Future<void> _ensureConfigured() => _configureFuture ??= _health.configure();

  Future<bool> requestStepsPermission() async {
    await _ensureConfigured();
    const types = <HealthDataType>[HealthDataType.STEPS];
    const permissions = <HealthDataAccess>[HealthDataAccess.READ];
    try {
      return await _health.requestAuthorization(types, permissions: permissions);
    } catch (_) {
      return false;
    }
  }

  Future<int?> readTodaySteps() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (_) {
      return null;
    }
  }

  /// Reads today steps and saves them into DailyDataModel for today.
  ///
  /// If [uid] is provided and a [FirestoreService] was injected, the dailyStats
  /// document is also upserted.
  Future<DailyDataModel?> syncTodaySteps({
    String? uid,
  }) async {
    final ok = await requestStepsPermission();
    if (!ok) return null;

    final steps = await readTodaySteps();
    if (steps == null) return null;

    final key = DateUtilsCF.toKey(DateTime.now());
    final current = await _daily.getForDateKey(key);
    final updated = current.copyWith(steps: steps);
    await _daily.upsert(updated);

    final fs = _firestore;
    if (uid != null && fs != null) {
      await fs.saveDailyStats(uid: uid, stats: updated);
    }

    return updated;
  }
}
