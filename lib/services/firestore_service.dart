import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_data_model.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> dailyDataCol(String uid) {
    return userDoc(uid).collection('daily_data');
  }

  CollectionReference<Map<String, dynamic>> dailyStatsCol(String uid) {
    return userDoc(uid).collection('dailyStats');
  }

  CollectionReference<Map<String, dynamic>> dailyMoodCol(String uid) {
    return userDoc(uid).collection('dailyMood');
  }

  Future<void> upsertUser({
    required String uid,
    required UserProfile profile,
    String? email,
  }) async {
    await userDoc(uid).set(
      {
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingCompleted': profile.onboardingCompleted,
        'isPremium': profile.isPremium,
        'profileData': profile.toJson(),
        'healthConditions': profile.healthConditions,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> createUserProfile({
    required String uid,
    required UserProfile profile,
  }) async {
    await upsertUser(uid: uid, profile: profile);
  }

  Future<void> updateProfile({
    required String uid,
    required UserProfile profile,
  }) async {
    await upsertUser(uid: uid, profile: profile);
  }

  Future<void> saveDailyData({
    required String uid,
    required String dateKey,
    required int steps,
    required double water,
    required int minutesActive,
    required int cfScore,
  }) async {
    await dailyDataCol(uid).doc(dateKey).set(
      {
        'steps': steps,
        'water': water,
        'minutesActive': minutesActive,
        'cfScore': cfScore,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveDailyDataFromModel({
    required String uid,
    required DailyDataModel data,
    required int cfScore,
  }) {
    return saveDailyData(
      uid: uid,
      dateKey: data.dateKey,
      steps: data.steps,
      water: data.waterLiters,
      minutesActive: data.activeMinutes,
      cfScore: cfScore,
    );
  }

  Future<void> saveMeditationMinutes({
    required String uid,
    required String dateKey,
    required int meditationMinutes,
  }) async {
    await dailyStatsCol(uid).doc(dateKey).set(
      {
        'dateKey': dateKey,
        'meditationMinutes': meditationMinutes < 0 ? 0 : meditationMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveDailyTracking({
    required String uid,
    required String dateKey,
    required bool workoutCompleted,
    required int steps,
    required double waterLiters,
    required int mealsLoggedCount,
    required int meditationMinutes,
    required int cfIndex,
  }) async {
    await dailyStatsCol(uid).doc(dateKey).set(
      {
        'dateKey': dateKey,
        'workoutCompleted': workoutCompleted,
        'steps': steps < 0 ? 0 : steps,
        'waterLiters': waterLiters < 0 ? 0 : waterLiters,
        'mealsLoggedCount': mealsLoggedCount < 0 ? 0 : mealsLoggedCount,
        'meditationMinutes': meditationMinutes < 0 ? 0 : meditationMinutes,
        'cfIndex': cfIndex.clamp(0, 100),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveDailyMood({
    required String uid,
    required String dateKey,
    required String energia,
    required String animo,
    required String estres,
    required String sueno,
  }) async {
    await dailyMoodCol(uid).doc(dateKey).set(
      {
        'dateKey': dateKey,
        'energia': energia,
        'animo': animo,
        'estres': estres,
        'sueno': sueno,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Back-compat shim (older name) - uses the new daily_data structure.
  Future<void> saveDailyStats({
    required String uid,
    required DailyDataModel stats,
  }) {
    return saveDailyDataFromModel(uid: uid, data: stats, cfScore: 0);
  }

  Future<Map<String, Object?>?> getDailyData({
    required String uid,
    required String dateKey,
  }) async {
    final snap = await dailyDataCol(uid).doc(dateKey).get();
    final data = snap.data();
    if (data == null) return null;
    return Map<String, Object?>.from(data);
  }

  /// Back-compat shim - tries to deserialize into DailyDataModel when possible.
  Future<DailyDataModel?> getDailyStats({
    required String uid,
    required String dateKey,
  }) async {
    final map = await getDailyData(uid: uid, dateKey: dateKey);
    if (map == null) return null;
    // Accept both legacy keys (waterLiters/activeMinutes) and new keys (water/minutesActive).
    final normalized = <String, Object?>{
      ...map,
      if (!map.containsKey('waterLiters') && map['water'] != null) 'waterLiters': map['water'],
      if (!map.containsKey('activeMinutes') && map['minutesActive'] != null) 'activeMinutes': map['minutesActive'],
      'dateKey': dateKey,
    };
    final model = DailyDataModel.fromJson(normalized);
    return model.dateKey.trim().isEmpty ? null : model;
  }
}
