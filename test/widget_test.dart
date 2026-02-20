// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotidyfitapp/main.dart';
import 'package:cotidyfitapp/screens/home_screen.dart';
import 'package:cotidyfitapp/widgets/home/daily_actions_section.dart';

void main() {
  testWidgets('Home shows daily question', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'cf_user_profile_json': '{"goal":"Mejorar hábitos"}',
    });
    await tester.pumpWidget(const CotidyFitApp(forceLocalStart: true));

    // Wait for MainNavigation to appear.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) break;
    }

    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Ensure we are on the Home tab (PageView initial page can be timing-sensitive in tests).
    final bottomNav = find.byType(BottomNavigationBar);
    final homeIcon = find.descendant(of: bottomNav, matching: find.byIcon(Icons.home));
    final homeIconOutlined = find.descendant(of: bottomNav, matching: find.byIcon(Icons.home_outlined));

    if (homeIcon.evaluate().isNotEmpty) {
      await tester.tap(homeIcon.first);
    } else {
      await tester.tap(homeIconOutlined.first);
    }
    await tester.pump(const Duration(milliseconds: 320));

    // Wait until HomeScreen is onstage.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(HomeScreen), findsOneWidget);

    // Wait for Home content (DailyDataController init) to finish.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      if (find.byType(DailyActionsSection).evaluate().isNotEmpty) break;
    }

    expect(find.byType(DailyActionsSection), findsOneWidget);
    expect(find.text('¿Qué has hecho hoy?'), findsOneWidget);
    expect(find.text('Confirmar día'), findsOneWidget);
  });
}
