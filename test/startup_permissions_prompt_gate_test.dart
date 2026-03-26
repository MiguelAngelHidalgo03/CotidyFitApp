import 'package:cotidyfitapp/screens/startup_permissions_screen.dart';
import 'package:cotidyfitapp/services/app_permissions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePermissionsService extends AppPermissionsService {
  _FakePermissionsService({
    required this.shouldShow,
    this.snapshot = const AppPermissionsSnapshot(
      notifications: AppPermissionStatus.unavailable,
      location: AppPermissionStatus.unavailable,
      steps: AppPermissionStatus.unavailable,
    ),
  });

  final bool shouldShow;
  final AppPermissionsSnapshot snapshot;

  bool markHandledCalled = false;

  @override
  Future<bool> shouldShowStartupPrompt() async => shouldShow;

  @override
  Future<AppPermissionsSnapshot> getSnapshot() async => snapshot;

  @override
  Future<AppPermissionsSnapshot> requestStartupPermissions() async {
    markHandledCalled = true;
    return snapshot;
  }

  @override
  Future<void> markStartupPromptHandled() async {
    markHandledCalled = true;
  }
}

void main() {
  testWidgets('prompts for startup permissions when required', (tester) async {
    final service = _FakePermissionsService(
      shouldShow: true,
      snapshot: const AppPermissionsSnapshot(
        notifications: AppPermissionStatus.notRequested,
        location: AppPermissionStatus.denied,
        steps: AppPermissionStatus.notRequested,
      ),
    );
    var readyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupPermissionsPromptGate(
          permissionsService: service,
          onReady: () => readyCalls += 1,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permisos y acceso'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    await tester.tap(find.text('Lo revisaré más tarde'));
    await tester.pumpAndSettle();

    expect(service.markHandledCalled, isTrue);
    expect(find.text('home'), findsOneWidget);
    expect(readyCalls, 1);
  });

  testWidgets('passes through when startup prompt is not needed', (
    tester,
  ) async {
    final service = _FakePermissionsService(shouldShow: false);
    var readyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupPermissionsPromptGate(
          permissionsService: service,
          onReady: () => readyCalls += 1,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Permisos y acceso'), findsNothing);
    expect(readyCalls, 1);
  });

  test('steps permission stays optional for startup gating', () {
    const snapshot = AppPermissionsSnapshot(
      notifications: AppPermissionStatus.granted,
      location: AppPermissionStatus.granted,
      steps: AppPermissionStatus.notRequested,
    );

    expect(snapshot.hasMissingRequiredPermissions, isFalse);
  });
}