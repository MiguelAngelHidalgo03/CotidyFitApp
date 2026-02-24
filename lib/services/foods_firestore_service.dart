import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/food_model.dart';

/// Service for the global `foods` collection (admin-editable).
///
/// Read-only for regular users.
class FoodsFirestoreService {
  final FirebaseFirestore? _dbOverride;

  FoodsFirestoreService({FirebaseFirestore? db}) : _dbOverride = db;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Returns all global foods, cached locally for 10 min.
  Future<List<FoodModel>> getAllFoods() async {
    if (Firebase.apps.isEmpty) return const [];
    if (FirebaseAuth.instance.currentUser == null) return const [];

    final qs = await _db
        .collection('foods')
        .orderBy('name')
        .get(const GetOptions(source: Source.serverAndCache));

    final out = <FoodModel>[];
    for (final doc in qs.docs) {
      final m = FoodModel.fromFirestore(doc.id, doc.data());
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Search foods by name (client-side filter on cached list).
  Future<List<FoodModel>> searchFoods(String query) async {
    final all = await getAllFoods();
    if (query.trim().isEmpty) return all;

    final q = query.trim().toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}
