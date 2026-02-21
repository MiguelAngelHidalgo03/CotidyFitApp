import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/recipe_model.dart';
import 'recipe_repository.dart';

class RecipesFirestoreService implements RecipeRepository {
  RecipesFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _recipes => _db.collection('recipes');

  @override
  Future<void> seedIfEmpty() async {
    // No-op: recipes are managed in Firestore.
  }

  @override
  Future<List<RecipeModel>> getAllRecipes() async {
    final uid = _uid;
    if (uid == null) return const [];

    final qs = await _recipes.limit(500).get();
    final out = <RecipeModel>[];

    for (final doc in qs.docs) {
      final data = doc.data();
      final json = <String, dynamic>{...data};
      json.putIfAbsent('id', () => doc.id);
      final m = RecipeModel.fromJson(json);
      if (m != null) out.add(m);
    }

    return out;
  }

  @override
  Future<RecipeModel?> getRecipeById(String id) async {
    final uid = _uid;
    if (uid == null) return null;

    final rid = id.trim();
    if (rid.isEmpty) return null;

    final snap = await _recipes.doc(rid).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final json = <String, dynamic>{...data};
    json.putIfAbsent('id', () => snap.id);
    return RecipeModel.fromJson(json);
  }
}
