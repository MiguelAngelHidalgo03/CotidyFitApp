import 'package:cotidyfitapp/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Onboarding starts with permissions step', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Permisos y acceso'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Aceptar y revisar ahora'),
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Aceptar y revisar ahora'), findsOneWidget);
    expect(find.text('Lo revisaré más tarde'), findsOneWidget);
  });
}
