import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';
import 'connectivity_service.dart';
import 'my_day_local_service.dart';
import 'offline_sync_queue_service.dart';
import 'my_day_repository.dart';

class MyDayFirestoreService implements MyDayRepository {
  MyDayFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final MyDayLocalService _local = MyDayLocalService();

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _colForUid(String uid) {
    return _db.collection('users').doc(uid).collection('my_day_entries');
  }

  Future<void> setEntries(List<MyDayEntryModel> entries) async {
    final uid = _uid;
    if (uid == null) return;
    if (entries.isEmpty) return;

    final batch = _db.batch();
    final col = _colForUid(uid);
    for (final e in entries) {
      batch.set(col.doc(e.id), e.toJson(), SetOptions(merge: false));
    }
    await batch.commit();
  }

  @override
  Future<List<MyDayEntryModel>> getAll() async {
    final uid = _uid;
    if (uid == null) return _local.getAll();

    if (!ConnectivityService.instance.isOnline) {
      return _local.getAll();
    }

    try {
      final qs = await _colForUid(uid).get();
      final remote = <MyDayEntryModel>[];

      for (final doc in qs.docs) {
        final data = doc.data();
        final json = <String, dynamic>{...data};
        json.putIfAbsent('id', () => doc.id);
        final m = MyDayEntryModel.fromJson(json);
        if (m != null) remote.add(m);
      }

      final merged = await _mergeWithLocal(remote);
      await _local.replaceAll(merged);
      return merged;
    } catch (_) {
      return _local.getAll();
    }
  }

  @override
  Future<List<MyDayEntryModel>> getForDate(DateTime day) async {
    final uid = _uid;
    if (uid == null) return _local.getForDate(day);

    if (!ConnectivityService.instance.isOnline) {
      return _local.getForDate(day);
    }

    try {
      final dateKey = dateKeyFromDate(day);
      final qs = await _colForUid(
        uid,
      ).where('dateKey', isEqualTo: dateKey).get();

      final remote = <MyDayEntryModel>[];
      for (final doc in qs.docs) {
        final data = doc.data();
        final json = <String, dynamic>{...data};
        json.putIfAbsent('id', () => doc.id);
        final m = MyDayEntryModel.fromJson(json);
        if (m != null) remote.add(m);
      }

      final merged = await _mergeWithLocal(remote, dateKey: dateKey);
      final allLocal = await _local.getAll();
      final updatedAll = <MyDayEntryModel>[
        ...allLocal.where((entry) => entry.dateKey != dateKey),
        ...merged,
      ]..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
      await _local.replaceAll(updatedAll);
      return merged;
    } catch (_) {
      return _local.getForDate(day);
    }
  }

  @override
  Future<void> add({
    required DateTime day,
    required MealType mealType,
    required String recipeId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rid = recipeId.trim();
    if (rid.isEmpty) return;

    final entry = MyDayEntryModel(
      id: 'd_${now}_$rid',
      dateKey: dateKeyFromDate(day),
      mealType: mealType,
      recipeId: rid,
      addedAtMs: now,
    );

    await _local.addEntry(entry);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueMyDayEntryUpsert(
        uid: uid,
        entry: entry,
      );
      return;
    }

    try {
      await _colForUid(
        uid,
      ).doc(entry.id).set(entry.toJson(), SetOptions(merge: false));
    } catch (_) {
      await OfflineSyncQueueService.instance.queueMyDayEntryUpsert(
        uid: uid,
        entry: entry,
      );
    }
  }

  @override
  Future<void> addMany({
    required DateTime day,
    required List<({MealType mealType, String recipeId})> entries,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (entries.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dateKey = dateKeyFromDate(day);

    final newEntries = <MyDayEntryModel>[];
    var i = 0;
    for (final e in entries) {
      final rid = e.recipeId.trim();
      if (rid.isEmpty) continue;

      newEntries.add(
        MyDayEntryModel(
          id: 'd_${now}_${i}_$rid',
          dateKey: dateKey,
          mealType: e.mealType,
          recipeId: rid,
          addedAtMs: now,
        ),
      );
      i++;
    }

    if (newEntries.isEmpty) return;

    await _local.addEntries(newEntries);

    if (!ConnectivityService.instance.isOnline) {
      for (final entry in newEntries) {
        await OfflineSyncQueueService.instance.queueMyDayEntryUpsert(
          uid: uid,
          entry: entry,
        );
      }
      return;
    }

    try {
      final batch = _db.batch();
      for (final entry in newEntries) {
        batch.set(
          _colForUid(uid).doc(entry.id),
          entry.toJson(),
          SetOptions(merge: false),
        );
      }
      await batch.commit();
    } catch (_) {
      for (final entry in newEntries) {
        await OfflineSyncQueueService.instance.queueMyDayEntryUpsert(
          uid: uid,
          entry: entry,
        );
      }
    }
  }

  @override
  Future<void> remove(String entryId) async {
    final uid = _uid;
    if (uid == null) {
      await _local.remove(entryId);
      return;
    }
    final id = entryId.trim();
    if (id.isEmpty) return;

    await _local.remove(id);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueMyDayEntryDelete(
        uid: uid,
        entryId: id,
      );
      return;
    }

    try {
      await _colForUid(uid).doc(id).delete();
    } catch (_) {
      await OfflineSyncQueueService.instance.queueMyDayEntryDelete(
        uid: uid,
        entryId: id,
      );
    }
  }

  Future<List<MyDayEntryModel>> _mergeWithLocal(
    List<MyDayEntryModel> remote, {
    String? dateKey,
  }) async {
    final localItems = dateKey == null
        ? await _local.getAll()
        : await _local.getForDate(DateTime.parse(dateKey));
    final byId = <String, MyDayEntryModel>{
      for (final entry in remote) entry.id: entry,
      for (final entry in localItems) entry.id: entry,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return merged;
  }
}
