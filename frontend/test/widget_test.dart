import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/backend/backend_status.dart';
import 'package:hkh_app/main.dart';

class _SuccessfulStatusSource implements BackendStatusSource {
  @override
  Future<BackendStatus> load() async => const BackendStatus(
    application: 'hkh',
    version: 'test',
    commit: 'abc123',
  );
}

class _FailingStatusSource implements BackendStatusSource {
  @override
  Future<BackendStatus> load() async => throw StateError('offline');
}

void main() {
  testWidgets('shows backend version when the service is ready', (
    tester,
  ) async {
    await tester.pumpWidget(HkhApp(statusSource: _SuccessfulStatusSource()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Ontdek de geschiedenis van Heemskerk vanuit een vraag',
      ),
      findsOneWidget,
    );
    expect(find.text('hkh test · abc123'), findsOneWidget);

    await tester.tap(find.text('Lees onze productvisie'));
    await tester.pumpAndSettle();

    expect(find.text('Productvisie'), findsWidgets);
    expect(find.text('Productprincipes'), findsOneWidget);
    expect(find.text('Verbonden'), findsOneWidget);
  });

  testWidgets('shows a retry action when the service is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(HkhApp(statusSource: _FailingStatusSource()));
    await tester.pumpAndSettle();

    expect(find.text('De HKH-service is niet bereikbaar'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsOneWidget);
  });
}
