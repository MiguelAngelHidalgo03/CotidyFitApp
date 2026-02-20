import 'package:cotidyfitapp/screens/training_screen.dart';
import 'package:cotidyfitapp/screens/my_plan_screen.dart';
import 'package:cotidyfitapp/widgets/training/training_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Training entry opens Mi semana', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));

    expect(find.text('Mi semana'), findsOneWidget);
    expect(find.text('Buscar rutinas'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));

    final miSemanaCard = tester.widget<TrainingActionCard>(
      find.widgetWithText(TrainingActionCard, 'Mi semana'),
    );
    miSemanaCard.onTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MyPlanScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Mi semana')),
      findsOneWidget,
    );
  });

  testWidgets('Training entry opens Buscar rutinas', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    final buscarRutinasCard = tester.widget<TrainingActionCard>(
      find.widgetWithText(TrainingActionCard, 'Buscar rutinas'),
    );
    buscarRutinasCard.onTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Explorar entrenamientos'), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
  });
}
