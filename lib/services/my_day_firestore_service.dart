import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';
import 'my_day_repository.dart';

class MyDayFirestoreService implements MyDayRepository {
  MyDayFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

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
    if (uid == null) return const [];

    final qs = await _colForUid(uid).get();
    final out = <MyDayEntryModel>[];

    for (final doc in qs.docs) {
      final data = doc.data();
      final json = <String, dynamic>{...data};
      json.putIfAbsent('id', () => doc.id);
      final m = MyDayEntryModel.fromJson(json);
      if (m != null) out.add(m);
    }

    out.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return out;
  }

  @override
  Future<List<MyDayEntryModel>> getForDate(DateTime day) async {
    final uid = _uid;
    if (uid == null) return const [];

    final dateKey = dateKeyFromDate(day);
    final qs = await _colForUid(uid).where('dateKey', isEqualTo: dateKey).get();

    final out = <MyDayEntryModel>[];
    for (final doc in qs.docs) {
      final data = doc.data();
      final json = <String, dynamic>{...data};
      json.putIfAbsent('id', () => doc.id);
      final m = MyDayEntryModel.fromJson(json);
      if (m != null) out.add(m);
    }

    out.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return out;
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

    await _colForUid(uid).doc(entry.id).set(entry.toJson(), SetOptions(merge: false));
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

    final batch = _db.batch();
    var i = 0;
    for (final e in entries) {
      final rid = e.recipeId.trim();
      if (rid.isEmpty) continue;

      final entry = MyDayEntryModel(
        id: 'd_${now}_${i}_$rid',
        dateKey: dateKey,
        mealType: e.mealType,
        recipeId: rid,
        addedAtMs: now,
      );

      batch.set(_colForUid(uid).doc(entry.id), entry.toJson(), SetOptions(merge: false));
      i++;
    }

    await batch.commit();
  }

  @override
  Future<void> remove(String entryId) async {
    final uid = _uid;
    if (uid == null) return;
    final id = entryId.trim();
    if (id.isEmpty) return;

    await _colForUid(uid).doc(id).delete();
  }
}
