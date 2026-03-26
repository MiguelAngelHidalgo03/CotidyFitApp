import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/push_token_service.dart';
import '../../services/user_repository.dart';
import '../main_navigation.dart';
import '../onboarding_screen.dart';
import '../profile/streak_preferences_setup_screen.dart';
import '../splash_screen.dart';
import '../startup_permissions_screen.dart';
import 'auth_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<void> _initFuture;
  String? _registeredTokenUid;
  Future<User?>? _sessionRestoreFuture;
  String? _bootstrappedUid;
  Future<bool>? _bootstrapFuture;
  Future<UserProfile?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Firebase.apps.isNotEmpty
        ? Future<void>.value()
        : Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firebase no está listo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Revisa tu configuración de Firebase (google-services.json / GoogleService-Info.plist).',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Detalle: ${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final auth = AuthService();
        final users = UserRepository();
        _sessionRestoreFuture ??= auth.restoreSessionIfPossible();

        return FutureBuilder<User?>(
          future: _sessionRestoreFuture,
          builder: (context, restoreSnap) {
            if (restoreSnap.connectionState != ConnectionState.done) {
              return const SplashScreen();
            }

            final restoredUser = restoreSnap.data ?? auth.currentUser;

            return StreamBuilder(
              stream: auth.authStateChanges(),
              initialData: restoredUser,
              builder: (context, authSnap) {
                if (authSnap.connectionState != ConnectionState.active) {
                  return const SplashScreen();
                }

                final user = authSnap.data ?? auth.currentUser;
                if (user == null) return const AuthScreen();

                if (_bootstrappedUid != user.uid || _bootstrapFuture == null) {
                  _bootstrappedUid = user.uid;
                  _bootstrapFuture = users.bootstrapSignedInUser(user);
                  _profileFuture = null;
                }

                return FutureBuilder<bool>(
                  future: _bootstrapFuture,
                  builder: (context, bootSnap) {
                    if (bootSnap.connectionState != ConnectionState.done) {
                      return const SplashScreen();
                    }
                    if (bootSnap.hasError) {
                      // If Firestore is temporarily unavailable, fall back to local gating.
                      return const _LocalFallbackGate();
                    }

                    final completed = bootSnap.data ?? false;

                    if (!completed) return const OnboardingScreen();

                    return StartupPermissionsPromptGate(
                      key: ValueKey('startup-permissions-${user.uid}'),
                      onReady: () {
                        if (_registeredTokenUid == user.uid) return;
                        _registeredTokenUid = user.uid;
                        try {
                          PushTokenService().registerCurrentDeviceToken();
                        } catch (_) {
                          // ignore
                        }
                      },
                      child: const _ProfileSetupGate(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LocalFallbackGate extends StatelessWidget {
  const _LocalFallbackGate();

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService();
    return FutureBuilder<UserProfile?>(
      future: profile.getProfile(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        final p = snap.data;
        if (p != null && p.onboardingCompleted) {
          if (p.hasPersonalizedStreakPreferences) {
            return const StartupPermissionsPromptGate(child: MainNavigation());
          }
          return const StartupPermissionsPromptGate(
            child: StreakPreferencesSetupScreen(requireCompletion: true),
          );
        }
        return const OnboardingScreen();
      },
    );
  }
}

class _ProfileSetupGate extends StatelessWidget {
  const _ProfileSetupGate();

  @override
  Widget build(BuildContext context) {
    return _CachedProfileSetupGate(profileService: ProfileService());
  }
}

class _CachedProfileSetupGate extends StatefulWidget {
  const _CachedProfileSetupGate({required this.profileService});

  final ProfileService profileService;

  @override
  State<_CachedProfileSetupGate> createState() =>
      _CachedProfileSetupGateState();
}

class _CachedProfileSetupGateState extends State<_CachedProfileSetupGate> {
  late final Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileService.getProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        final current = snap.data;
        if (current != null && current.hasPersonalizedStreakPreferences) {
          return const MainNavigation();
        }
        return const StreakPreferencesSetupScreen(requireCompletion: true);
      },
    );
  }
}
