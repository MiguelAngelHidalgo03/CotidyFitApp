import 'package:cotidyfitapp/screens/community_screen.dart';
import 'package:cotidyfitapp/screens/community/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Community v2: contacts start chats; communities separate', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Comunidad'), findsWidgets);
    expect(find.widgetWithText(Tab, 'Chats'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Contactos'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Comunidades'), findsOneWidget);

    // Chats tab is empty until user sends at least one message.
    expect(find.text('Escribe a un contacto para iniciar un chat.'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);

    // Contactos: open Ana and send a message.
    await tester.tap(find.widgetWithText(Tab, 'Contactos'));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 12; i++) {
      if (find.text('Coach CotidyFit').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Coach CotidyFit'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 12; i++) {
      if (find.byType(ChatScreen).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ChatScreen), findsOneWidget);

    final composerField = find.byWidgetPredicate(
      (w) => w is TextField && ((w.decoration?.hintText ?? '').contains('Escribe un mensaje')),
    );
    expect(composerField, findsOneWidget);

    await tester.enterText(composerField, 'Hola');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hola'), findsWidgets);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));

    // Now Ana should appear in Chats.
    await tester.tap(find.widgetWithText(Tab, 'Chats'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ana'), findsOneWidget);

    // Comunidades stays separate and has seeded items.
    await tester.tap(find.widgetWithText(Tab, 'Comunidades'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.scrollUntilVisible(
      find.text('Comunidad Fitness'),
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await tester.tap(find.text('Comunidad Fitness'));
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
