import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'tag_generator.dart';

class PublicUser {
  final String uid;
  final String displayName;
  final String uniqueTag;
  final bool visible;
  final int? lastActiveAtMs;

  const PublicUser({
    required this.uid,
    required this.displayName,
    required this.uniqueTag,
    required this.visible,
    required this.lastActiveAtMs,
  });

  static PublicUser? fromFirestore(String uid, Map<String, Object?> data) {
    final displayName = (data['displayName'] as String?)?.trim() ?? '';
    final uniqueTag = (data['uniqueTag'] as String?)?.trim() ?? '';
    final visible = (data['visible'] as bool?) ?? true;
    final ts = data['lastActiveAt'];
    int? ms;
    if (ts is Timestamp) ms = ts.millisecondsSinceEpoch;

    if (displayName.isEmpty) return null;

    return PublicUser(
      uid: uid,
      displayName: displayName,
      uniqueTag: uniqueTag,
      visible: visible,
      lastActiveAtMs: ms,
    );
  }
}

class FriendRequestModel {
  final String id;
  final List<String> uids;
  final String requesterUid;
  final String addresseeUid;
  final String status; // pending | accepted | rejected
  final int updatedAtMs;

  const FriendRequestModel({
    required this.id,
    required this.uids,
    required this.requesterUid,
    required this.addresseeUid,
    required this.status,
    required this.updatedAtMs,
  });

  bool get isPending => status == 'pending';

  static FriendRequestModel? fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return null;
    final uidsRaw = data['uids'];
    final requesterUid = (data['requesterUid'] as String?)?.trim() ?? '';
    final addresseeUid = (data['addresseeUid'] as String?)?.trim() ?? '';
    final status = (data['status'] as String?)?.trim() ?? 'pending';

    if (uidsRaw is! List) return null;
    final uids = <String>[];
    for (final v in uidsRaw) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) uids.add(s);
    }
    if (uids.length != 2) return null;

    final updatedAt = data['updatedAt'];
    final updatedAtMs = updatedAt is Timestamp ? updatedAt.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;

    return FriendRequestModel(
      id: snap.id,
      uids: uids,
      requesterUid: requesterUid,
      addresseeUid: addresseeUid,
      status: status,
      updatedAtMs: updatedAtMs,
    );
  }
}

class SocialFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  SocialFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  static String pairIdFor(String uidA, String uidB) {
    final a = uidA.trim();
    final b = uidB.trim();
    if (a.compareTo(b) <= 0) return '${a}_$b';
    return '${b}_$a';
  }

  Future<void> pingPresence() async {
    final uid = currentUid;
    if (uid == null) return;
    await _db.collection('user_public').doc(uid).set(
      {
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> resolveUidByUniqueTag(String uniqueTag) async {
    final parts = TagGenerator.splitFullTagInput(uniqueTag);
    if (parts == null) return null;
    final usernameNormalized = TagGenerator.normalize(parts.usernamePart);
    final searchableTag = TagGenerator.buildSearchableTag(
      usernameNormalized: usernameNormalized,
      tag: parts.tag,
    );
    DocumentSnapshot<Map<String, dynamic>> snap = await _db.collection('user_tags').doc(searchableTag).get();
    Map<String, dynamic>? data = snap.data();

    if (data == null) {
      final legacy = TagGenerator.buildLegacySearchableTag(
        usernamePart: parts.usernamePart,
        tag: parts.tag,
      );
      snap = await _db.collection('user_tags').doc(legacy).get();
      data = snap.data();
    }

    final uid = (data?['uid'] as String?)?.trim();
    return uid != null && uid.isNotEmpty ? uid : null;
  }

  Future<PublicUser?> findPublicUserByUsername(String username) async {
    final uid = currentUid;
    if (uid == null) return null;

    final q = TagGenerator.normalize(username);
    if (q.trim().isEmpty) return null;

    final qs = await _db
        .collection('user_public')
      .where('usernameNormalized', isEqualTo: q)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;
    final doc = qs.docs.first;
    final data = doc.data();
    final map = <String, Object?>{};
    data.forEach((k, v) => map[k] = v);
    final user = PublicUser.fromFirestore(doc.id, map);
    if (user == null) return null;
    if (user.visible == false) return null;
    return user;
  }

  Future<PublicUser?> getPublicUser(String uid) async {
    final snap = await _db.collection('user_public').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    final map = <String, Object?>{};
    data.forEach((k, v) => map[k] = v);
    return PublicUser.fromFirestore(uid, map);
  }

  Stream<List<ChatModel>> watchDmChats() {
    final uid = currentUid;
    if (uid == null) return const Stream<List<ChatModel>>.empty();

    return _db
      .collection('chats')
      .where('members', arrayContains: uid)
      .snapshots()
      .map((qs) {
      final out = <ChatModel>[];
      for (final doc in qs.docs) {
        final data = doc.data();
        final membersRaw = data['members'];
        if (membersRaw is! List) continue;
        final members = membersRaw.map((e) => e.toString()).toList();
        if (members.length != 2) continue;
        final peerUid = members.firstWhere((m) => m != uid, orElse: () => '');

        final namesRaw = data['names'];
        final names = namesRaw is Map ? namesRaw.map((k, v) => MapEntry(k.toString(), v)) : const <String, Object?>{};
        final peerName = (names[peerUid] as String?)?.trim() ?? 'Chat';
        final updatedAt = data['updatedAt'];
        final updatedAtMs = updatedAt is Timestamp ? updatedAt.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;

        final last = data['lastMessage'];
        final lastMessage = _messageFromLastMessageMap(
          chatId: doc.id,
          myUid: uid,
          map: last is Map ? last.map((k, v) => MapEntry(k.toString(), v)) : null,
        );

        final unreadRaw = data['unreadCountByUser'];
        int unread = 0;
        if (unreadRaw is Map) {
          final v = unreadRaw[uid];
          if (v is int) unread = v;
          if (v is num) unread = v.toInt();
          if (v is String) unread = int.tryParse(v) ?? 0;
        }

        out.add(
          ChatModel(
            id: doc.id,
            type: ChatType.amigo,
            title: peerName,
            avatarKey: peerUid.isEmpty ? peerName : peerUid,
            readOnly: false,
            unreadCount: unread.clamp(0, 999),
            updatedAtMs: updatedAtMs,
            messages: lastMessage == null ? const [] : [lastMessage],
          ),
        );
      }
      out.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return out;
    });
  }

  /// Resets my unread counter for a chat (WhatsApp-style).
  ///
  /// Storage: chats/{chatId}.unreadCountByUser.{uid} = 0
  Future<void> resetUnreadCount({required String chatId}) async {
    final uid = currentUid;
    if (uid == null) return;
    final id = chatId.trim();
    if (id.isEmpty) return;

    try {
      await _db.collection('chats').doc(id).set(
        {
          'unreadCountByUser.$uid': 0,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore
    }
  }

  Stream<List<MessageModel>> watchMessages({required String chatId}) {
    final uid = currentUid;
    if (uid == null) return const Stream<List<MessageModel>>.empty();

    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map((qs) {
      final out = <MessageModel>[];
      for (final doc in qs.docs) {
        final data = doc.data();
        final senderUid = (data['senderUid'] as String?)?.trim() ?? '';
        final senderName = (data['senderName'] as String?)?.trim() ?? 'Usuario';
        final text = (data['text'] as String?) ?? '';
        final typeRaw = (data['type'] as String?)?.trim();

        MessageType type = MessageType.text;
        for (final v in MessageType.values) {
          if (v.name == typeRaw) {
            type = v;
            break;
          }
        }

        final createdAt = data['createdAt'];
        final createdAtMs = createdAt is Timestamp ? createdAt.millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;

        out.add(
          MessageModel(
            id: doc.id,
            chatId: chatId,
            senderId: senderUid,
            senderName: senderName,
            isMine: senderUid == uid,
            type: type,
            text: text,
            createdAtMs: createdAtMs,
          ),
        );
      }
      return out;
    });
  }

  Future<void> sendMessage({
    required String chatId,
    required MessageType type,
    required String text,
  }) async {
    final uid = currentUid;
    final user = _auth.currentUser;
    if (uid == null || user == null) return;

    final senderName = (user.displayName ?? '').trim().isEmpty
        ? ((user.email ?? '').split('@').first)
        : (user.displayName ?? '');

    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final payload = {
      'senderUid': uid,
      'senderName': senderName.trim().isEmpty ? 'Usuario' : senderName.trim(),
      'type': type.name,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      tx.set(msgRef, payload);
      tx.set(
        chatRef,
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': {
            'senderUid': uid,
            'senderName': senderName.trim().isEmpty ? 'Usuario' : senderName.trim(),
            'type': type.name,
            'text': text.trim(),
            'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          },
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> sendFriendRequest({required String targetUid}) async {
    final uid = currentUid;
    if (uid == null) return;
    if (targetUid.trim().isEmpty || targetUid == uid) return;

    final pairId = pairIdFor(uid, targetUid);
    final uids = [uid, targetUid]..sort();

    try {
      await _db.collection('friend_requests').doc(pairId).set(
        {
          'uids': uids,
          'requesterUid': uid,
          'addresseeUid': targetUid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: false),
      );
    } catch (_) {
      // already exists or blocked by rules
    }
  }

  Stream<List<FriendRequestModel>> watchPendingFriendRequests() {
    final uid = currentUid;
    if (uid == null) return const Stream<List<FriendRequestModel>>.empty();

    return _db
        .collection('friend_requests')
        .where('uids', arrayContains: uid)
        .snapshots()
        .map((qs) {
      final out = <FriendRequestModel>[];
      for (final doc in qs.docs) {
        final m = FriendRequestModel.fromSnap(doc);
        if (m != null && m.status == 'pending') out.add(m);
      }
      out.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return out;
    });
  }

  Stream<List<PublicUser>> watchFriends() {
    final uid = currentUid;
    if (uid == null) return const Stream<List<PublicUser>>.empty();

    return _db
      .collection('friendships')
      .where('uids', arrayContains: uid)
      .snapshots()
      .map((qs) {
      final out = <PublicUser>[];
      for (final doc in qs.docs) {
        final data = doc.data();
        final aUid = (data['aUid'] as String?)?.trim() ?? '';
        final bUid = (data['bUid'] as String?)?.trim() ?? '';
        final peerUid = aUid == uid ? bUid : aUid;

        final peerName = (data[uid == aUid ? 'bName' : 'aName'] as String?)?.trim() ?? '';
        final peerTag = (data[uid == aUid ? 'bUniqueTag' : 'aUniqueTag'] as String?)?.trim() ?? '';

        if (peerUid.isEmpty || peerName.isEmpty) continue;
        out.add(PublicUser(uid: peerUid, displayName: peerName, uniqueTag: peerTag, visible: true, lastActiveAtMs: null));
      }
      out.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return out;
    });
  }

  Future<void> acceptFriendRequest(FriendRequestModel req) async {
    final uid = currentUid;
    if (uid == null) return;
    if (req.addresseeUid != uid) return;

    final a = req.uids.first;
    final b = req.uids.last;

    final aPublic = await getPublicUser(a);
    final bPublic = await getPublicUser(b);

    final reqRef = _db.collection('friend_requests').doc(req.id);
    final friendshipRef = _db.collection('friendships').doc(req.id);
    final chatRef = _db.collection('chats').doc(req.id);

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(reqRef);
      final data = fresh.data();
      final status = (data?['status'] as String?)?.trim() ?? 'pending';
      if (status != 'pending') return;

      // Delete the request doc to avoid zombie state blocking future requests.
      tx.delete(reqRef);

      tx.set(
        friendshipRef,
        {
          'uids': req.uids,
          'aUid': a,
          'bUid': b,
          'aName': aPublic?.displayName ?? 'Usuario',
          'bName': bPublic?.displayName ?? 'Usuario',
          'aUniqueTag': aPublic?.uniqueTag ?? '',
          'bUniqueTag': bPublic?.uniqueTag ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: false),
      );

      tx.set(
        chatRef,
        {
          'members': req.uids,
          'kind': 'dm',
          'names': {
            a: aPublic?.displayName ?? 'Usuario',
            b: bPublic?.displayName ?? 'Usuario',
          },
          'uniqueTags': {
            a: aPublic?.uniqueTag ?? '',
            b: bPublic?.uniqueTag ?? '',
          },
          'unreadCountByUser': {
            a: 0,
            b: 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> rejectFriendRequest(FriendRequestModel req) async {
    final uid = currentUid;
    if (uid == null) return;
    if (req.addresseeUid != uid) return;

    // Delete to allow future requests without conflicts.
    try {
      await _db.collection('friend_requests').doc(req.id).delete();
    } catch (_) {
      // ignore
    }
  }

  MessageModel? _messageFromLastMessageMap({
    required String chatId,
    required String myUid,
    required Map<String, Object?>? map,
  }) {
    if (map == null) return null;

    final senderUid = (map['senderUid'] as String?)?.trim() ?? '';
    final senderName = (map['senderName'] as String?)?.trim() ?? 'Usuario';
    final typeRaw = (map['type'] as String?)?.trim();
    final text = (map['text'] as String?) ?? '';
    final createdAtMs = map['createdAtMs'] is int ? map['createdAtMs'] as int : DateTime.now().millisecondsSinceEpoch;

    MessageType type = MessageType.text;
    for (final v in MessageType.values) {
      if (v.name == typeRaw) {
        type = v;
        break;
      }
    }

    return MessageModel(
      id: 'last',
      chatId: chatId,
      senderId: senderUid,
      senderName: senderName,
      isMine: senderUid == myUid,
      type: type,
      text: text,
      createdAtMs: createdAtMs,
    );
  }
}
