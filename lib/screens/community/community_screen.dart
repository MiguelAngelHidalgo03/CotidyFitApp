import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/home_navigation.dart';
import '../../core/theme.dart';
import '../../widgets/common/coordinated_horizontal_swipe.dart';
import 'tabs/community_coach_tab.dart';
import 'tabs/community_news_tab.dart';
import 'tabs/community_share_tab.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.entryRequestListenable});

  final ValueListenable<NestedTabEntryRequest>? entryRequestListenable;

  @override
  State<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  static const _mainTabIndex = 1;
  static const _mainTabCount = 5;
  late final TabController _tabController;
  int _lastHandledEntryToken = -1;

  @override
  void initState() {
    super.initState();
    final initialEntry =
        widget.entryRequestListenable?.value ??
        const NestedTabEntryRequest.preserve();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _targetIndexForEntry(initialEntry),
    );
    _lastHandledEntryToken = initialEntry.token;
    widget.entryRequestListenable?.addListener(_handleEntryRequestChanged);
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
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
    _applyEntryRequest(request);
  }

  @override
  void dispose() {
    widget.entryRequestListenable?.removeListener(_handleEntryRequestChanged);
    _tabController.dispose();
    super.dispose();
  }

  int _targetIndexForEntry(NestedTabEntryRequest request) {
    switch (request.mode) {
      case NestedTabEntryMode.swipeFromLeft:
        return 0;
      case NestedTabEntryMode.swipeFromRight:
        return 2;
      case NestedTabEntryMode.preserve:
      case NestedTabEntryMode.navbarDefault:
        return 1;
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

  void _handleSwipeLeft() {
    final nextSubTab = _tabController.index + 1;
    if (nextSubTab < _tabController.length) {
      _tabController.animateTo(nextSubTab);
      return;
    }

    _goToAdjacentMainTab(1);
  }

  void _handleSwipeRight() {
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
          labelColor: CFColors.primary,
          unselectedLabelColor: CFColors.textSecondary,
          indicatorColor: CFColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          tabs: const [
            Tab(text: 'Coach'),
            Tab(text: 'Compartir'),
            Tab(text: 'Noticias'),
          ],
        ),
      ),
      body: CoordinatedHorizontalSwipe(
        onSwipeLeft: _handleSwipeLeft,
        onSwipeRight: _handleSwipeRight,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            CommunityCoachTab(),
            CommunityShareTab(),
            CommunityNewsTab(),
          ],
        ),
      ),
    );
  }
}
