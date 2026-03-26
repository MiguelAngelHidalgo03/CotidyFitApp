import 'package:cotidyfitapp/screens/community_screen.dart';
import 'package:cotidyfitapp/screens/community/chat_screen.dart';
import 'package:cotidyfitapp/core/home_navigation.dart';
import 'package:cotidyfitapp/widgets/progress/progress_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Community entry requests keep swipe linear and navbar tap resets sharing',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'cf_user_profile_json':
            '{"goal":"Salud","isPremium":true,"name":"Tester"}',
      });

      final entryRequest = ValueNotifier(
        const NestedTabEntryRequest(
          mode: NestedTabEntryMode.swipeFromRight,
          token: 1,
        ),
      );
      addTearDown(entryRequest.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(entryRequestListenable: entryRequest),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      for (var i = 0; i < 12; i++) {
        if (find.text('Comunidad Fitness').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Comunidad Fitness'), findsWidgets);

      entryRequest.value = const NestedTabEntryRequest(
        mode: NestedTabEntryMode.navbarDefault,
        token: 2,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Comparte en un toque.'), findsOneWidget);
    },
  );

  testWidgets('Community v3: sharing, coach and news are available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cf_user_profile_json':
          '{"goal":"Salud","isPremium":true,"name":"Tester"}',
    });

    Future<void> tapTab(String label) async {
      final labelFinder = find.text(label);
      await tester.ensureVisible(labelFinder);
      await tester.tap(labelFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
    }

    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.widgetWithText(Tab, 'Compartir'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Coach'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Noticias'), findsOneWidget);

    expect(find.text('Comparte en un toque.'), findsOneWidget);
    expect(find.text('Rutinas'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Actualizar información'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Compartir'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Copiar texto'), findsWidgets);
    expect(find.text('Copiar link'), findsNothing);

    // Coach: local premium fallback remains usable without Firebase.
    await tapTab('Coach');
    for (var i = 0; i < 12; i++) {
      if (find.text('Abrir coach local').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Abrir coach local'), findsOneWidget);

    await tester.tap(find.text('Abrir coach local'));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 12; i++) {
      if (find.byType(ChatScreen).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Coach CotidyFit'), findsWidgets);

    final composerField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          ((w.decoration?.hintText ?? '').contains('Escribe un mensaje')),
    );
    expect(composerField, findsOneWidget);

    await tester.enterText(composerField, 'Hola coach');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hola coach'), findsWidgets);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));

    // Noticias keeps the current communities/news behavior.
    await tapTab('Noticias');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
      find.text('Comunidad Fitness'),
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    final communityCard = find.ancestor(
      of: find.text('Comunidad Fitness'),
      matching: find.byType(ProgressSectionCard),
    );
    final openNewsButton = find.descendant(
      of: communityCard,
      matching: find.widgetWithText(FilledButton, 'Abrir noticia'),
    );
    await tester.tap(openNewsButton);
    await tester.pump(const Duration(milliseconds: 200));

    for (var i = 0; i < 12; i++) {
      if (find.byType(ChatScreen).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(ChatScreen), findsOneWidget);

    expect(find.text('Comunidad Fitness'), findsWidgets);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}
