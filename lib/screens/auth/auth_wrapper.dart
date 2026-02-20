import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/push_token_service.dart';
import '../../services/user_repository.dart';
import '../main_navigation.dart';
import '../onboarding_screen.dart';
import '../splash_screen.dart';
import 'auth_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Future<void> _initFuture;
  String? _registeredTokenUid;

  @override
  void initState() {
    super.initState();
    _initFuture = Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SplashScreen();
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    const Text('Revisa tu configuración de Firebase (google-services.json / GoogleService-Info.plist).'),
                    const SizedBox(height: 10),
                    Text('Detalle: ${snapshot.error}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          );
        }

        final auth = AuthService();
        final users = UserRepository();

        return StreamBuilder(
          stream: auth.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState != ConnectionState.active) return const SplashScreen();

            final user = authSnap.data;
            if (user == null) return const AuthScreen();

            return FutureBuilder<bool>(
              future: users.bootstrapSignedInUser(user),
              builder: (context, bootSnap) {
                if (bootSnap.connectionState != ConnectionState.done) return const SplashScreen();
                if (bootSnap.hasError) {
                  // If Firestore is temporarily unavailable, fall back to local gating.
                  return const _LocalFallbackGate();
                }

                final completed = bootSnap.data ?? false;

                // Best-effort: register push token once per signed-in user.
                if (_registeredTokenUid != user.uid) {
                  _registeredTokenUid = user.uid;
                  try {
                    PushTokenService().registerCurrentDeviceToken();
                  } catch (_) {
                    // ignore
                  }
                }

                return completed ? const MainNavigation() : const OnboardingScreen();
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
        if (snap.connectionState != ConnectionState.done) return const SplashScreen();
        final p = snap.data;
        if (p != null && p.onboardingCompleted) return const MainNavigation();
        return const OnboardingScreen();
      },
    );
  }
}
