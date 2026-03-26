import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nutrition_template_model.dart';
import '../models/template_recipe_link_model.dart';
import '../utils/meal_slot_utils.dart';
import 'connectivity_service.dart';
import 'offline_sync_queue_service.dart';

class TemplateInteractions {
  const TemplateInteractions({
    required this.likedTemplateIds,
    required this.ratingByTemplateId,
  });

  final Set<String> likedTemplateIds;
  final Map<String, int> ratingByTemplateId;
}

class NutritionTemplatesFirestoreService {
  static const _kLikesPrefix = 'cf_template_likes_v1_';
  static const _kRatingsPrefix = 'cf_template_ratings_v1_';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  NutritionTemplatesFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _dbOverride = db,
       _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Stream<List<NutritionTemplateModel>> watchTemplates({int limit = 50}) {
    if (Firebase.apps.isEmpty || currentUid == null) {
      return const Stream<List<NutritionTemplateModel>>.empty();
    }

    return _db
        .collection('templates')
        .limit(limit.clamp(1, 200))
        .snapshots()
        .map((qs) {
          final out = <NutritionTemplateModel>[];
          for (final doc in qs.docs) {
            final m = NutritionTemplateModel.fromFirestore(doc);
            if (m != null) out.add(m);
          }
          out.sort((a, b) {
            final likes = b.totalLikes.compareTo(a.totalLikes);
            if (likes != 0) return likes;
            final rating = b.avgRating.compareTo(a.avgRating);
            if (rating != 0) return rating;
            return b.createdAtMs.compareTo(a.createdAtMs);
          });
          return out;
        });
  }

  Future<List<TemplateRecipeLinkModel>> getTemplateRecipes({
    required String templateId,
  }) async {
    if (Firebase.apps.isEmpty) return const [];
    final id = templateId.trim();
    if (id.isEmpty) return const [];

    final qs = await _db
        .collection('template_recipes')
        .where('template_id', isEqualTo: id)
        .get();

    final out = <TemplateRecipeLinkModel>[];
    for (final doc in qs.docs) {
      final data = doc.data();
      final m = TemplateRecipeLinkModel.fromFirestore(doc.id, data);
      if (m != null) out.add(m);
    }

    // Stable grouping order in UI.
    out.sort((a, b) {
      final slotOrder = compareMealSlots(a.mealSlot, b.mealSlot);
      if (slotOrder != 0) return slotOrder;
      return a.recipeId.compareTo(b.recipeId);
    });
    return out;
  }

  Future<TemplateInteractions> getUserInteractions({
    required List<String> templateIds,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return const TemplateInteractions(
        likedTemplateIds: <String>{},
        ratingByTemplateId: <String, int>{},
      );
    }

    final cleaned = templateIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return const TemplateInteractions(
        likedTemplateIds: <String>{},
        ratingByTemplateId: <String, int>{},
      );
    }

    final liked = <String>{};
    final ratings = <String, int>{};

    if (!ConnectivityService.instance.isOnline) {
      return _getCachedInteractions(uid: uid, templateIds: cleaned);
    }

    // Firestore whereIn has a 30 element limit.
    const chunkSize = 30;
    try {
      for (var i = 0; i < cleaned.length; i += chunkSize) {
        final chunk = cleaned.sublist(
          i,
          (i + chunkSize).clamp(0, cleaned.length),
        );

        final likesQs = await _db
            .collection('template_likes')
            .where('user_id', isEqualTo: uid)
            .where('template_id', whereIn: chunk)
            .get();
        for (final doc in likesQs.docs) {
          final tid = (doc.data()['template_id'] as String?)?.trim() ?? '';
          if (tid.isNotEmpty) liked.add(tid);
        }

        final ratingsQs = await _db
            .collection('template_ratings')
            .where('user_id', isEqualTo: uid)
            .where('template_id', whereIn: chunk)
            .get();
        for (final doc in ratingsQs.docs) {
          final data = doc.data();
          final tid = (data['template_id'] as String?)?.trim() ?? '';
          final r = data['rating'];
          if (tid.isEmpty) continue;
          if (r is int) ratings[tid] = r.clamp(1, 5);
          if (r is num) ratings[tid] = r.toInt().clamp(1, 5);
          if (r is String) {
            final parsed = int.tryParse(r);
            if (parsed != null) ratings[tid] = parsed.clamp(1, 5);
          }
        }
      }
    } catch (_) {
      return _getCachedInteractions(uid: uid, templateIds: cleaned);
    }

