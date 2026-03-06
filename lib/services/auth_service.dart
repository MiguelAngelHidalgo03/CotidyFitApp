import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

class AuthGoogleConfigurationException implements Exception {
  final String message;
  const AuthGoogleConfigurationException([
    this.message = 'Google Sign-In no está configurado correctamente.',
  ]);

  @override
  String toString() => message;
}

class AuthGoogleTransientException implements Exception {
  final String message;
  const AuthGoogleTransientException([
    this.message = 'Error temporal en Google Sign-In.',
  ]);

  @override
  String toString() => message;
}

class AuthPasskeyException implements Exception {
  final String message;
  const AuthPasskeyException([
    this.message = 'No se pudo usar tu passkey en este dispositivo.',
  ]);

  @override
  String toString() => message;
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
      try {
        return await _signInWithGoogleProviderPopup();
      } catch (e) {
        if (e is AuthCancelledException || e is AuthLinkRequiredException) rethrow;
        final s = e.toString();
        if (_looksLikePasskeyError(s)) {
          return await _signInWithGoogleProviderPopup(prompt: 'login');
        }
        rethrow;
      }
    }

    // Desktop platforms don't support the google_sign_in native flow reliably.
    // Use the Firebase provider flow directly.
    if (!_supportsNativeGoogleSignIn()) {
      try {
        return await _signInWithGoogleProviderFallback();
      } on FirebaseAuthException catch (e) {
        _throwLinkRequiredIfNeeded(e);
        rethrow;
      } catch (e) {
        if (e is AuthCancelledException || e is AuthLinkRequiredException) rethrow;
        final s = e.toString();
        if (_looksLikePasskeyError(s)) {
          try {
            return await _signInWithGoogleProviderFallback(prompt: 'login');
          } catch (forcedErr) {
            if (forcedErr is AuthCancelledException || forcedErr is AuthLinkRequiredException) rethrow;
            throw const AuthPasskeyException(
              'Tu passkey falló en este entorno (Windows/emulador). Prueba con contraseña o en un móvil real.',
            );
          }
        }
        if (_looksLikeGoogleConfigError(s)) {
          throw const AuthGoogleConfigurationException();
        }
        if (_looksLikeGoogleTransientError(s)) {
          throw const AuthGoogleTransientException();
        }
        rethrow;
      }
    }

    Object? nativeError;
    try {
      return await _signInWithGoogleNative();
    } on AuthCancelledException {
      rethrow;
    } on AuthLinkRequiredException {
      rethrow;
    } catch (e) {
      nativeError = e;
    }

    // If native sign-in fails, try a Firebase provider-based flow once.
    // This avoids repeating the same native account picker twice.
    try {
      return await _signInWithGoogleProviderFallback();
    } on FirebaseAuthException catch (e) {
      _throwLinkRequiredIfNeeded(e);
      rethrow;
    } catch (fallbackError) {
      final merged = '${nativeError.toString()} | ${fallbackError.toString()}';

      if (_looksLikePasskeyError(merged)) {
        try {
          return await _signInWithGoogleProviderFallback(prompt: 'login');
        } catch (_) {
          throw const AuthPasskeyException(
            'No se pudo usar tu passkey. En algunos dispositivos puede fallar: usa contraseña o prueba en otro móvil.',
          );
        }
      }

      if (_looksLikeGoogleConfigError(merged)) {
        throw const AuthGoogleConfigurationException();
      }
      if (_looksLikeGoogleTransientError(merged)) {
        throw const AuthGoogleTransientException();
      }

      if (nativeError is AuthGoogleConfigurationException) throw nativeError;
      if (nativeError is AuthGoogleTransientException) throw nativeError;
      if (nativeError is AuthPasskeyException) throw nativeError;
      rethrow;
    }
  }

  bool _supportsNativeGoogleSignIn() {
    // google_sign_in supports Android/iOS (and web via kIsWeb). For desktop
    // targets, prefer Firebase provider auth flows.
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
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

  Future<UserCredential> _signInWithGoogleProviderPopup({String prompt = 'select_account'}) async {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': prompt});
    late final UserCredential cred;
    try {
      cred = await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      _throwLinkRequiredIfNeeded(e);
      rethrow;
    }
    await _ensureDisplayNameFromEmail(cred.user);
    return cred;
  }

  Future<UserCredential> _signInWithGoogleProviderFallback({String prompt = 'select_account'}) async {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': prompt});
    final cred = await _auth.signInWithProvider(provider);
    await _ensureDisplayNameFromEmail(cred.user);
    return cred;
  }

  Future<UserCredential> _signInWithGoogleNative() async {
    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      _throwMappedGoogleSignInPlatformException(e);
    }
    if (account == null) throw const AuthCancelledException();

    late final GoogleSignInAuthentication auth;
    try {
      auth = await account.authentication;
    } on PlatformException catch (e) {
      _throwMappedGoogleSignInPlatformException(e);
    } catch (e) {
      final s = e.toString();
      if (_looksLikeGoogleConfigError(s)) throw const AuthGoogleConfigurationException();
      if (_looksLikeGoogleTransientError(s)) throw const AuthGoogleTransientException();
      rethrow;
    }
    final accessToken = auth.accessToken;
    final idToken = auth.idToken;
    if ((accessToken == null || accessToken.isEmpty) && (idToken == null || idToken.isEmpty)) {
      throw const AuthGoogleConfigurationException('Google devolvió tokens vacíos.');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    try {
      final cred = await _auth.signInWithCredential(credential);
      await _ensureDisplayNameFromEmail(cred.user);
      return cred;
    } on FirebaseAuthException catch (e) {
      _throwLinkRequiredIfNeeded(e);
      rethrow;
    }
  }

  Never _throwMappedGoogleSignInPlatformException(PlatformException e) {
    final combined = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.trim();
    if (_looksLikeGoogleCancelledError(combined)) {
      throw const AuthCancelledException();
    }
    if (_looksLikeGoogleConfigError(combined)) {
      throw const AuthGoogleConfigurationException();
    }
    if (_looksLikeGoogleTransientError(combined)) {
      throw const AuthGoogleTransientException();
    }
    throw e;
  }

  void _throwLinkRequiredIfNeeded(FirebaseAuthException e) {
    if (e.code == 'account-exists-with-different-credential' &&
        (e.email ?? '').trim().isNotEmpty &&
        e.credential != null) {
      throw AuthLinkRequiredException(
        email: e.email!.trim(),
        pendingCredential: e.credential!,
      );
    }
  }

  bool _looksLikeGoogleConfigError(String input) {
    final s = input.toLowerCase();
    final code = _extractGoogleApiExceptionCode(s);
    if (code == 10 || code == 16 || code == 17 || code == 12500) return true;
    return s.contains('apiexception: 10') ||
        s.contains('apiexception:10') ||
        s.contains('api exception: 10') ||
        s.contains('developer_error') ||
        s.contains('12500') ||
        s.contains('invalid_audience') ||
        s.contains('sha-1') ||
        s.contains('sha1') ||
        s.contains('google-services.json');
  }

  bool _looksLikeGoogleTransientError(String input) {
    final s = input.toLowerCase();
    final code = _extractGoogleApiExceptionCode(s);
    if (code == 7 || code == 8 || code == 12502) return true;
    return s.contains('network_error') ||
        s.contains('network request failed') ||
        s.contains('timeout') ||
        s.contains('temporarily unavailable') ||
        s.contains('service unavailable') ||
        s.contains('api exception: 7');
  }

  bool _looksLikeGoogleCancelledError(String input) {
    final s = input.toLowerCase();
    final code = _extractGoogleApiExceptionCode(s);
    if (code == 12501) return true;
    return s.contains('sign_in_canceled') ||
        s.contains('sign_in_cancelled') ||
        s.contains('12501') ||
        s.contains('canceled') ||
        s.contains('cancelled');
  }

  int? _extractGoogleApiExceptionCode(String input) {
    final s = input.toLowerCase();
    final m = RegExp(r'(?:api\s*exception|apiexception)\s*:\s*(\d+)').firstMatch(s);
    if (m != null) return int.tryParse(m.group(1) ?? '');
    final m2 = RegExp(r'\b(12500|12501|12502)\b').firstMatch(s);
    if (m2 != null) return int.tryParse(m2.group(1) ?? '');
    return null;
  }

  bool _looksLikePasskeyError(String input) {
    final s = input.toLowerCase();
    return s.contains('passkey') ||
        s.contains('webauthn') ||
        s.contains('publickeycredential') ||
        s.contains('windows security') ||
        s.contains('securityerror');
  }

  Future<void> _ensureDisplayNameFromEmail(User? user) async {
    if (user == null) return;
    if ((user.displayName ?? '').trim().isNotEmpty) return;

    final derived = _deriveNameFromEmail((user.email ?? '').trim());
    if (derived.isEmpty) return;
    try {
      await user.updateDisplayName(derived);
      await user.reload();
    } catch (_) {}
  }
}
