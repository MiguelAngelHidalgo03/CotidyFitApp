import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class CommunityGroupMuteService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  CommunityGroupMuteService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _ref({
    required String uid,
    required String groupId,
  }) {
    final id = groupId.trim();
    return _db
        .collection('users')
        .doc(uid)
        .collection('mutedCommunityGroups')
        .doc(id);
  }

  static DateTime? muteUntilFromDocData(Map<String, dynamic>? data) {
    final ts = data?['muteUntil'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  static bool isMuted(DateTime? until) {
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<void> setMuteUntil({
    required String groupId,
    required DateTime? until,
  }) async {
    final uid = currentUid;
    if (uid == null) return;

    final gid = groupId.trim();
    if (gid.isEmpty) return;

    final ref = _ref(uid: uid, groupId: gid);

    if (until == null) {
      try {
        await ref.delete();
      } catch (_) {
        // Best-effort fallback.
        await ref.set({
          'muteUntil': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      return;
    }

    await ref.set({
      'uid': uid,
      'groupId': gid,
      'muteUntil': Timestamp.fromDate(until),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
