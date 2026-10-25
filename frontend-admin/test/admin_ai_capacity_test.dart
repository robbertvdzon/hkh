import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/ai/admin_ai_capacity.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/shell/admin_router.dart';

class _Source implements AdminAiCapacitySource {
  final posts = <(String, Map<String, dynamic>?)>[];
  final state = <String, dynamic>{
    'method': 'PIPELINE',
    'writeBudgetChars': 450000,
    'datasets': [
      {
        'id': 'set1',
        'name': 'Vaste vragenlijst',
        'count': 1000,
        'checksum': 'abcdef123456abcdef',
      },
    ],
    'options': [
      for (final p in ['openai', 'anthropic'])
        {
          'execution': {
            'vendorId': p,
            'model': '$p-test',
            'mode': 'SUBSCRIPTION',
          },
          'available': true,
        },
    ],
    'campaigns': [
      {
        'id': 'camp1',
        'name': 'Bestaande campagne',
        'provider': 'openai',
        'holds_provider': true,
        'status': 'WAITING_LIMIT',
        'started': 4,
        'succeeded': 2,
        'failed': 0,
        'active': 2,
        'reason': 'Korte grens',
        'config': {
          'execution': {
            'vendorId': 'openai',
            'model': 'openai-test',
            'mode': 'SUBSCRIPTION',
          },
        },
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> load(AdminIdentity identity) async => state;
  @override
  Future<Map<String, dynamic>> detail(
    AdminIdentity identity,
    String id,
  ) async => {
    'campaign': {
      'id': id,
      'name': 'Bestaande campagne',
      'status': 'WAITING_LIMIT',
      'config': {
        'method': 'PIPELINE',
        'parallelism': 2,
        'accountAlias': 'test',
        'datasetVersion': 'v1',
      },
    },
    'runs': [],
    'phases': [],
    'limits': [
      {
        'recorded_at': '2026-10-25',
        'observation': {'kind': 'SHORT_WINDOW'},
        'counts': {'succeeded': 2, 'active': 2},
        'job_id': 'job1',
        'attempt_id': 'attempt1',
      },
    ],
    'events': [],
  };
  @override
  Future<Map<String, dynamic>> result(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async => {};
  @override
  Future<Map<String, dynamic>> execution(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async => {};
  @override
  Future<void> post(
    AdminIdentity identity,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    posts.add((path, body));
  }
}

void main() {
  test('capacity page has a stable admin route', () {
    expect(AdminPaths.normalise('/ai-capaciteit'), AdminPaths.aiCapacity);
    expect(AdminPaths.title(AdminPaths.aiCapacity), 'Capaciteitstests');
  });

  testWidgets(
    'opening the page starts no jobs and import remains a separate action',
    (tester) async {
      final source = _Source();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAiCapacityPage(
                identity: const AdminIdentity('admin'),
                source: source,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Capaciteitstests'), findsOneWidget);
      expect(find.textContaining('2 geslaagd'), findsOneWidget);
      expect(source.posts, isEmpty);
      await tester.tap(find.text('1.000 HKH-vragen importeren'));
      await tester.pumpAndSettle();
      expect(source.posts.single.$1, '/datasets/bundled');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'occupied provider is blocked and another provider requires review before starting',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _Source();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAiCapacityPage(
                identity: const AdminIdentity('admin'),
                source: source,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capacity-create')));
      await tester.pumpAndSettle();
      expect(
        find.text('Deze provider heeft al een actieve campagne.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Instellingen controleren'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('capacity-provider')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('anthropic · anthropic-test · SUBSCRIPTION').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instellingen controleren'));
      await tester.pumpAndSettle();
      expect(source.posts, isEmpty);
      expect(find.text('Duurtest starten'), findsOneWidget);
      await tester.tap(find.text('Campagne starten'));
      await tester.pumpAndSettle();
      expect(source.posts.single.$1, '/campaigns');
      expect(source.posts.single.$2?['execution']['vendorId'], 'anthropic');
      expect(source.posts.single.$2?['parallelism'], 1);
      expect(source.posts.single.$2?['repeatQuestions'], false);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
