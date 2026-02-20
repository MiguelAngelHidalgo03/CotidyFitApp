import 'package:cotidyfitapp/screens/nutrition_screen.dart';
import 'package:cotidyfitapp/screens/nutrition/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotidyfitapp/widgets/nutrition/recipe_card.dart';

void main() {
  testWidgets('Nutrition renders and can open a recipe detail', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: NutritionScreen()));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.widgetWithText(Tab, 'Plantillas'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Explorar recetas'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Recetas favoritas'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Mi día'), findsOneWidget);

    // Default tab is now "Plantillas"; switch to Explore.
    await tester.tap(find.widgetWithText(Tab, 'Explorar recetas'));
    await tester.pump(const Duration(milliseconds: 300));

    // Wait for recipes to load then open first card.
    for (var i = 0; i < 12; i++) {
      if (find.byType(RecipeCard).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(RecipeCard), findsWidgets);

    await tester.tap(find.byType(RecipeCard).first);
    await tester.pump(const Duration(milliseconds: 200));

    for (var i = 0; i < 20; i++) {
      if (find.byType(RecipeDetailScreen).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(RecipeDetailScreen), findsOneWidget);

    // Button is near the top; check it early.
    if (find.text('Añadir a Mi día').evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text('Añadir a Mi día'),
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 10,
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Añadir a Mi día'), findsOneWidget);

    for (var i = 0; i < 20; i++) {
      if (find.text('Ingredientes').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }

    if (find.text('Ingredientes').evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text('Ingredientes'),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Ingredientes'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pasos'),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Pasos'), findsOneWidget);
  });
}
