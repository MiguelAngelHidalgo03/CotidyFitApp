import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class MuteService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  MuteService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  static DateTime? muteUntilFromChatData({required Map<String, dynamic>? data, required String uid}) {
    if (data == null) return null;

    // Preferred: per-user mute
    final byUserRaw = data['muteUntilByUser'];
    if (byUserRaw is Map) {
      final ts = byUserRaw[uid];
      if (ts is Timestamp) return ts.toDate();
    }

    // Back-compat: global mute
    final global = data['muteUntil'];
    if (global is Timestamp) return global.toDate();

    return null;
  }

  static bool isMuted(DateTime? until) {
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<void> setMuteUntil({required String chatId, required DateTime? until}) async {
    final uid = currentUid;
    if (uid == null) return;

    final id = chatId.trim();
    if (id.isEmpty) return;

    final ref = _db.collection('chats').doc(id);

    if (until == null) {
      await ref.set(
        {
          'muteUntilByUser.$uid': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    await ref.set(
      {
        'muteUntilByUser.$uid': Timestamp.fromDate(until),
      },
      SetOptions(merge: true),
    );
  }
}
