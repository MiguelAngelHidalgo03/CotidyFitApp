import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutHistoryService {
  // Must match WorkoutSessionService internal key.
  static const _kCompletedWorkoutsByDateKey = 'cf_completed_workouts_by_date_json';
  static const _kCompletedWorkoutIdsByDateKey = 'cf_completed_workout_ids_by_date_json';
  static const _kCloudMigrationPrefix =
      'cf_completed_workouts_cloud_migrated_v1_';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  WorkoutHistoryService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  CollectionReference<Map<String, dynamic>> _historyColForUid(String uid) {
    return _db.collection('users').doc(uid).collection('workoutCompletions');
  }

  Future<Map<String, String>> getCompletedWorkoutsByDate() async {
    final uid = _uid;
    if (uid != null) {
      await _migrateLocalHistoryToCloudIfNeeded(uid);

      final qs = await _historyColForUid(uid).get();
      final out = <String, String>{};
      for (final doc in qs.docs) {
        final data = doc.data();
        final workoutName = data['workoutName'];
        if (workoutName is! String || workoutName.trim().isEmpty) continue;

        final dateKeyRaw = data['dateKey'];
        final dateKey = dateKeyRaw is String && dateKeyRaw.trim().isNotEmpty
            ? dateKeyRaw
            : doc.id;

        out[dateKey] = workoutName.trim();
      }

      await _cacheMapLocally(out);
      return out;
    }

    final p = await _prefs();
    final raw = p.getString(_kCompletedWorkoutsByDateKey);
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

  Future<Map<String, String>> getCompletedWorkoutIdsByDate() async {
    final uid = _uid;
    if (uid != null) {
      await _migrateLocalHistoryToCloudIfNeeded(uid);

      final qs = await _historyColForUid(uid).get();
      final out = <String, String>{};
      for (final doc in qs.docs) {
        final data = doc.data();

        final workoutId = (data['workoutId'] as String?)?.trim() ?? '';
        if (workoutId.isEmpty) continue;

        final dateKeyRaw = data['dateKey'];
        final dateKey = dateKeyRaw is String && dateKeyRaw.trim().isNotEmpty
            ? dateKeyRaw
            : doc.id;

        out[dateKey] = workoutId;
      }

      await _cacheIdsMapLocally(out);
      return out;
    }

    return _readLocalIdsMap();
  }

  Future<void> upsertCompletedWorkoutForDate({
    required String dateKey,
    required String workoutName,
    Map<String, Object?>? completionData,
  }) async {
    final key = dateKey.trim();
    final name = workoutName.trim();
    if (key.isEmpty || name.isEmpty) return;

    final uid = _uid;
    if (uid != null) {
      await _historyColForUid(uid).doc(key).set(
        {
          'dateKey': key,
          'workoutName': name,
          'updatedAt': FieldValue.serverTimestamp(),
          if (completionData != null) ...completionData,
        },
        SetOptions(merge: true),
      );
    }

    final map = await _readLocalMap();
    map[key] = name;
    await _cacheMapLocally(map);

    final workoutId = completionData?['workoutId'];
    if (workoutId is String && workoutId.trim().isNotEmpty) {
      final ids = await _readLocalIdsMap();
      ids[key] = workoutId.trim();
      await _cacheIdsMapLocally(ids);
    }
  }

  Future<String?> getCompletedWorkoutName(String dateKey) async {
    final key = dateKey.trim();
    if (key.isEmpty) return null;

    final uid = _uid;
    if (uid != null) {
      await _migrateLocalHistoryToCloudIfNeeded(uid);
      final snap = await _historyColForUid(uid).doc(key).get();
      if (snap.exists) {
        final data = snap.data();
        final name = data?['workoutName'];
        if (name is String && name.trim().isNotEmpty) {
          final map = await _readLocalMap();
          map[key] = name.trim();
          await _cacheMapLocally(map);

          final workoutId = (data?['workoutId'] as String?)?.trim();
          if (workoutId != null && workoutId.isNotEmpty) {
            final ids = await _readLocalIdsMap();
            ids[key] = workoutId;
            await _cacheIdsMapLocally(ids);
          }

          return name.trim();
        }
      }
    }

    final map = await _readLocalMap();
    return map[key];
  }

  Future<Map<String, String>> _readLocalMap() async {
    final p = await _prefs();
    final raw = p.getString(_kCompletedWorkoutsByDateKey);
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

  Future<void> _cacheMapLocally(Map<String, String> map) async {
    final p = await _prefs();
    await p.setString(_kCompletedWorkoutsByDateKey, jsonEncode(map));
  }

  Future<Map<String, String>> _readLocalIdsMap() async {
    final p = await _prefs();
    final raw = p.getString(_kCompletedWorkoutIdsByDateKey);
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

  Future<void> _cacheIdsMapLocally(Map<String, String> map) async {
    final p = await _prefs();
    await p.setString(_kCompletedWorkoutIdsByDateKey, jsonEncode(map));
  }

  Future<void> _migrateLocalHistoryToCloudIfNeeded(String uid) async {
    final p = await _prefs();
    final markerKey = '$_kCloudMigrationPrefix$uid';
    if (p.getBool(markerKey) == true) return;

    final local = await _readLocalMap();
    if (local.isNotEmpty) {
      final batch = _db.batch();
      final col = _historyColForUid(uid);

      for (final e in local.entries) {
        final key = e.key.trim();
        final name = e.value.trim();
        if (key.isEmpty || name.isEmpty) continue;

        batch.set(col.doc(key), {
          'dateKey': key,
          'workoutName': name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    }

    await p.setBool(markerKey, true);
  }
}
