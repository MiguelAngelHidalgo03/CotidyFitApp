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

void main() {
  testWidgets('Home shows daily question', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'cf_user_profile_json': '{"goal":"Mejorar hábitos"}',
    });
    await tester.pumpWidget(const CotidyFitApp());

    // Allow async controller init to complete.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('¿Qué has hecho hoy por tu salud?'), findsOneWidget);
    expect(find.text('Confirmar día'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
