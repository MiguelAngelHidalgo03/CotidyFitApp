import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/food_model.dart';

/// Service for per-user custom foods stored at
/// `users/{userId}/customFoods/{foodId}`.
///
/// Reuses [FoodModel] (same fields as global foods).
class CustomFoodsFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  CustomFoodsFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('customFoods');
  }

  /// Get all custom foods for the current user.
  Future<List<FoodModel>> getAll() async {
    final col = _col;
    if (col == null) return const [];

    final qs = await col.orderBy('name').get();
    final out = <FoodModel>[];
    for (final doc in qs.docs) {
      final m = FoodModel.fromFirestore(doc.id, doc.data());
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Add a custom food. Returns the generated id.
  Future<String?> add(FoodModel food) async {
    final col = _col;
    if (col == null) return null;

    final ref = await col.add({
      ...food.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Update an existing custom food.
  Future<void> update(FoodModel food) async {
    final col = _col;
    if (col == null) return;

    await col.doc(food.id).set({
      ...food.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete a custom food.
  Future<void> delete(String foodId) async {
    final col = _col;
    if (col == null) return;
    await col.doc(foodId).delete();
  }

  /// Search custom foods by name (client-side).
  Future<List<FoodModel>> search(String query) async {
    final all = await getAll();
    if (query.trim().isEmpty) return all;

    final q = query.trim().toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}
