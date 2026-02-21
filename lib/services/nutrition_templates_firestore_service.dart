import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/nutrition_template_model.dart';
import '../models/template_recipe_link_model.dart';

class TemplateInteractions {
  const TemplateInteractions({
    required this.likedTemplateIds,
    required this.ratingByTemplateId,
  });

  final Set<String> likedTemplateIds;
  final Map<String, int> ratingByTemplateId;
}

class NutritionTemplatesFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  NutritionTemplatesFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Stream<List<NutritionTemplateModel>> watchTemplates({int limit = 50}) {
    if (Firebase.apps.isEmpty) {
      return const Stream<List<NutritionTemplateModel>>.empty();
    }

    return _db
        .collection('templates')
        .orderBy('total_likes', descending: true)
        .orderBy('avg_rating', descending: true)
        .orderBy('created_at', descending: true)
        .limit(limit.clamp(1, 200))
        .snapshots()
        .map((qs) {
          final out = <NutritionTemplateModel>[];
          for (final doc in qs.docs) {
            final m = NutritionTemplateModel.fromFirestore(doc);
            if (m != null) out.add(m);
          }
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
    out.sort((a, b) => a.mealSlot.compareTo(b.mealSlot));
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

    final cleaned = templateIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      return const TemplateInteractions(
        likedTemplateIds: <String>{},
        ratingByTemplateId: <String, int>{},
      );
    }

    final liked = <String>{};
    final ratings = <String, int>{};

    // Firestore whereIn has a 30 element limit.
    const chunkSize = 30;
    for (var i = 0; i < cleaned.length; i += chunkSize) {
      final chunk = cleaned.sublist(i, (i + chunkSize).clamp(0, cleaned.length));

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

    return TemplateInteractions(likedTemplateIds: liked, ratingByTemplateId: ratings);
  }

  Future<void> toggleLike({required String templateId}) async {
    final uid = currentUid;
    if (uid == null) return;
    final tid = templateId.trim();
    if (tid.isEmpty) return;

    final likeRef = _db.collection('template_likes').doc('${uid}_$tid');

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

    final ratingRef = _db.collection('template_ratings').doc('${uid}_$tid');

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
  }
}
