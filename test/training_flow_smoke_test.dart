import 'package:cotidyfitapp/screens/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Training entry opens My Plan and Explore', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingScreen(),
      ),
    );

    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Mi Plan'), findsOneWidget);
    expect(find.text('Explorar entrenamientos'), findsOneWidget);

    await tester.tap(find.text('Mi Plan'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mi Plan'), findsWidgets);

    await tester.runAsync(() async {
      final context = tester.element(find.byType(TrainingScreen));
      await Navigator.of(context).maybePop();
    });
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Explorar entrenamientos'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Explorar entrenamientos'), findsWidgets);
  });
}
