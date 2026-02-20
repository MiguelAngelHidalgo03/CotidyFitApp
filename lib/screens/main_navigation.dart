import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/home_navigation.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'nutrition_screen.dart';
import 'progress_screen.dart';
import 'training_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final PageController _controller;
  int _index = 2;

  late final List<Widget> _tabs = const [
    NutritionScreen(),
    CommunityScreen(),
    HomeScreen(),
    TrainingScreen(),
    ProgressScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeNavigation(
      currentIndex: _index,
      goToTab: (value) {
        setState(() => _index = value);
        _controller.animateToPage(
          value,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      },
      child: Scaffold(
        body: PageView(
          controller: _controller,
          onPageChanged: (value) => setState(() => _index = value),
          children: _tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (value) {
            setState(() => _index = value);
            _controller.animateToPage(
              value,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: CFColors.primary,
          unselectedItemColor: CFColors.textSecondary,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: 'Nutrición',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Comunidad',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Entrenamiento',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats_outlined),
              activeIcon: Icon(Icons.query_stats),
              label: 'Progreso',
            ),
          ],
        ),
      ),
    );
  }
}
