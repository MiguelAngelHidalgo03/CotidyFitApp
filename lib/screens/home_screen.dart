import 'package:flutter/material.dart';

import '../core/daily_data_controller.dart';
import '../core/home_navigation.dart';
import 'achievements_screen.dart';
import '../widgets/home/daily_actions_section.dart';
import '../widgets/home/home_extras_section.dart';
import '../widgets/home/home_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DailyDataController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DailyDataController();
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
                          data: _controller.todayData,
                          workoutCompleted: _controller.workoutCompleted,
                          mealsLoggedCount: _controller.mealsLoggedCount,
                          completedCount: _controller.completedCount,
                          totalCount: _controller.totalCount,
                          completedToday: _controller.completedToday,
                          onGoToNutrition: () => HomeNavigation.maybeOf(context)?.goToTab(0),
                          onGoToTraining: () => HomeNavigation.maybeOf(context)?.goToTab(3),
                          onSetSteps: _controller.setSteps,
                          onSetActiveMinutes: _controller.setActiveMinutes,
                          onSetWaterLiters: _controller.setWaterLiters,
                          onToggleStretches: _controller.toggleStretchesDone,
                          onConfirm: _controller.confirmToday,
                        ),
                        const SizedBox(height: 18),
                        HomeExtrasSection(
                          data: _controller.todayData,
                          completedToday: _controller.completedToday,
                          onSetEnergy: _controller.setEnergy,
                          onSetMood: _controller.setMood,
                          onSetStress: _controller.setStress,
                          onSetSleep: _controller.setSleep,
                          quickSteps: _controller.todayData.steps,
                          quickWaterLiters: _controller.todayData.waterLiters,
                          quickMealsLoggedCount: _controller.mealsLoggedCount,
                          quickActiveMinutes: _controller.todayData.activeMinutes,
                          onEditSteps: _controller.setSteps,
                          onAddWater250ml: _controller.addWater250ml,
                          onEditWaterLiters: _controller.setWaterLiters,
                          onEditActiveMinutes: _controller.setActiveMinutes,
                          onGoToAchievements: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AchievementsScreen(
                                  streakCount: _controller.streakCount,
                                  bestCf: _controller.displayedCfIndex,
                                  workoutCompleted: _controller.workoutCompleted,
                                  mealsLoggedCount: _controller.mealsLoggedCount,
                                  todayData: _controller.todayData,
                                ),
                              ),
                            );
                          },
                        ),
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
