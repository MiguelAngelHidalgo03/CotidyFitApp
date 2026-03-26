import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme_controller.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile/streak_preferences_setup_screen.dart';
import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'services/offline_sync_queue_service.dart';
import 'services/profile_service.dart';
import 'services/task_reminder_service.dart';
import 'utils/js_error_details.dart';
import 'widgets/common/offline_sync_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kIsWeb) {
      final js = tryDescribeJsError(details.exception);
      if (js != null) debugPrint('global.flutterError\n$js');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('global.onError type=${error.runtimeType}');
    debugPrint('global.onError error=${Error.safeToString(error)}');
    debugPrint('global.onError stack=$stack');
    if (kIsWeb) {
      final js = tryDescribeJsError(error);
      if (js != null) debugPrint('global.onError\n$js');
    }
    return true;
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CotidyFitApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ConnectivityService.instance.initialize());
    unawaited(OfflineSyncQueueService.instance.initialize());
    unawaited(TaskReminderService.instance.initialize());
  });
}

class CotidyFitApp extends StatefulWidget {
  const CotidyFitApp({super.key, this.forceLocalStart = false});

  final bool forceLocalStart;

  @override
  State<CotidyFitApp> createState() => _CotidyFitAppState();
}

class _CotidyFitAppState extends State<CotidyFitApp> {
  @override
  void initState() {
    super.initState();
    unawaited(AppThemeController.instance.load());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'CotidyFit',
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: AppThemeController.instance.themeMode,
          builder: (context, child) {
            return OfflineSyncBanner(child: child ?? const SizedBox.shrink());
          },
          home: widget.forceLocalStart
              ? const _LocalOnboardingGate()
              : const AuthWrapper(),
        );
      },
    );
  }
}

class _LocalOnboardingGate extends StatefulWidget {
  const _LocalOnboardingGate();

  @override
  State<_LocalOnboardingGate> createState() => _LocalOnboardingGateState();
}

class _LocalOnboardingGateState extends State<_LocalOnboardingGate> {
  final _profileService = ProfileService();
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }

        final profile = snapshot.data;
        if (profile == null || !profile.onboardingCompleted) {
          return const OnboardingScreen();
        }
        if (!profile.hasPersonalizedStreakPreferences) {
          return const StreakPreferencesSetupScreen(requireCompletion: true);
        }
        return const MainNavigation();
      },
    );
  }
}
