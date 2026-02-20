import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthCancelledException implements Exception {
  final String message;
  const AuthCancelledException([this.message = 'Auth cancelled']);

  @override
  String toString() => message;
}

class AuthLinkRequiredException implements Exception {
  final String email;
  final AuthCredential pendingCredential;

  const AuthLinkRequiredException({
    required this.email,
    required this.pendingCredential,
  });

  @override
  String toString() => 'Link required for $email';
}

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cred = await _auth.createUserWithEmailAndPassword(email: cleanEmail, password: password);

    final user = cred.user;
    final derived = _deriveNameFromEmail(cleanEmail);
    if (user != null && (user.displayName ?? '').trim().isEmpty && derived.isNotEmpty) {
      try {
        await user.updateDisplayName(derived);
        await user.reload();
      } catch (_) {
        // Ignore; user doc will still be normalized on bootstrap.
      }
    }

    return cred;
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    // Ensures Firebase Auth emails are localized.
    _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web uses a Firebase Auth popup/redirect flow.
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      late final UserCredential cred;
      try {
        cred = await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential' &&
            (e.email ?? '').trim().isNotEmpty &&
            e.credential != null) {
          throw AuthLinkRequiredException(
            email: e.email!.trim(),
            pendingCredential: e.credential!,
          );
        }
        rethrow;
      }

      final user = cred.user;
      if (user != null && (user.displayName ?? '').trim().isEmpty) {
        final derived = _deriveNameFromEmail((user.email ?? '').trim());
        if (derived.isNotEmpty) {
          try {
            await user.updateDisplayName(derived);
            await user.reload();
          } catch (_) {}
        }
      }

      return cred;
    }

    // Android/iOS use google_sign_in.
    final account = await _googleSignIn.signIn();
    if (account == null) throw const AuthCancelledException();

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    late final UserCredential cred;
    try {
      cred = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' &&
          (e.email ?? '').trim().isNotEmpty &&
          e.credential != null) {
        throw AuthLinkRequiredException(
          email: e.email!.trim(),
          pendingCredential: e.credential!,
        );
      }
      rethrow;
    }
    final user = cred.user;
    if (user != null && (user.displayName ?? '').trim().isEmpty) {
      final derived = _deriveNameFromEmail((user.email ?? '').trim());
      if (derived.isNotEmpty) {
        try {
          await user.updateDisplayName(derived);
          await user.reload();
        } catch (_) {}
      }
    }

    return cred;
  }

  Future<UserCredential> signInWithPasswordForLink({
    required String email,
    required String password,
  }) {
    return signInWithEmailPassword(email: email, password: password);
  }

  Future<void> linkWithCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to link credential');
    }
    await user.linkWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if Google sign out is not available on this platform.
    }
  }

  String _deriveNameFromEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '';
    return email.substring(0, at).trim();
  }
}
