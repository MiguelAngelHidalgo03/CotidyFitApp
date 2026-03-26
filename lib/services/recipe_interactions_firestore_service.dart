import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import 'offline_sync_queue_service.dart';

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
  static const _kLikesPrefix = 'cf_recipe_likes_v1_';
  static const _kRatingsPrefix = 'cf_recipe_ratings_v1_';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  RecipeInteractionsFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _dbOverride = db,
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

    if (!ConnectivityService.instance.isOnline) {
      return (await _getCachedLikedRecipeIds(uid)).contains(rid);
    }

    try {
      final doc = await _db.collection('recipe_likes').doc('${uid}_$rid').get();
      final likedIds = await _getCachedLikedRecipeIds(uid);
      if (doc.exists) {
        likedIds.add(rid);
      } else {
        likedIds.remove(rid);
      }
      await _saveCachedLikedRecipeIds(uid, likedIds);
      return doc.exists;
    } catch (_) {
      return (await _getCachedLikedRecipeIds(uid)).contains(rid);
    }
  }

  Future<Set<String>> getLikedRecipeIds() async {
    final uid = currentUid;
    if (uid == null) return <String>{};

    if (!ConnectivityService.instance.isOnline) {
      return _getCachedLikedRecipeIds(uid);
    }

    try {
      final qs = await _db
          .collection('recipe_likes')
          .where('user_id', isEqualTo: uid)
          .get();

      final out = <String>{};
      for (final doc in qs.docs) {
        final rid = (doc.data()['recipe_id'] as String?)?.trim() ?? '';
        if (rid.isNotEmpty) out.add(rid);
      }
      await _saveCachedLikedRecipeIds(uid, out);
      return out;
    } catch (_) {
      return _getCachedLikedRecipeIds(uid);
    }
  }

  Future<bool> toggleLike({required String recipeId}) async {
    final uid = currentUid;
    if (uid == null) return false;
    final rid = recipeId.trim();
    if (rid.isEmpty) return false;

    final cachedLikes = await _getCachedLikedRecipeIds(uid);
    final nextLiked = !cachedLikes.contains(rid);
    if (nextLiked) {
      cachedLikes.add(rid);
    } else {
      cachedLikes.remove(rid);
    }
    await _saveCachedLikedRecipeIds(uid, cachedLikes);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueRecipeLikeState(
        uid: uid,
        recipeId: rid,
        liked: nextLiked,
      );
      return nextLiked;
    }

    final likeRef = _db.collection('recipe_likes').doc('${uid}_$rid');

    bool nowLiked = false;
    try {
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
    } catch (_) {
      await OfflineSyncQueueService.instance.queueRecipeLikeState(
        uid: uid,
        recipeId: rid,
        liked: nextLiked,
      );
      return nextLiked;
    }

    final refreshedLikes = await _getCachedLikedRecipeIds(uid);
    if (nowLiked) {
      refreshedLikes.add(rid);
    } else {
      refreshedLikes.remove(rid);
    }
    await _saveCachedLikedRecipeIds(uid, refreshedLikes);
    return nowLiked;
  }

  // ── Ratings ────────────────────────────────────────────────────────────

  Future<double?> getMyRating({required String recipeId}) async {
    final uid = currentUid;
    if (uid == null) return null;
    final rid = recipeId.trim();
    if (rid.isEmpty) return null;

    if (!ConnectivityService.instance.isOnline) {
      return (await _getCachedRecipeRatings(uid))[rid];
    }

    try {
      final doc = await _db
          .collection('recipe_ratings')
          .doc('${uid}_$rid')
          .get();
      if (!doc.exists) return null;

      final r = doc.data()?['rating'];
      if (r is num) {
        final ratings = await _getCachedRecipeRatings(uid);
        ratings[rid] = r.toDouble().clamp(1, 5);
        await _saveCachedRecipeRatings(uid, ratings);
        return ratings[rid];
      }
      return null;
    } catch (_) {
      return (await _getCachedRecipeRatings(uid))[rid];
    }
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
    final ratings = await _getCachedRecipeRatings(uid);
    ratings[rid] = r;
    await _saveCachedRecipeRatings(uid, ratings);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueRecipeRating(
        uid: uid,
        recipeId: rid,
        rating: r,
      );
      return;
    }

    final ratingRef = _db.collection('recipe_ratings').doc('${uid}_$rid');

    try {
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
    } catch (_) {
      await OfflineSyncQueueService.instance.queueRecipeRating(
        uid: uid,
        recipeId: rid,
        rating: r,
      );
    }
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

    final cleaned = recipeIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return const RecipeInteractions(
        likedRecipeIds: <String>{},
        ratingByRecipeId: <String, double>{},
      );
    }

    final liked = <String>{};
    final ratings = <String, double>{};

    if (!ConnectivityService.instance.isOnline) {
      return _getCachedInteractions(uid: uid, recipeIds: cleaned);
    }

    const chunkSize = 30;
    try {
      for (var i = 0; i < cleaned.length; i += chunkSize) {
        final chunk = cleaned.sublist(
          i,
          (i + chunkSize).clamp(0, cleaned.length),
        );

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
    } catch (_) {
      return _getCachedInteractions(uid: uid, recipeIds: cleaned);
    }

    await _saveCachedInteractions(
      uid: uid,
      likedRecipeIds: liked,
      ratingByRecipeId: ratings,
    );

    return RecipeInteractions(likedRecipeIds: liked, ratingByRecipeId: ratings);
  }

  Future<RecipeInteractions> _getCachedInteractions({
    required String uid,
    required List<String> recipeIds,
  }) async {
    final liked = await _getCachedLikedRecipeIds(uid);
    final ratings = await _getCachedRecipeRatings(uid);
    final filteredIds = recipeIds.toSet();

    return RecipeInteractions(
      likedRecipeIds: liked.where(filteredIds.contains).toSet(),
      ratingByRecipeId: <String, double>{
        for (final entry in ratings.entries)
          if (filteredIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Future<void> _saveCachedInteractions({
    required String uid,
    required Set<String> likedRecipeIds,
    required Map<String, double> ratingByRecipeId,
  }) async {
    await _saveCachedLikedRecipeIds(uid, likedRecipeIds);
    await _saveCachedRecipeRatings(uid, ratingByRecipeId);
  }

  Future<Set<String>> _getCachedLikedRecipeIds(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kLikesPrefix$uid');
    if (raw == null || raw.trim().isEmpty) return <String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveCachedLikedRecipeIds(
    String uid,
    Set<String> likedIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kLikesPrefix$uid',
      jsonEncode(likedIds.toList()..sort()),
    );
  }

  Future<Map<String, double>> _getCachedRecipeRatings(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kRatingsPrefix$uid');
    if (raw == null || raw.trim().isEmpty) return <String, double>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, double>{};
      final ratings = <String, double>{};
      decoded.forEach((key, value) {
        final parsed = value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (parsed != null) ratings[key.toString()] = parsed.clamp(1, 5);
      });
      return ratings;
    } catch (_) {
      return <String, double>{};
    }
  }

  Future<void> _saveCachedRecipeRatings(
    String uid,
    Map<String, double> ratings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kRatingsPrefix$uid', jsonEncode(ratings));
  }
}
