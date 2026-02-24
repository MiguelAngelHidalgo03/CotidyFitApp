import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firestore-backed recipe likes & ratings.
///
/// Uses top-level collections (same pattern as template_likes / template_ratings):
///   recipe_likes/{uid}_{recipeId}
///   recipe_ratings/{uid}_{recipeId}
///
/// Cloud Functions triggers maintain aggregate fields on each recipe doc:
///   totalLikes, avgRating, ratingCount, ratingSum.

class RecipeInteractions {
  const RecipeInteractions({
    required this.likedRecipeIds,
    required this.ratingByRecipeId,
  });

  final Set<String> likedRecipeIds;
  final Map<String, double> ratingByRecipeId;
}

class RecipeInteractionsFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  RecipeInteractionsFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  // ── Likes ──────────────────────────────────────────────────────────────

  Future<bool> isLiked({required String recipeId}) async {
    final uid = currentUid;
    if (uid == null) return false;
    final rid = recipeId.trim();
    if (rid.isEmpty) return false;

    final doc =
        await _db.collection('recipe_likes').doc('${uid}_$rid').get();
    return doc.exists;
  }

  Future<Set<String>> getLikedRecipeIds() async {
    final uid = currentUid;
    if (uid == null) return <String>{};

    final qs = await _db
        .collection('recipe_likes')
        .where('user_id', isEqualTo: uid)
        .get();

    final out = <String>{};
    for (final doc in qs.docs) {
      final rid = (doc.data()['recipe_id'] as String?)?.trim() ?? '';
      if (rid.isNotEmpty) out.add(rid);
    }
    return out;
  }

  Future<bool> toggleLike({required String recipeId}) async {
    final uid = currentUid;
    if (uid == null) return false;
    final rid = recipeId.trim();
    if (rid.isEmpty) return false;

    final likeRef = _db.collection('recipe_likes').doc('${uid}_$rid');

    bool nowLiked = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(likeRef);
      if (snap.exists) {
        tx.delete(likeRef);
        nowLiked = false;
      } else {
        tx.set(likeRef, {
          'user_id': uid,
          'recipe_id': rid,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
        nowLiked = true;
      }
    });
    return nowLiked;
  }

  // ── Ratings ────────────────────────────────────────────────────────────

  Future<double?> getMyRating({required String recipeId}) async {
    final uid = currentUid;
    if (uid == null) return null;
    final rid = recipeId.trim();
    if (rid.isEmpty) return null;

    final doc =
        await _db.collection('recipe_ratings').doc('${uid}_$rid').get();
    if (!doc.exists) return null;

    final r = doc.data()?['rating'];
    if (r is num) return r.toDouble().clamp(1, 5);
    return null;
  }

  Future<void> setRating({
    required String recipeId,
    required double rating,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final rid = recipeId.trim();
    if (rid.isEmpty) return;

    final r = rating.clamp(1, 5).toDouble();
    final ratingRef =
        _db.collection('recipe_ratings').doc('${uid}_$rid');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ratingRef);

      if (!snap.exists) {
        tx.set(ratingRef, {
          'user_id': uid,
          'recipe_id': rid,
          'rating': r,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
        return;
      }

      tx.update(ratingRef, {
        'rating': r,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Batch interactions (for list views) ────────────────────────────────

  Future<RecipeInteractions> getUserInteractions({
    required List<String> recipeIds,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return const RecipeInteractions(
        likedRecipeIds: <String>{},
        ratingByRecipeId: <String, double>{},
      );
    }

    final cleaned =
        recipeIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      return const RecipeInteractions(
        likedRecipeIds: <String>{},
        ratingByRecipeId: <String, double>{},
      );
    }

    final liked = <String>{};
    final ratings = <String, double>{};

    const chunkSize = 30;
    for (var i = 0; i < cleaned.length; i += chunkSize) {
      final chunk =
          cleaned.sublist(i, (i + chunkSize).clamp(0, cleaned.length));

      final likesQs = await _db
          .collection('recipe_likes')
          .where('user_id', isEqualTo: uid)
          .where('recipe_id', whereIn: chunk)
          .get();
      for (final doc in likesQs.docs) {
        final rid = (doc.data()['recipe_id'] as String?)?.trim() ?? '';
        if (rid.isNotEmpty) liked.add(rid);
      }

      final ratingsQs = await _db
          .collection('recipe_ratings')
          .where('user_id', isEqualTo: uid)
          .where('recipe_id', whereIn: chunk)
          .get();
      for (final doc in ratingsQs.docs) {
        final data = doc.data();
        final rid = (data['recipe_id'] as String?)?.trim() ?? '';
        final r = data['rating'];
        if (rid.isEmpty) continue;
        if (r is num) ratings[rid] = r.toDouble().clamp(1, 5);
      }
    }

    return RecipeInteractions(
      likedRecipeIds: liked,
      ratingByRecipeId: ratings,
    );
  }
}
