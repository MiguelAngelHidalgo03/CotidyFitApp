import 'package:cotidyfitapp/screens/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Progress header opens Profile screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: ProgressScreen(),
      ),
    );

    // Allow async loads.
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.widgetWithIcon(IconButton, Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Perfil deportivo'), findsOneWidget);

    // The screen is a ListView; scroll to build lower sections.
    await tester.scrollUntilVisible(
      find.text('Política de privacidad'),
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Política de privacidad'), findsOneWidget);
  });
}
