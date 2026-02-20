import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';


class ChatService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;

  ChatService({FirebaseFirestore? db, FirebaseAuth? auth, FirebaseFunctions? functions})
      : _dbOverride = db,
        _authOverride = auth,
        _functionsOverride = functions;

  FirebaseFunctions get _functions => _functionsOverride ?? FirebaseFunctions.instance;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  // New storage (preferred): users/{uid}/mutedChats/{chatId}
  DocumentReference<Map<String, dynamic>> _mutedRef({required String uid, required String chatId}) {
    return _db.collection('users').doc(uid).collection('mutedChats').doc(chatId);
  }

  // Legacy storage (kept for backward compatibility): mutedChats/{uid_chatId}
  String _legacyMuteDocId({required String uid, required String chatId}) => '${uid}_$chatId';
  DocumentReference<Map<String, dynamic>> _legacyMutedRef({required String uid, required String chatId}) {
    return _db.collection('mutedChats').doc(_legacyMuteDocId(uid: uid, chatId: chatId));
  }

  Stream<bool> watchMuted({required String chatId}) {
    final uid = currentUid;
    if (uid == null) return const Stream<bool>.empty();

    return _mutedRef(uid: uid, chatId: chatId).snapshots().asyncMap((snap) async {
      final data = snap.data();
      final muted = data?['muted'];
      if (muted is bool) return muted;

      // Backward-compat fallback (read once).
      try {
        final legacy = await _legacyMutedRef(uid: uid, chatId: chatId).get();
        final legacyMuted = legacy.data()?['muted'];
        return legacyMuted is bool ? legacyMuted : false;
      } catch (_) {
        return false;
      }
    });
  }

  Future<bool> isMutedOnce({required String chatId}) async {
    final uid = currentUid;
    if (uid == null) return false;

    final snap = await _mutedRef(uid: uid, chatId: chatId).get();
    final muted = snap.data()?['muted'];
    if (muted is bool) return muted;

    // Backward-compat.
    try {
      final legacy = await _legacyMutedRef(uid: uid, chatId: chatId).get();
      final legacyMuted = legacy.data()?['muted'];
      return legacyMuted is bool ? legacyMuted : false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setMuted({required String chatId, required bool muted}) async {
    final uid = currentUid;
    if (uid == null) return;

    final payload = {
      'uid': uid,
      'chatId': chatId,
      'muted': muted,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Write to the new canonical location.
    await _mutedRef(uid: uid, chatId: chatId).set(payload, SetOptions(merge: true));

    // Best-effort: also write legacy doc so older builds keep working.
    try {
      await _legacyMutedRef(uid: uid, chatId: chatId).set(payload, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  /// Deletes a chat document AND its `messages` subcollection using a Cloud Function.
  ///
  /// mode:
  /// - 'purge': delete chat + messages
  /// - 'clear': delete chat + messages, then recreate the chat doc (keeps friendship intact)
  Future<void> deleteChatCascade({
    required String chatId,
    required String mode,
    bool allowFallback = true,
  }) async {
    final uid = currentUid;
    if (uid == null) return;

    final id = chatId.trim();
    if (id.isEmpty) return;

    final cleanedMode = mode.trim().isEmpty ? 'purge' : mode.trim();

    try {
      await _functions.httpsCallable('deleteChatCascade').call(<String, Object?>{
        'chatId': id,
        'mode': cleanedMode,
      });
      return;
    } catch (e) {
      if (!allowFallback) rethrow;
      // Fallback when Cloud Functions isn't deployed/available yet.
      // This won't delete messages (rules disallow client deletes) but prevents zombie chats in UI.
      try {
        await _db.collection('chats').doc(id).delete();
      } catch (_) {
        // ignore
      }
      if (cleanedMode == 'clear') {
        try {
          await ensureDmChatFromFriendship(chatId: id);
        } catch (_) {
          // ignore
        }
      }
    }
  }

  Future<void> purgeChat({required String chatId}) async {
    await deleteChatCascade(chatId: chatId, mode: 'purge', allowFallback: true);
  }

  Future<void> clearConversation({required String chatId}) async {
    await deleteChatCascade(chatId: chatId, mode: 'clear', allowFallback: true);
  }

  Future<void> purgeChatStrict({required String chatId}) async {
    await deleteChatCascade(chatId: chatId, mode: 'purge', allowFallback: false);
  }

  Future<void> clearConversationStrict({required String chatId}) async {
    await deleteChatCascade(chatId: chatId, mode: 'clear', allowFallback: false);
  }

  /// Ensures a DM chat document exists if friendship exists (prevents orphan/missing chats).
  ///
  /// Reads `friendships/{chatId}` and recreates `chats/{chatId}` if missing.
  Future<void> ensureDmChatFromFriendship({required String chatId}) async {
    final uid = currentUid;
    if (uid == null) return;
    final id = chatId.trim();
    if (id.isEmpty) return;

    final chatRef = _db.collection('chats').doc(id);
    final chatSnap = await chatRef.get();
    if (chatSnap.exists) return;

    final friendshipSnap = await _db.collection('friendships').doc(id).get();
    if (!friendshipSnap.exists) return;
    final f = friendshipSnap.data();
    if (f == null) return;
    final uidsRaw = f['uids'];
    if (uidsRaw is! List) return;
    final members = <String>[];
    for (final v in uidsRaw) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) members.add(s);
    }
    if (members.length != 2) return;
    if (!members.contains(uid)) return;

    // Use stored peer names/tags from friendship to avoid extra reads.
    final aUid = (f['aUid'] as String?)?.trim() ?? '';
    final bUid = (f['bUid'] as String?)?.trim() ?? '';
    if (aUid.isEmpty || bUid.isEmpty) return;

    final aName = (f['aName'] as String?)?.trim() ?? 'Usuario';
    final bName = (f['bName'] as String?)?.trim() ?? 'Usuario';
    final aTag = (f['aUniqueTag'] as String?)?.trim() ?? '';
    final bTag = (f['bUniqueTag'] as String?)?.trim() ?? '';

    await chatRef.set(
      {
        'members': members,
        'kind': 'dm',
        'names': {aUid: aName, bUid: bName},
        'uniqueTags': {aUid: aTag, bUid: bTag},
        'unreadCountByUser': {
          aUid: 0,
          bUid: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: false),
    );
  }
}
