import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ReportService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  ReportService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final reported = reportedUserId.trim();
    if (reported.isEmpty || reported == uid) return;

    final cleanedReason = reason.trim();
    if (cleanedReason.isEmpty) {
      throw const FormatException('Indica un motivo');
    }

    await _db.collection('reports').add({
      'reportedUserId': reported,
      'reportedBy': uid,
      'reason': cleanedReason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
