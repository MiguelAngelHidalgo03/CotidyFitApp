import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'profile_service.dart';

class OnboardingService {
  final ProfileService _profile;
  AuthService? _auth;
  FirestoreService? _firestore;

  OnboardingService({
    ProfileService? profile,
    AuthService? auth,
    FirestoreService? firestore,
  })  : _profile = profile ?? ProfileService(),
        _auth = auth,
        _firestore = firestore;

  AuthService? _authOrNull() {
    if (Firebase.apps.isEmpty) return null;
    return _auth ??= AuthService();
  }

  FirestoreService? _firestoreOrNull() {
    if (Firebase.apps.isEmpty) return null;
    return _firestore ??= FirestoreService();
  }

  Future<UserProfile> getOrCreateLocalProfile() {
    return _profile.getOrCreateProfile(fallbackGoal: 'Salud');
  }

  Future<void> saveLocalProfile(UserProfile profile) {
    return _profile.saveProfile(profile);
  }

  Future<void> syncSignedInUserToFirestore() async {
    final auth = _authOrNull();
    if (auth == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    final fs = _firestoreOrNull();
    if (fs == null) return;

    final local = await getOrCreateLocalProfile();
    await fs.upsertUser(
      uid: user.uid,
      email: user.email,
      profile: local,
    );
  }

  Future<void> syncProfileToFirestore(UserProfile profile) async {
    final auth = _authOrNull();
    if (auth == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    final fs = _firestoreOrNull();
    if (fs == null) return;

    await fs.upsertUser(
      uid: user.uid,
      email: user.email,
      profile: profile,
    );
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final completed = profile.onboardingCompleted ? profile : profile.copyWith(onboardingCompleted: true);
    await saveLocalProfile(completed);
    await syncProfileToFirestore(completed);
  }

  /// Utility for cases where a Firebase user is already available.
  Future<void> syncUserToFirestore(User user) async {
    final fs = _firestoreOrNull();
    if (fs == null) return;
    final local = await getOrCreateLocalProfile();
    await fs.upsertUser(uid: user.uid, email: user.email, profile: local);
  }
}
