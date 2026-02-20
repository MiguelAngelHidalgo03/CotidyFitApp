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
