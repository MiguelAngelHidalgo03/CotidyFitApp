import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'firestore_service.dart';
import 'profile_service.dart';
import 'user_service.dart';

class UserRepository {
  UserRepository({
    FirestoreService? firestore,
    ProfileService? profile,
    UserService? userService,
  })  : _firestore = firestore ?? FirestoreService(),
        _profile = profile ?? ProfileService(),
        _userService = userService ?? UserService();

  final FirestoreService _firestore;
  final ProfileService _profile;
  final UserService _userService;

  Future<UserProfile> getOrCreateLocalProfile() {
    return _profile.getOrCreateProfile(fallbackGoal: 'Salud');
  }

  Future<void> saveLocalProfile(UserProfile profile) {
    return _profile.saveProfile(profile);
  }

  /// Bootstraps local + remote user state and returns whether onboarding is completed.
  ///
  /// Rules:
  /// - Reads `users/{uid}` and uses its `onboardingCompleted` as the source of truth.
  /// - Ensures `displayName` is present (email prefix fallback) and persists it.
  /// - If Firestore has `profileData`, it is saved locally.
  /// - If Firestore doc is missing, it is created from local profile.
  Future<bool> bootstrapSignedInUser(User user) async {
    final uid = user.uid;

    final email = (user.email ?? '').trim();
    final derivedName = _deriveDisplayName(
      email: email,
      firebaseDisplayName: user.displayName,
    );

    // Ensure FirebaseAuth displayName is set (best-effort).
    if ((user.displayName ?? '').trim().isEmpty && derivedName.trim().isNotEmpty) {
      try {
        await user.updateDisplayName(derivedName);
        await user.reload();
      } catch (_) {
        // Ignore; still persist to Firestore/local.
      }
    }

    final docRef = _firestore.userDoc(uid);
    final snap = await docRef.get();

    // Ensure username/tag exists (best-effort) without overwriting.
    await ensureUniqueTagForUser(user);

    // Best-effort: keep a public profile doc for Community (no sensitive fields).
    await _upsertPublicProfile(uid: uid, displayName: derivedName);

    if (!snap.exists) {
      final local = await getOrCreateLocalProfile();
      final normalized = _applyDisplayNameToProfile(local, derivedName);
      await saveLocalProfile(normalized);

      await docRef.set(
        {
          if (email.isNotEmpty) 'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'onboardingCompleted': normalized.onboardingCompleted,
          'isPremium': normalized.isPremium,
          'profileData': normalized.toJson(),
          'healthConditions': normalized.healthConditions,
        },
        SetOptions(merge: true),
      );

      return normalized.onboardingCompleted;
    }

    final data = snap.data();
    if (data == null) {
      // Should be rare; fall back to local.
      final local = await getOrCreateLocalProfile();
      return local.onboardingCompleted;
    }

    final onboardingCompletedRaw = data['onboardingCompleted'];
    final onboardingCompleted = onboardingCompletedRaw is bool ? onboardingCompletedRaw : false;

    // Prefer remote profileData if present.
    final profileDataRaw = data['profileData'];
    UserProfile? remoteProfile;
    if (profileDataRaw is Map) {
      final map = <String, Object?>{};
      for (final e in profileDataRaw.entries) {
        map[e.key.toString()] = e.value;
      }
      remoteProfile = UserProfile.fromJson(map);
    }

    final local = await getOrCreateLocalProfile();

    final effective = (remoteProfile ?? local).copyWith(
      onboardingCompleted: onboardingCompleted,
    );

    final normalized = _applyDisplayNameToProfile(effective, derivedName);

    // Keep local in sync.
    await saveLocalProfile(normalized);

    // Best-effort: persist updated displayName/profile + timestamps.
    await docRef.set(
      {
        if (email.isNotEmpty) 'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
        'onboardingCompleted': normalized.onboardingCompleted,
        'isPremium': normalized.isPremium,
        'profileData': normalized.toJson(),
        'healthConditions': normalized.healthConditions,
      },
      SetOptions(merge: true),
    );

    return onboardingCompleted;
  }

  /// Ensures the signed-in user has `username`, `tag` and `uniqueTag`.
  ///
  /// Stored at `users/{uid}`:
  /// - username: String
  /// - tag: String (6 digits)
  /// - uniqueTag: String "username#123456"
  /// - searchableTag: String "username#123456" (lowercase)
  ///
  /// Uses a reservation doc `user_tags/{searchableTag}` to guarantee uniqueness (case-insensitive).
  Future<void> ensureUniqueTagForUser(User user) async {
    await _userService.ensureIdentityForUser(user);
  }

  /// Updates the tag for the current username, validating uniqueness.
  ///
  /// This keeps username stable and only changes the 6-digit tag.
  Future<void> updateTag({
    required String uid,
    required String newTag,
  }) async {
    await _userService.updateTag(uid: uid, newTag: newTag);
  }

  /// Updates the username. Keeps the current 6-digit tag if possible.
  /// If the resulting `username#tag` is taken, a new tag is auto-generated.
  Future<void> updateUsername({
    required String uid,
    required String newUsername,
  }) async {
    await _userService.updateUsername(uid: uid, newUsername: newUsername);
  }

  Future<void> _upsertPublicProfile({
    required String uid,
    required String displayName,
  }) async {
    final cleaned = displayName.trim();
    if (cleaned.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('user_public').doc(uid).set(
        {
          'displayName': cleaned,
          'visible': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort
    }
  }

  String _deriveDisplayName({
    required String email,
    required String? firebaseDisplayName,
  }) {
    final raw = (firebaseDisplayName ?? '').trim();
    if (raw.isNotEmpty) return raw;
    final at = email.indexOf('@');
    if (at <= 0) return '';
    return email.substring(0, at).trim();
  }

  UserProfile _applyDisplayNameToProfile(UserProfile profile, String displayName) {
    final name = displayName.trim();
    if (name.isEmpty) return profile;

    // Only auto-fill if the profile still has the default placeholder.
    final current = profile.name.trim();
    if (current.isEmpty || current == 'CotidyFit') {
      return profile.copyWith(name: name);
    }
    return profile;
  }
}
