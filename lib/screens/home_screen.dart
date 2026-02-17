import 'package:flutter/material.dart';

import '../core/daily_checkin_controller.dart';
import '../services/local_storage_service.dart';
import '../widgets/home/daily_actions_section.dart';
import '../widgets/home/home_extras_section.dart';
import '../widgets/home/home_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DailyCheckInController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DailyCheckInController(storage: LocalStorageService());
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _controller.init(),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        HomeHeader(
                          streakCount: _controller.streakCount,
                          cfIndex: _controller.displayedCfIndex,
                        ),
                        const SizedBox(height: 16),
                        DailyActionsSection(
                          actions: DailyCheckInController.actions,
                          selected: _controller.selectedActions,
                          completedToday: _controller.completedToday,
                          onToggle: _controller.toggleAction,
                          onConfirm: _controller.confirmToday,
                        ),
                        const SizedBox(height: 18),
                        const HomeExtrasSection(),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
