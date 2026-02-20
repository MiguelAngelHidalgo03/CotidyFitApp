import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'social_firestore_service.dart';
import 'chat_service.dart';

class BlockService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final ChatService _chatService;

  BlockService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth,
        _chatService = ChatService(db: db, auth: auth);

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Future<void> ensureBlocksDocBackfilled() async {
    final uid = currentUid;
    if (uid == null) return;

    final blocksRef = _db.collection('user_blocks').doc(uid);
    try {
      final blocksSnap = await blocksRef.get();
      if (blocksSnap.exists) return;
    } catch (_) {
      // ignore
    }

    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      final raw = userSnap.data()?['blockedUsers'];
      final blocked = <String>[];
      if (raw is List) {
        for (final v in raw) {
          final s = v?.toString().trim();
          if (s != null && s.isNotEmpty) blocked.add(s);
        }
      }
      await blocksRef.set(
        {
          'blockedUsers': blocked,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore
    }
  }

  Stream<List<String>> watchBlockedUserIds() {
    final uid = currentUid;
    if (uid == null) return const Stream<List<String>>.empty();

    // Best-effort: ensure rules-visible mirror exists.
    ensureBlocksDocBackfilled();

    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      final raw = data?['blockedUsers'];
      if (raw is! List) return const <String>[];
      final out = <String>[];
      for (final v in raw) {
        final s = v?.toString().trim();
        if (s != null && s.isNotEmpty) out.add(s);
      }
      out.sort();
      return out;
    });
  }

  Future<List<String>> getBlockedUserIdsOnce() async {
    final uid = currentUid;
    if (uid == null) return const [];

    await ensureBlocksDocBackfilled();
    final snap = await _db.collection('users').doc(uid).get();
    final raw = snap.data()?['blockedUsers'];
    if (raw is! List) return const [];
    final out = <String>[];
    for (final v in raw) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) out.add(s);
    }
    return out;
  }

  Future<void> blockUser({required String blockedUid}) async {
    final uid = currentUid;
    if (uid == null) return;

    final target = blockedUid.trim();
    if (target.isEmpty || target == uid) return;

    final pairId = SocialFirestoreService.pairIdFor(uid, target);

    final meRef = _db.collection('users').doc(uid);
    final blocksRef = _db.collection('user_blocks').doc(uid);

    // 1) Always persist the block itself.
    await meRef.set(
      {
        'blockedUsers': FieldValue.arrayUnion([target]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Mirror into user_blocks so security rules can check both directions.
    await blocksRef.set(
      {
        'blockedUsers': FieldValue.arrayUnion([target]),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 2) Best-effort cleanup. These deletes can fail if docs don't exist,
    // because the rules for delete rely on `resource.data`.
    final friendshipRef = _db.collection('friendships').doc(pairId);
    final requestRef = _db.collection('friend_requests').doc(pairId);
    
    // Delete chat + messages via admin function (robust).
    try {
      await _chatService.purgeChat(chatId: pairId);
    } catch (_) {
      // ignore
    }

    try {
      await friendshipRef.delete();
    } catch (_) {
      // ignore
    }
    try {
      await requestRef.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> unblockUser({required String blockedUid}) async {
    final uid = currentUid;
    if (uid == null) return;

    final target = blockedUid.trim();
    if (target.isEmpty) return;

    final pairId = SocialFirestoreService.pairIdFor(uid, target);

    await _db.collection('users').doc(uid).set(
      {
        'blockedUsers': FieldValue.arrayRemove([target]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Mirror into user_blocks.
    await _db.collection('user_blocks').doc(uid).set(
      {
        'blockedUsers': FieldValue.arrayRemove([target]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // No auto-restore. Ensure there is no residual social state that blocks new requests.
    try {
      await _db.collection('friendships').doc(pairId).delete();
    } catch (_) {
      // ignore
    }
    try {
      await _db.collection('friend_requests').doc(pairId).delete();
    } catch (_) {
      // ignore
    }
    try {
      await _chatService.purgeChat(chatId: pairId);
    } catch (_) {
      // ignore
    }
  }
}
