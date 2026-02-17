import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'services/profile_service.dart';

void main() {
  runApp(const CotidyFitApp());
}

class CotidyFitApp extends StatelessWidget {
  const CotidyFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CotidyFit',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppStartGate(),
    );
  }
}

class _AppStartGate extends StatefulWidget {
  const _AppStartGate();

  @override
  State<_AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<_AppStartGate> {
  final _profileService = ProfileService();
  late Future<String?> _goalFuture;

  @override
  void initState() {
    super.initState();
    _goalFuture = _profileService.getGoal();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _goalFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final goal = snapshot.data;
        if (goal == null || goal.trim().isEmpty) {
          return const OnboardingScreen();
        }
        return const MainNavigation();
      },
    );
  }
}
