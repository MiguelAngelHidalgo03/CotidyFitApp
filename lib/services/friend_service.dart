import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'social_firestore_service.dart';
import 'tag_generator.dart';
import 'chat_service.dart';

enum SendFriendRequestResult {
  created,
  alreadyFriends,
  alreadyPendingSent,
  alreadyPendingReceived,
  alreadyExists,
}

class FriendService {
  FriendService({FirebaseFirestore? db, ChatService? chatService})
      : _dbOverride = db,
        _chatService = chatService ?? ChatService(db: db);

  final FirebaseFirestore? _dbOverride;
  final ChatService _chatService;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Sends a friend request only if there is no prior relationship.
  ///
  /// Checks (in order):
  /// - existing friendship
  /// - existing friend request (pending outgoing)
  /// - existing friend request (pending incoming)
  ///
  /// Returns a result to show the correct UX message.
  Future<SendFriendRequestResult> sendFriendRequestSafely({
    required String myUid,
    required String targetUid,
  }) async {
    if (Firebase.apps.isEmpty) return SendFriendRequestResult.alreadyExists;

    final me = myUid.trim();
    final other = targetUid.trim();
    if (me.isEmpty || other.isEmpty || me == other) {
      return SendFriendRequestResult.alreadyExists;
    }

    final pairId = SocialFirestoreService.pairIdFor(me, other);

    // 1) Already friends?
    try {
      final friendshipSnap = await _db.collection('friendships').doc(pairId).get();
      if (friendshipSnap.exists) return SendFriendRequestResult.alreadyFriends;
    } on FirebaseException catch (e) {
      // Some rule sets deny `get` on missing docs; treat as not friends.
      if (e.code != 'permission-denied') rethrow;
    }

    // 2) Any existing request?
    final reqRef = _db.collection('friend_requests').doc(pairId);
    Map<String, dynamic>? data;
    try {
      final reqSnap = await reqRef.get();
      data = reqSnap.data();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      data = null;
    }
    if (data != null) {
      final status = (data['status'] as String?)?.trim() ?? 'pending';
      final requesterUid = (data['requesterUid'] as String?)?.trim() ?? '';
      final addresseeUid = (data['addresseeUid'] as String?)?.trim() ?? '';
      if (status == 'pending') {
        if (requesterUid == me && addresseeUid == other) {
          return SendFriendRequestResult.alreadyPendingSent;
        }
        if (requesterUid == other && addresseeUid == me) {
          return SendFriendRequestResult.alreadyPendingReceived;
        }
        return SendFriendRequestResult.alreadyExists;
      }

      // Stale request (accepted/rejected/unknown): remove it so new requests can be created.
      try {
        await reqRef.delete();
      } on FirebaseException {
        return SendFriendRequestResult.alreadyExists;
      }
    }

    final uids = [me, other]..sort();

    try {
      await reqRef.set(
        {
          'uids': uids,
          'requesterUid': me,
          'addresseeUid': other,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: false),
      );
      return SendFriendRequestResult.created;
    } on FirebaseException catch (e) {
      // Surface rules issues for better UX (e.g. blocked-by-other => permission-denied).
      if (e.code == 'permission-denied') rethrow;
      return SendFriendRequestResult.alreadyExists;
    }
  }

  /// Finds a public user by full tag input (username#123456), case-insensitive.
  ///
  /// Requirements:
  /// - Only accepts full tag format containing '#'
  /// - Normalizes only the username part and searches by exact match on `searchableTag`
  Future<PublicUser?> findPublicUserByFullTag(String input) async {
    if (Firebase.apps.isEmpty) return null;

    final db = _db;

    final raw = input.trim();
    final parts = TagGenerator.splitFullTagInput(raw);
    if (parts == null) {
      throw const FormatException(
        'Para añadir a un amigo necesitas su nombre completo y tag único. Ejemplo: miguel#482913',
      );
    }

    final usernameNormalized = TagGenerator.normalize(parts.usernamePart);
    final searchable = TagGenerator.buildSearchableTag(
      usernameNormalized: usernameNormalized,
      tag: parts.tag,
    );

    // Read the tag reservation doc directly. This avoids Firestore query permission failures.
    DocumentSnapshot<Map<String, dynamic>> tagSnap = await db.collection('user_tags').doc(searchable).get();
    Map<String, dynamic>? tagData = tagSnap.data();

    // Back-compat: older identities used a different doc id scheme.
    if (tagData == null) {
      final legacy = TagGenerator.buildLegacySearchableTag(
        usernamePart: parts.usernamePart,
        tag: parts.tag,
      );
      tagSnap = await db.collection('user_tags').doc(legacy).get();
      tagData = tagSnap.data();
    }

    final uid = (tagData?['uid'] as String?)?.trim() ?? '';
    if (uid.isEmpty) return null;

    try {
      final pubSnap = await db.collection('user_public').doc(uid).get();
      final data = pubSnap.data();
      if (data == null) return null;
      final map = <String, Object?>{};
      data.forEach((k, v) => map[k] = v);
      final user = PublicUser.fromFirestore(uid, map);
      if (user == null) return null;
      if (user.visible == false) return null;
      return user;
    } on FirebaseException catch (e) {
      // If the user is hidden (visible=false) rules may deny reading their public doc.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Removes friendship. Optionally purges the conversation (chat doc + messages).
  ///
  /// If [deleteConversation] is false, the chat doc remains but messages sending will be prevented
  /// by rules because messages require an existing friendship.
  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
    required bool deleteConversation,
  }) async {
    if (Firebase.apps.isEmpty) return;

    final me = myUid.trim();
    final other = friendUid.trim();
    if (me.isEmpty || other.isEmpty || me == other) return;

    final pairId = SocialFirestoreService.pairIdFor(me, other);

    // Always remove friendship and any existing request artifact.
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

    if (deleteConversation) {
      await _chatService.purgeChatStrict(chatId: pairId);
    }
  }

  /// Removes friendship and related social artifacts for a pair.
  ///
  /// Best-effort deletes:
  /// - friendships/{pairId}
  /// - friend_requests/{pairId}
  /// - chats/{pairId}
  ///
  /// Note: deleting messages subcollection is not possible from the client.
  Future<void> removeFriendshipAndChat({
    required String myUid,
    required String friendUid,
  }) async {
    await removeFriend(
      myUid: myUid,
      friendUid: friendUid,
      deleteConversation: true,
    );
  }
}
