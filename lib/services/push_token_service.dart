import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushTokenService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  PushTokenService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseMessaging? messaging,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  Future<void> registerCurrentDeviceToken() async {
    // Web push requires extra setup (service worker + VAPID key). If not configured,
    // firebase_messaging_web can throw noisy engine assertions.
    if (kIsWeb) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // iOS permissions (no-op elsewhere)
      await _messaging.requestPermission();
    } catch (_) {
      // best-effort
    }

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (_) {
      token = null;
    }

    if (token == null || token.trim().isEmpty) return;

    final uid = user.uid;
    final platform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        TargetPlatform.macOS => 'macos',
        TargetPlatform.windows => 'windows',
        TargetPlatform.linux => 'linux',
        TargetPlatform.fuchsia => 'fuchsia',
        };

    final ref = _db.collection('users').doc(uid).collection('tokens').doc(token);
    await ref.set(
      {
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Keep token updated if it refreshes (best-effort, never throw unhandled).
    _messaging.onTokenRefresh.listen(
      (t) async {
        try {
          if (t.trim().isEmpty) return;
          final r = _db.collection('users').doc(uid).collection('tokens').doc(t);
          await r.set(
            {
              'token': t,
              'platform': platform,
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {
          // best-effort
        }
      },
      onError: (Object error, StackTrace stack) {
        // best-effort
      },
    );
  }
}
