import 'package:flutter/widgets.dart';

class HomeNavigation extends InheritedWidget {
  const HomeNavigation({
    super.key,
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  final int currentIndex;
  final void Function(int index) goToTab;

  static HomeNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeNavigation>();
  }

  @override
  bool updateShouldNotify(covariant HomeNavigation oldWidget) {
    return oldWidget.currentIndex != currentIndex;
  }
}
