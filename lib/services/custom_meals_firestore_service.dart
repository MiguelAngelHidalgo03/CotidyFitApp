import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/custom_meal_model.dart';
import '../models/recipe_model.dart';

class CustomMealsFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  CustomMealsFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _dailyCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('my_day_custom_meals');
  }

  CollectionReference<Map<String, dynamic>>? get _savedCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('saved_custom_meals');
  }

  Future<List<CustomMealEntryModel>> getForDateKey(String dateKey) async {
    final col = _dailyCol;
    if (col == null) return const [];

    final dk = dateKey.trim();
    if (dk.isEmpty) return const [];

    final qs = await col.where('dateKey', isEqualTo: dk).get();

    final out = <CustomMealEntryModel>[];
    for (final doc in qs.docs) {
      final data = <String, Object?>{...doc.data()};
      data.putIfAbsent('id', () => doc.id);
      final m = CustomMealEntryModel.fromJson(data);
      if (m != null) out.add(m);
    }

    out.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return out;
  }

  Future<void> addCustomMeal({
    required String dateKey,
    required MealType mealType,
    required CustomMealModel meal,
  }) async {
    final col = _dailyCol;
    if (col == null) return;

    final dk = dateKey.trim();
    if (dk.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final entryId = 'cm_${now}_${meal.id}';

    await col.doc(entryId).set({
      'id': entryId,
      'dateKey': dk,
      'mealType': mealType.name,
      'meal': meal.toJson(),
      'addedAtMs': now,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  Future<void> removeCustomMeal(String entryId) async {
    final col = _dailyCol;
    if (col == null) return;

    final id = entryId.trim();
    if (id.isEmpty) return;

    await col.doc(id).delete();
  }

  Future<void> setDailyEntriesForDate({
    required String dateKey,
    required List<CustomMealEntryModel> entries,
  }) async {
    final col = _dailyCol;
    if (col == null || entries.isEmpty) return;

    final dk = dateKey.trim();
    if (dk.isEmpty) return;

    final batch = _db.batch();
    for (final e in entries) {
      batch.set(col.doc(e.id), {
        'id': e.id,
        'dateKey': dk,
        'mealType': e.mealType.name,
        'meal': e.meal.toJson(),
        'addedAtMs': e.addedAtMs,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<CustomMealModel>> getSavedMeals() async {
    final col = _savedCol;
    if (col == null) return const [];

    final qs = await col.get();
    final items = <({int savedAtMs, CustomMealModel meal})>[];

    for (final doc in qs.docs) {
      final data = doc.data();
      final rawMeal = data['meal'];
      if (rawMeal is! Map) continue;

      final map = rawMeal.map((k, v) => MapEntry(k.toString(), v));
      final meal = CustomMealModel.fromJson(map);
      if (meal == null) continue;

      final savedAtRaw = data['savedAtMs'];
      final savedAtMs = savedAtRaw is int
          ? savedAtRaw
          : (savedAtRaw is num ? savedAtRaw.toInt() : 0);

      items.add((savedAtMs: savedAtMs, meal: meal));
    }

    items.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return [for (final e in items) e.meal];
  }

  Future<void> saveSavedMeal(CustomMealModel meal) async {
    final col = _savedCol;
    if (col == null) return;

    final id = meal.id.trim();
    if (id.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await col.doc(id).set({
      'id': id,
      'meal': meal.toJson(),
      'savedAtMs': now,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setSavedMeals(List<CustomMealModel> meals) async {
    final col = _savedCol;
    if (col == null || meals.isEmpty) return;

    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final meal in meals) {
      final id = meal.id.trim();
      if (id.isEmpty) continue;
      batch.set(col.doc(id), {
        'id': id,
        'meal': meal.toJson(),
        'savedAtMs': now,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> removeSavedMeal(String mealId) async {
    final col = _savedCol;
    if (col == null) return;

    final id = mealId.trim();
    if (id.isEmpty) return;

    await col.doc(id).delete();
  }
}
