import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'core/theme.dart';
import 'models/user_profile.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/profile_service.dart';
import 'utils/js_error_details.dart';

void main() {
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

  runApp(const CotidyFitApp());
}

class CotidyFitApp extends StatelessWidget {
  const CotidyFitApp({super.key, this.forceLocalStart = false});

  final bool forceLocalStart;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CotidyFit',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: forceLocalStart ? const _LocalOnboardingGate() : const AuthWrapper(),
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
        if (snapshot.connectionState != ConnectionState.done) return const SplashScreen();

        final profile = snapshot.data;
        if (profile == null || !profile.onboardingCompleted) {
          return const OnboardingScreen();
        }
        return const MainNavigation();
      },
    );
  }
}
