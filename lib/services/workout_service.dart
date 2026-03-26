import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout.dart';
import 'training_firestore_service.dart';

class WorkoutService {
  WorkoutService({TrainingFirestoreService? firestore})
    : _firestore = firestore ?? TrainingFirestoreService();

  final TrainingFirestoreService _firestore;
  List<Workout> _cache = const [];
  bool _refreshing = false;
  bool _lastRefreshSucceeded = true;

  static const _kCacheVersion = 1;
  static const _kCacheTtl = Duration(hours: 12);

  String _cacheKey(String? uid) => 'cf_workouts_cache_v${_kCacheVersion}_${uid ?? 'no_uid'}';
  String _cacheUpdatedAtKey(String? uid) =>
      'cf_workouts_cache_updated_ms_v${_kCacheVersion}_${uid ?? 'no_uid'}';

  bool get lastRefreshSucceeded => _lastRefreshSucceeded;

  Future<void> ensureLoaded() async {
    if (_cache.isNotEmpty) return;

    final loaded = await _tryRestoreFromDisk();
    if (loaded) {
      unawaited(_refreshIfStale());
      return;
    }

    await refreshFromFirestore();
  }

  Future<List<Workout>> refreshFromFirestore() async {
    if (_refreshing) return _cache;
    _refreshing = true;
    try {
      final routines = await _firestore.getRoutines();
      final generated = await _firestore.getUserGeneratedRoutines();
      final next = [...routines, ...generated];
      _cache = next;
      _lastRefreshSucceeded = true;
      await _persistToDisk(next);
    } catch (_) {
      _lastRefreshSucceeded = false;
      if (_cache.isEmpty) _cache = const [];
    } finally {
      _refreshing = false;
    }
    return _cache;
  }

  Future<bool> _tryRestoreFromDisk() async {
    try {
      final uid = _firestore.currentUid;
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_cacheKey(uid));
      if (raw == null || raw.trim().isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return false;

      final out = <Workout>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final workout = Workout.fromJson(map);
        if (workout != null) out.add(workout);
      }

      if (out.isEmpty) return false;
      _cache = out;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistToDisk(List<Workout> workouts) async {
    try {
      final uid = _firestore.currentUid;
      final p = await SharedPreferences.getInstance();
      final payload = workouts.map((w) => w.toJson()).toList();
      await p.setString(_cacheKey(uid), jsonEncode(payload));
      await p.setInt(
        _cacheUpdatedAtKey(uid),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _refreshIfStale() async {
    try {
      final uid = _firestore.currentUid;
      final p = await SharedPreferences.getInstance();
      final updatedAtMs = p.getInt(_cacheUpdatedAtKey(uid)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - updatedAtMs;
      if (age >= 0 && age < _kCacheTtl.inMilliseconds) return;
      await refreshFromFirestore();
    } catch (_) {
      // best-effort
    }
  }

  List<Workout> getAllWorkouts() => _cache;

  Workout? getWorkoutById(String id) {
    try {
      return _cache.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> getCategories() {
    final set = <String>{};
    for (final w in _cache) {
      set.add(w.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Workout> getWorkoutsByCategory(String category) {
    final list = _cache.where((w) => w.category == category).toList();
    list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return list;
  }

  List<Workout> getFilteredWorkouts(WorkoutFilters filters) {
    return _cache.where((w) => w.matchesFilters(filters)).toList();
  }
}
