import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';

class WorkoutPlanService {
  static const _kPlansByWeekKey = 'cf_workout_plans_by_week_json';
  static const _kCloudMigrationPrefix = 'cf_workout_plans_cloud_migrated_v1_';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  WorkoutPlanService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  CollectionReference<Map<String, dynamic>> _plansColForUid(String uid) {
    return _db.collection('users').doc(uid).collection('workoutPlans');
  }

  Future<WeekPlan?> getPlanForWeekKey(String weekStartKey) async {
    final uid = _uid;
    if (uid != null) {
      await _migrateLocalPlansToCloudIfNeeded(uid);
      final snap = await _plansColForUid(uid).doc(weekStartKey).get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
          final map = <String, Object?>{};
          for (final e in data.entries) {
            map[e.key] = e.value;
          }
          final parsed = WeekPlan.fromJson(map);
          if (parsed != null) {
            await _cachePlanLocally(parsed);
            return parsed;
          }
        }
      }
    }

    final map = await _getAllPlans();
    final raw = map[weekStartKey];
    if (raw == null || raw.trim().isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final obj = <String, Object?>{};
    for (final e in decoded.entries) {
      if (e.key is String) obj[e.key as String] = e.value;
    }

    return WeekPlan.fromJson(obj);
  }

  Future<void> upsertPlan(WeekPlan plan) async {
    final uid = _uid;
    if (uid != null) {
      await _plansColForUid(uid).doc(plan.weekKey).set({
        ...plan.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _cachePlanLocally(plan);
  }

  Future<void> _cachePlanLocally(WeekPlan plan) async {
    final map = await _getAllPlans();
    map[plan.weekKey] = jsonEncode(plan.toJson());
    final p = await _prefs();
    await p.setString(_kPlansByWeekKey, jsonEncode(map));
  }

  Future<void> _migrateLocalPlansToCloudIfNeeded(String uid) async {
    final p = await _prefs();
    final markerKey = '$_kCloudMigrationPrefix$uid';
    if (p.getBool(markerKey) == true) return;

    final local = await _getAllPlans();
    if (local.isNotEmpty) {
      final batch = _db.batch();
      final col = _plansColForUid(uid);

      for (final entry in local.entries) {
        final decoded = jsonDecode(entry.value);
        if (decoded is! Map) continue;
        final obj = <String, Object?>{};
        for (final e in decoded.entries) {
          if (e.key is String) obj[e.key as String] = e.value;
        }
        final plan = WeekPlan.fromJson(obj);
        if (plan == null) continue;

        batch.set(col.doc(plan.weekKey), {
          ...plan.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    }

    await p.setBool(markerKey, true);
  }

  Future<Map<String, String>> _getAllPlans() async {
    final p = await _prefs();
    final raw = p.getString(_kPlansByWeekKey);
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
