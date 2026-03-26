import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/home_navigation.dart';
import '../widgets/common/coordinated_horizontal_swipe.dart';
import 'nutrition/tabs/diet_templates_tab.dart';
import 'nutrition/tabs/explore_recipes_tab.dart';
import 'nutrition/tabs/my_day_tab.dart';
import 'nutrition/tabs/nutrition_favorites_tab.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, this.entryRequestListenable});

  final ValueListenable<NestedTabEntryRequest>? entryRequestListenable;

  @override
  State<NutritionScreen> createState() => NutritionScreenState();
}

class NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  static const _mainTabIndex = 0;
  static const _mainTabCount = 5;
  final GlobalKey<NutritionFavoritesTabState> _favoritesKey =
      GlobalKey<NutritionFavoritesTabState>();
  late final TabController _tabController;
  int _lastHandledEntryToken = -1;

  @override
  void initState() {
    super.initState();
    final initialEntry =
        widget.entryRequestListenable?.value ??
        const NestedTabEntryRequest.preserve();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _targetIndexForEntry(initialEntry),
    );
    _lastHandledEntryToken = initialEntry.token;
    widget.entryRequestListenable?.addListener(_handleEntryRequestChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyEntryRequest(initialEntry);
    });
  }

  @override
  void didUpdateWidget(covariant NutritionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryRequestListenable == widget.entryRequestListenable) {
      return;
    }

    oldWidget.entryRequestListenable?.removeListener(
      _handleEntryRequestChanged,
    );
    widget.entryRequestListenable?.addListener(_handleEntryRequestChanged);

    final request = widget.entryRequestListenable?.value;
    if (request == null || request.token == _lastHandledEntryToken) return;
    _lastHandledEntryToken = request.token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyEntryRequest(request);
    });
  }

  @override
  void dispose() {
    widget.entryRequestListenable?.removeListener(_handleEntryRequestChanged);
    _tabController.dispose();
    super.dispose();
  }

  int _targetIndexForEntry(NestedTabEntryRequest request) {
    switch (request.mode) {
      case NestedTabEntryMode.swipeFromRight:
        return 3;
      case NestedTabEntryMode.preserve:
      case NestedTabEntryMode.navbarDefault:
      case NestedTabEntryMode.swipeFromLeft:
        return 0;
    }
  }

  void _handleEntryRequestChanged() {
    final request = widget.entryRequestListenable?.value;
    if (request == null || request.token == _lastHandledEntryToken) return;
    _lastHandledEntryToken = request.token;
    _applyEntryRequest(request);
  }

  void _applyEntryRequest(NestedTabEntryRequest request) {
    if (request.mode == NestedTabEntryMode.preserve) return;

    final targetIndex = _targetIndexForEntry(request);
    if (_tabController.index != targetIndex) {
      _tabController.index = targetIndex;
    }

    if (request.mode == NestedTabEntryMode.swipeFromRight) {
      _moveFavoritesToEdge(fromRight: true);
      return;
    }

    _moveFavoritesToEdge(fromRight: false);
  }

  void _moveFavoritesToEdge({required bool fromRight}) {
    void apply() {
      final favorites = _favoritesKey.currentState;
      if (favorites == null) return;
      if (fromRight) {
        favorites.moveToEnd();
      } else {
        favorites.moveToStart();
      }
    }

    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      apply();
    });
  }

  void _goToAdjacentMainTab(int delta) {
    final nav = HomeNavigation.maybeOf(context);
    if (nav == null) return;

    final nextMainTab = _mainTabIndex + delta;
    if (nextMainTab >= 0 && nextMainTab < _mainTabCount) {
      nav.goToTab(
        nextMainTab,
        source: HomeTabNavigationSource.swipe,
        swipeDelta: delta,
      );
    }
  }

  void _showFavoritesEntry() {
    _tabController.animateTo(3);
    _moveFavoritesToEdge(fromRight: false);
  }

  void _handleSwipeLeft() {
    if (_tabController.index == 3) {
      final favorites = _favoritesKey.currentState;
      if (favorites != null && favorites.hasNext) {
        favorites.moveNext();
        return;
      }

      _goToAdjacentMainTab(1);
      return;
    }

    if (_tabController.index == 2) {
      _showFavoritesEntry();
      return;
    }

    final nextSubTab = _tabController.index + 1;
    if (nextSubTab < _tabController.length) {
      _tabController.animateTo(nextSubTab);
    }
  }

  void _handleSwipeRight() {
    if (_tabController.index == 3) {
      final favorites = _favoritesKey.currentState;
      if (favorites != null && favorites.hasPrevious) {
        favorites.movePrevious();
        return;
      }

      _tabController.animateTo(2);
      return;
    }

    final nextSubTab = _tabController.index - 1;
    if (nextSubTab >= 0) {
      _tabController.animateTo(nextSubTab);
      return;
    }

    _goToAdjacentMainTab(-1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Mi día'),
            Tab(text: 'Plantillas'),
            Tab(text: 'Recetas'),
            Tab(text: 'Favoritos'),
          ],
        ),
      ),
      body: CoordinatedHorizontalSwipe(
        onSwipeLeft: _handleSwipeLeft,
        onSwipeRight: _handleSwipeRight,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const MyDayTab(),
            const DietTemplatesTab(),
            const ExploreRecipesTab(),
            NutritionFavoritesTab(key: _favoritesKey),
          ],
        ),
      ),
    );
  }
}
