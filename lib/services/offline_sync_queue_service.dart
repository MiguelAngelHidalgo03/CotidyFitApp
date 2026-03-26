import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_data_model.dart';
import '../models/my_day_entry_model.dart';
import '../models/user_profile.dart';
import 'connectivity_service.dart';
import 'firestore_service.dart';

class OfflineSyncQueueService extends ChangeNotifier {
  OfflineSyncQueueService._();

  static final OfflineSyncQueueService instance = OfflineSyncQueueService._();

  static const _kQueueKey = 'cf_offline_sync_queue_v1';
  static const _kLastSyncedAtKey = 'cf_offline_sync_last_synced_at_ms';

  FirestoreService? _firestoreService;

  final List<_QueuedSyncTask> _tasks = <_QueuedSyncTask>[];

  bool _initialized = false;
  bool _isSyncing = false;
  int? _lastSyncedAtMs;
  StreamSubscription<User?>? _authSubscription;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _tasks.length;
  int? get lastSyncedAtMs => _lastSyncedAtMs;

  FirestoreService get _firestore {
    return _firestoreService ??= FirestoreService();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _restore();
    ConnectivityService.instance.addListener(_handleConnectivityChange);

    if (Firebase.apps.isNotEmpty) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(processPending());
      });
    }

    unawaited(processPending());
  }

  Future<void> queueProfileUpsert({
    required String uid,
    required UserProfile profile,
    String? email,
  }) {
    return _enqueue(
      type: 'profileUpsert',
      dedupeKey: 'profile:$uid',
      payload: <String, Object?>{
        'uid': uid,
        'email': email,
        'profile': profile.toJson(),
      },
    );
  }

  Future<void> queueDailySync({
    required String uid,
    required DailyDataModel data,
    required int cfScore,
    required bool workoutCompleted,
    required int mealsLoggedCount,
  }) {
    return _enqueue(
      type: 'dailySync',
      dedupeKey: 'daily:$uid:${data.dateKey}',
      payload: <String, Object?>{
        'uid': uid,
        'data': data.toJson(),
        'cfScore': cfScore,
        'workoutCompleted': workoutCompleted,
        'mealsLoggedCount': mealsLoggedCount,
      },
    );
  }

  Future<void> queueMeditationSync({
    required String uid,
    required String dateKey,
    required int meditationMinutes,
  }) {
    return _enqueue(
      type: 'meditationSync',
      dedupeKey: 'meditation:$uid:$dateKey',
      payload: <String, Object?>{
        'uid': uid,
        'dateKey': dateKey,
        'meditationMinutes': meditationMinutes,
      },
    );
  }

  Future<void> queueMoodSync({
    required String uid,
    required String dateKey,
    required String energia,
    required String animo,
    required String estres,
    required String sueno,
  }) {
    return _enqueue(
      type: 'moodSync',
      dedupeKey: 'mood:$uid:$dateKey',
      payload: <String, Object?>{
        'uid': uid,
        'dateKey': dateKey,
        'energia': energia,
        'animo': animo,
        'estres': estres,
        'sueno': sueno,
      },
    );
  }

  Future<void> queueRecipeLikeState({
    required String uid,
    required String recipeId,
    required bool liked,
  }) {
    return _enqueue(
      type: 'recipeLikeState',
      dedupeKey: 'recipe-like:$uid:$recipeId',
      payload: <String, Object?>{
        'uid': uid,
        'recipeId': recipeId,
        'liked': liked,
      },
    );
  }

  Future<void> queueRecipeRating({
    required String uid,
    required String recipeId,
    required double rating,
  }) {
    return _enqueue(
      type: 'recipeRating',
      dedupeKey: 'recipe-rating:$uid:$recipeId',
      payload: <String, Object?>{
        'uid': uid,
        'recipeId': recipeId,
        'rating': rating,
      },
    );
  }

  Future<void> queueTemplateLikeState({
    required String uid,
    required String templateId,
    required bool liked,
  }) {
    return _enqueue(
      type: 'templateLikeState',
      dedupeKey: 'template-like:$uid:$templateId',
      payload: <String, Object?>{
        'uid': uid,
        'templateId': templateId,
        'liked': liked,
      },
    );
  }

  Future<void> queueTemplateRating({
    required String uid,
    required String templateId,
    required int rating,
  }) {
    return _enqueue(
      type: 'templateRating',
      dedupeKey: 'template-rating:$uid:$templateId',
      payload: <String, Object?>{
        'uid': uid,
        'templateId': templateId,
        'rating': rating,
      },
    );
  }

  Future<void> queueMyDayEntryUpsert({
    required String uid,
    required MyDayEntryModel entry,
  }) {
    return _enqueue(
      type: 'myDayEntryUpsert',
      dedupeKey: 'myday:$uid:${entry.id}',
      payload: <String, Object?>{'uid': uid, 'entry': entry.toJson()},
    );
  }

  Future<void> queueMyDayEntryDelete({
    required String uid,
    required String entryId,
  }) {
    return _enqueue(
      type: 'myDayEntryDelete',
      dedupeKey: 'myday:$uid:$entryId',
      payload: <String, Object?>{'uid': uid, 'entryId': entryId},
    );
  }

  Future<void> processPending() async {
    if (!_initialized) return;
    if (_isSyncing) return;
    if (!ConnectivityService.instance.isOnline) return;
    if (_tasks.isEmpty) return;
    if (Firebase.apps.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      var didProgress = true;
      while (didProgress && ConnectivityService.instance.isOnline) {
        didProgress = false;

        final snapshot = List<_QueuedSyncTask>.from(_tasks);
        for (final task in snapshot) {
          if (task.uid != null && task.uid != user.uid) continue;

          final ok = await _processTask(task);
          if (!ok) {
            if (!ConnectivityService.instance.isOnline) break;
            continue;
          }

          _tasks.removeWhere((candidate) => candidate.id == task.id);
          didProgress = true;
          _lastSyncedAtMs = DateTime.now().millisecondsSinceEpoch;
          await _persist();
          notifyListeners();
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _enqueue({
    required String type,
    required String dedupeKey,
    required Map<String, Object?> payload,
  }) async {
    final task = _QueuedSyncTask(
      id: '${DateTime.now().microsecondsSinceEpoch}_$dedupeKey',
      dedupeKey: dedupeKey,
      type: type,
      payload: payload,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _tasks.removeWhere((existing) => existing.dedupeKey == dedupeKey);
    _tasks.add(task);
    await _persist();
    notifyListeners();
    unawaited(processPending());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSyncedAtMs = prefs.getInt(_kLastSyncedAtKey);

    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _tasks
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map((item) {
            final casted = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            return _QueuedSyncTask.fromJson(casted);
          }).whereType<_QueuedSyncTask>(),
        );
    } catch (_) {
      _tasks.clear();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kQueueKey,
      jsonEncode(<Object?>[for (final task in _tasks) task.toJson()]),
    );

    if (_lastSyncedAtMs != null) {
      await prefs.setInt(_kLastSyncedAtKey, _lastSyncedAtMs!);
    }
  }

  void _handleConnectivityChange() {
    if (!ConnectivityService.instance.isOnline) {
      notifyListeners();
      return;
    }
    unawaited(processPending());
  }

  Future<bool> _processTask(_QueuedSyncTask task) async {
    final payload = task.payload;
    final uid = task.uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      switch (task.type) {
        case 'profileUpsert':
          final profileMap = payload['profile'];
          if (profileMap is! Map) return false;
          final profile = UserProfile.fromJson(
            profileMap.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (profile == null) return false;
          await _firestore.upsertUser(
            uid: uid,
            email: payload['email'] as String?,
            profile: profile,
          );
          return true;
        case 'dailySync':
          final rawData = payload['data'];
          if (rawData is! Map) return false;
          final data = DailyDataModel.fromJson(
            rawData.map((key, value) => MapEntry(key.toString(), value)),
          );
          final cfScore = (payload['cfScore'] as num?)?.toInt() ?? 0;
          final workoutCompleted = payload['workoutCompleted'] == true;
          final mealsLoggedCount =
              (payload['mealsLoggedCount'] as num?)?.toInt() ?? 0;

          await _firestore.saveDailyDataFromModel(
            uid: uid,
            data: data,
            cfScore: cfScore,
          );
          await _firestore.saveDailyTracking(
            uid: uid,
            dateKey: data.dateKey,
            workoutCompleted: workoutCompleted,
            steps: data.steps,
            waterLiters: data.waterLiters,
            mealsLoggedCount: mealsLoggedCount,
            meditationMinutes: data.meditationMinutes,
            cfIndex: cfScore,
          );
          return true;
        case 'meditationSync':
          await _firestore.saveMeditationMinutes(
            uid: uid,
            dateKey: (payload['dateKey'] as String?) ?? '',
            meditationMinutes:
                (payload['meditationMinutes'] as num?)?.toInt() ?? 0,
          );
          return true;
        case 'moodSync':
          await _firestore.saveDailyMood(
            uid: uid,
            dateKey: (payload['dateKey'] as String?) ?? '',
            energia: (payload['energia'] as String?) ?? 'media',
            animo: (payload['animo'] as String?) ?? 'medio',
            estres: (payload['estres'] as String?) ?? 'medio',
            sueno: (payload['sueno'] as String?) ?? 'normal',
          );
          return true;
        case 'recipeLikeState':
          await _applyRecipeLikeState(
            uid: uid,
            recipeId: (payload['recipeId'] as String?) ?? '',
            liked: payload['liked'] == true,
          );
          return true;
        case 'recipeRating':
          await _applyRecipeRating(
            uid: uid,
            recipeId: (payload['recipeId'] as String?) ?? '',
            rating: ((payload['rating'] as num?) ?? 0).toDouble(),
          );
          return true;
        case 'templateLikeState':
          await _applyTemplateLikeState(
            uid: uid,
            templateId: (payload['templateId'] as String?) ?? '',
            liked: payload['liked'] == true,
          );
          return true;
        case 'templateRating':
          await _applyTemplateRating(
            uid: uid,
            templateId: (payload['templateId'] as String?) ?? '',
            rating: (payload['rating'] as num?)?.toInt() ?? 0,
          );
          return true;
        case 'myDayEntryUpsert':
          final rawEntry = payload['entry'];
          if (rawEntry is! Map) return false;
          final entry = MyDayEntryModel.fromJson(
            rawEntry.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (entry == null) return false;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('my_day_entries')
              .doc(entry.id)
              .set(entry.toJson(), SetOptions(merge: false));
          return true;
        case 'myDayEntryDelete':
          final entryId = (payload['entryId'] as String?)?.trim() ?? '';
          if (entryId.isEmpty) return false;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('my_day_entries')
              .doc(entryId)
              .delete();
          return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<void> _applyRecipeLikeState({
    required String uid,
    required String recipeId,
    required bool liked,
  }) async {
    final rid = recipeId.trim();
    if (rid.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('recipe_likes')
        .doc('${uid}_$rid');
    if (liked) {
      await ref.set({
        'user_id': uid,
        'recipe_id': rid,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
      return;
    }
    await ref.delete();
  }

  Future<void> _applyRecipeRating({
    required String uid,
    required String recipeId,
    required double rating,
  }) async {
    final rid = recipeId.trim();
    if (rid.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('recipe_ratings')
        .doc('${uid}_$rid');
    final nextRating = rating.clamp(1, 5);
    await ref.set({
      'user_id': uid,
      'recipe_id': rid,
      'rating': nextRating,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyTemplateLikeState({
    required String uid,
    required String templateId,
    required bool liked,
  }) async {
    final tid = templateId.trim();
    if (tid.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('template_likes')
        .doc('${uid}_$tid');
    if (liked) {
      await ref.set({
        'user_id': uid,
        'template_id': tid,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
      return;
    }
    await ref.delete();
  }

  Future<void> _applyTemplateRating({
    required String uid,
    required String templateId,
    required int rating,
  }) async {
    final tid = templateId.trim();
    if (tid.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('template_ratings')
        .doc('${uid}_$tid');
    final nextRating = rating.clamp(1, 5);
    await ref.set({
      'user_id': uid,
      'template_id': tid,
      'rating': nextRating,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_handleConnectivityChange);
    _authSubscription?.cancel();
    super.dispose();
  }
}

class _QueuedSyncTask {
  const _QueuedSyncTask({
    required this.id,
    required this.dedupeKey,
    required this.type,
    required this.payload,
    required this.createdAtMs,
  });

  final String id;
  final String dedupeKey;
  final String type;
  final Map<String, Object?> payload;
  final int createdAtMs;

  String? get uid => (payload['uid'] as String?)?.trim();

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'dedupeKey': dedupeKey,
      'type': type,
      'payload': payload,
      'createdAtMs': createdAtMs,
    };
  }

  static _QueuedSyncTask? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final dedupeKey = json['dedupeKey'];
    final type = json['type'];
    final payload = json['payload'];
    final createdAtMs = json['createdAtMs'];

    if (id is! String || id.trim().isEmpty) return null;
    if (dedupeKey is! String || dedupeKey.trim().isEmpty) return null;
    if (type is! String || type.trim().isEmpty) return null;
    if (payload is! Map) return null;
    if (createdAtMs is! num) return null;

    return _QueuedSyncTask(
      id: id,
      dedupeKey: dedupeKey,
      type: type,
      payload: payload.map((key, value) => MapEntry(key.toString(), value)),
      createdAtMs: createdAtMs.toInt(),
    );
  }
}
