import 'package:health/health.dart';

import '../models/daily_data_model.dart';
import '../services/daily_data_service.dart';
import '../services/firestore_service.dart';
import '../utils/date_utils.dart';

class HealthService {
  static const _stepsTypes = <HealthDataType>[HealthDataType.STEPS];
  static const _stepsPermissions = <HealthDataAccess>[
    HealthDataAccess.READ,
  ];

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

  Future<bool?> hasStepsPermission() async {
    await _ensureConfigured();
    try {
      return await _health.hasPermissions(
        _stepsTypes,
        permissions: _stepsPermissions,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> isHealthConnectAvailable() async {
    await _ensureConfigured();
    try {
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    await _ensureConfigured();
    try {
      await _health.installHealthConnect();
    } catch (_) {
      // Ignore install prompt failures.
    }
  }

  Future<bool> requestStepsPermission() async {
    await _ensureConfigured();
    try {
      return await _health.requestAuthorization(
        _stepsTypes,
        permissions: _stepsPermissions,
      );
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
