import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cotidyfitapp/main.dart';

void main() {
  testWidgets('local startup requests personalized streak setup when missing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cf_user_profile_json':
          '{"goal":"Mejorar hábitos","onboardingCompleted":true}',
    });

    await tester.pumpWidget(const CotidyFitApp(forceLocalStart: true));

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      if (find.text('Personaliza tu racha').evaluate().isNotEmpty) break;
    }

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      if (find
          .text('Antes de entrar, elige que quieres mantener en racha.')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text('Personaliza tu racha'), findsOneWidget);
    expect(
      find.text('Antes de entrar, elige que quieres mantener en racha.'),
      findsOneWidget,
    );
  });
}
