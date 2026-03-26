import 'package:flutter/material.dart';

import 'community/community_screen.dart' as community_impl;
import '../core/home_navigation.dart';
import 'home_screen.dart';
import 'nutrition_screen.dart';
import 'progress_screen.dart';
import 'training_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, this.initialIndex = 2});

  final int initialIndex;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _tabCount = 5;
  static const _nutritionTabIndex = 0;
  static const _communityTabIndex = 1;
  late int _index;
  final Map<int, Widget> _tabCache = {};
  late final PageController _pageController;
  late final ValueNotifier<NestedTabEntryRequest> _nutritionEntryRequest;
  late final ValueNotifier<NestedTabEntryRequest> _communityEntryRequest;
  HomeTabNavigationSource? _pendingTransitionSource;
  int? _pendingTransitionTarget;
  int _entryToken = 0;
  int? _preparedDragTarget;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex >= _tabCount
              ? _tabCount - 1
              : widget.initialIndex);
    _nutritionEntryRequest = ValueNotifier(
      const NestedTabEntryRequest.preserve(),
    );
    _communityEntryRequest = ValueNotifier(
      const NestedTabEntryRequest(
        mode: NestedTabEntryMode.swipeFromRight,
        token: 0,
      ),
    );
    _pageController = PageController(initialPage: _index)
      ..addListener(_handlePageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _nutritionEntryRequest.dispose();
    _communityEntryRequest.dispose();
    super.dispose();
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return NutritionScreen(entryRequestListenable: _nutritionEntryRequest);
      case 1:
        return community_impl.CommunityScreen(
          entryRequestListenable: _communityEntryRequest,
        );
      case 2:
        return const HomeScreen();
      case 3:
        return const TrainingScreen();
      case 4:
        return const ProgressScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _tabFor(int index) {
    return _tabCache.putIfAbsent(index, () => _buildTab(index));
  }

  void _selectTab(int value) {
    if (_index == value) return;
    setState(() {
      _index = value;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients || _pendingTransitionSource != null) {
      return;
    }

    final page = _pageController.page;
    if (page == null) return;

    final distanceFromCurrent = page - _index;
    if (distanceFromCurrent.abs() < 0.02) {
      _preparedDragTarget = null;
      return;
    }

    final swipeDelta = distanceFromCurrent.isNegative ? -1 : 1;
    final targetIndex = _index + swipeDelta;
    if (targetIndex < 0 || targetIndex >= _tabCount) return;
    if (_preparedDragTarget == targetIndex) return;

    _preparedDragTarget = targetIndex;
    _prepareTabEntry(
      targetIndex,
      source: HomeTabNavigationSource.swipe,
      swipeDelta: swipeDelta,
    );
  }

  void _handlePageChanged(int value) {
    if (_pendingTransitionTarget != null && value != _pendingTransitionTarget) {
      return;
    }

    if (_index == value) {
      _pendingTransitionSource = null;
      _pendingTransitionTarget = null;
      _preparedDragTarget = null;
      return;
    }

    final previousIndex = _index;
    final delta = value - previousIndex;
    if (_pendingTransitionSource == null && delta != 0) {
      _prepareTabEntry(
        value,
        source: HomeTabNavigationSource.swipe,
        swipeDelta: delta,
      );
    }

    setState(() {
      _index = value;
    });

    _pendingTransitionSource = null;
    _pendingTransitionTarget = null;
    _preparedDragTarget = null;
  }

  void _goToTab(
    int value, {
    HomeTabNavigationSource source = HomeTabNavigationSource.programmatic,
    int? swipeDelta,
  }) {
    _prepareTabEntry(value, source: source, swipeDelta: swipeDelta);
    if (_index == value) return;

    _pendingTransitionSource = source;
    _pendingTransitionTarget = value;
    _selectTab(value);
  }

  void _prepareTabEntry(
    int value, {
    required HomeTabNavigationSource source,
    int? swipeDelta,
  }) {
    final request = _entryRequestFor(
      value,
      source: source,
      swipeDelta: swipeDelta,
    );
    if (request == null) return;

    switch (value) {
      case _nutritionTabIndex:
        _nutritionEntryRequest.value = request;
        return;
      case _communityTabIndex:
        _communityEntryRequest.value = request;
        return;
    }
  }

  NestedTabEntryRequest? _entryRequestFor(
    int value, {
    required HomeTabNavigationSource source,
    int? swipeDelta,
  }) {
    if (value != _nutritionTabIndex && value != _communityTabIndex) {
      return null;
    }

    switch (source) {
      case HomeTabNavigationSource.programmatic:
        return null;
      case HomeTabNavigationSource.navbarTap:
        return NestedTabEntryRequest(
          mode: NestedTabEntryMode.navbarDefault,
          token: ++_entryToken,
        );
      case HomeTabNavigationSource.swipe:
        return NestedTabEntryRequest(
          mode: (swipeDelta ?? 0) < 0
              ? NestedTabEntryMode.swipeFromRight
              : NestedTabEntryMode.swipeFromLeft,
          token: ++_entryToken,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactLabels = MediaQuery.sizeOf(context).width < 392;
    final pageSwipePhysics = (_index == 0 || _index == 1)
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics();

    return HomeNavigation(
      currentIndex: _index,
      goToTab: _goToTab,
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          physics: pageSwipePhysics,
          onPageChanged: _handlePageChanged,
          itemCount: 5,
          itemBuilder: (context, index) => _tabFor(index),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (value) =>
              _goToTab(value, source: HomeTabNavigationSource.navbarTap),
          selectedFontSize: compactLabels ? 10.5 : 11.5,
          unselectedFontSize: compactLabels ? 10.5 : 11.5,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.restaurant_outlined),
              activeIcon: const Icon(Icons.restaurant),
              label: 'Nutrición',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.groups_outlined),
              activeIcon: const Icon(Icons.groups),
              label: 'Comunidad',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.fitness_center_outlined),
              activeIcon: const Icon(Icons.fitness_center),
              label: compactLabels ? 'Entreno' : 'Entrenamiento',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.query_stats_outlined),
              activeIcon: const Icon(Icons.query_stats),
              label: 'Progreso',
            ),
          ],
        ),
      ),
    );
  }
}
