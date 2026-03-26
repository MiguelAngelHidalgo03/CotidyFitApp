import 'package:flutter/widgets.dart';

enum HomeTabNavigationSource { programmatic, navbarTap, swipe }

enum NestedTabEntryMode {
  preserve,
  navbarDefault,
  swipeFromLeft,
  swipeFromRight,
}

@immutable
class NestedTabEntryRequest {
  const NestedTabEntryRequest({required this.mode, required this.token});

  const NestedTabEntryRequest.preserve()
    : mode = NestedTabEntryMode.preserve,
      token = 0;

  final NestedTabEntryMode mode;
  final int token;
}

typedef HomeTabNavigator =
    void Function(int index, {HomeTabNavigationSource source, int? swipeDelta});

class HomeNavigation extends InheritedWidget {
  const HomeNavigation({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  final int currentIndex;
  final HomeTabNavigator goToTab;

  static HomeNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeNavigation>();
  }

  @override
  bool updateShouldNotify(covariant HomeNavigation oldWidget) {
    return oldWidget.currentIndex != currentIndex;
  }
}