    await _saveCachedInteractions(
      uid: uid,
      likedTemplateIds: liked,
      ratingByTemplateId: ratings,
    );

    return TemplateInteractions(
      likedTemplateIds: liked,
      ratingByTemplateId: ratings,
    );
  }

  Future<void> toggleLike({required String templateId}) async {
    final uid = currentUid;
    if (uid == null) return;
    final tid = templateId.trim();
    if (tid.isEmpty) return;

    final liked = await _getCachedLikedTemplateIds(uid);
    final nextLiked = !liked.contains(tid);
    if (nextLiked) {
      liked.add(tid);
    } else {
      liked.remove(tid);
    }
    await _saveCachedLikedTemplateIds(uid, liked);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueTemplateLikeState(
        uid: uid,
        templateId: tid,
        liked: nextLiked,
      );
      return;
    }

    final likeRef = _db.collection('template_likes').doc('${uid}_$tid');

    try {
      await _db.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        if (likeSnap.exists) {
          tx.delete(likeRef);
        } else {
          tx.set(likeRef, {
            'user_id': uid,
            'template_id': tid,
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));
        }
      });
    } catch (_) {
      await OfflineSyncQueueService.instance.queueTemplateLikeState(
        uid: uid,
        templateId: tid,
        liked: nextLiked,
      );
    }
  }

  Future<void> setRating({
    required String templateId,
    required int rating,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final tid = templateId.trim();
    if (tid.isEmpty) return;

    final r = rating.clamp(1, 5);
    final ratings = await _getCachedTemplateRatings(uid);
    ratings[tid] = r;
    await _saveCachedTemplateRatings(uid, ratings);

    if (!ConnectivityService.instance.isOnline) {
      await OfflineSyncQueueService.instance.queueTemplateRating(
        uid: uid,
        templateId: tid,
        rating: r,
      );
      return;
    }

    final ratingRef = _db.collection('template_ratings').doc('${uid}_$tid');

    try {
      await _db.runTransaction((tx) async {
        final ratingSnap = await tx.get(ratingRef);

        if (!ratingSnap.exists) {
          tx.set(ratingRef, {
            'user_id': uid,
            'template_id': tid,
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
      await OfflineSyncQueueService.instance.queueTemplateRating(
        uid: uid,
        templateId: tid,
        rating: r,
      );
    }
  }

  Future<TemplateInteractions> _getCachedInteractions({
    required String uid,
    required List<String> templateIds,
  }) async {
    final liked = await _getCachedLikedTemplateIds(uid);
    final ratings = await _getCachedTemplateRatings(uid);
    final filteredIds = templateIds.toSet();

    return TemplateInteractions(
      likedTemplateIds: liked.where(filteredIds.contains).toSet(),
      ratingByTemplateId: <String, int>{
        for (final entry in ratings.entries)
          if (filteredIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Future<void> _saveCachedInteractions({
    required String uid,
    required Set<String> likedTemplateIds,
    required Map<String, int> ratingByTemplateId,
  }) async {
    await _saveCachedLikedTemplateIds(uid, likedTemplateIds);
    await _saveCachedTemplateRatings(uid, ratingByTemplateId);
  }

  Future<Set<String>> _getCachedLikedTemplateIds(String uid) async {
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

  Future<void> _saveCachedLikedTemplateIds(
    String uid,
    Set<String> likedIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kLikesPrefix$uid',
      jsonEncode(likedIds.toList()..sort()),
    );
  }

  Future<Map<String, int>> _getCachedTemplateRatings(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kRatingsPrefix$uid');
    if (raw == null || raw.trim().isEmpty) return <String, int>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      final ratings = <String, int>{};
      decoded.forEach((key, value) {
        final parsed = value is num
            ? value.toInt()
            : int.tryParse(value.toString());
        if (parsed != null) ratings[key.toString()] = parsed.clamp(1, 5);
      });
      return ratings;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveCachedTemplateRatings(
    String uid,
    Map<String, int> ratings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kRatingsPrefix$uid', jsonEncode(ratings));
  }
}
