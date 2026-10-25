import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/ai/admin_ai_capacity.dart';
import 'package:hkh_admin/ai/admin_ai_capacity_execution.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/shell/admin_router.dart';
import 'capacity_metrics_test.dart' show samplePhases;

const c = '00000000-0000-4000-8000-000000000001';

class _Source implements AdminAiCapacitySource {
  final campaign = <String, dynamic>{
    'id': c,
    'name': 'Voorbeeldtest',
    'status': 'COMPLETED',
    'succeeded': 1,
    'failed': 0,
    'active': 0,
    'created_at': '2026-10-25T12:18:06Z',
    'completed_at': '2026-10-25T12:21:49Z',
    'config': {
      'execution': {
        'vendorId': 'mistral',
        'model': 'glm-5-3',
        'mode': 'SUBSCRIPTION',
      },
      'parallelism': 1,
    },
  };
  Map<String, dynamic> get run => {
    'id': 'r1',
    'ordinal': 1,
    'question': {'question': 'Een historische vraag'},
    'status': 'SUCCEEDED',
    'started_at': '2026-10-25T12:18:06Z',
    'turn_completed_at': '2026-10-25T12:21:49Z',
  };
  @override
  Future<Map<String, dynamic>> load(AdminIdentity identity) async => {
    'campaigns': [campaign],
    'datasets': [],
    'options': [],
  };
  @override
  Future<Map<String, dynamic>> detail(
    AdminIdentity identity,
    String id,
  ) async => {
    'campaign': campaign,
    'runs': [run],
    'phases': samplePhases(),
    'limits': [
      {
        'job_id': 'j2',
        'observation': {'kind': 'SHORT_WINDOW'},
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> execution(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async => {
    'run': {...run, 'campaign_name': 'Voorbeeldtest'},
    'phases': samplePhases(),
    'limits': [],
  };
  @override
  Future<Map<String, dynamic>> result(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async => {};
  @override
  Future<void> post(
    AdminIdentity identity,
    String path, [
    Map<String, dynamic>? body,
  ]) async {}
}

void main() {
  test('execution has a separate bookmarkable route', () {
    const r = '00000000-0000-4000-8000-000000000002';
    final path = AdminPaths.capacityExecution(c, r);
    expect(AdminPaths.normalise(path), path);
    expect(AdminPaths.executionIds(path), [c, r]);
    expect(AdminPaths.resultIds(path), isNull);
    expect(AdminPaths.title(path), 'Uitvoeringsdetails');
  });
  testWidgets(
    'overview shows measurements in a table and navigates instead of expanding raw data',
    (tester) async {
      tester.view.physicalSize = const Size(2800, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAiCapacityPage(
                identity: const AdminIdentity('admin'),
                source: _Source(),
                onNavigate: paths.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Voorbeeldtest · mistral'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('capacity-runs-table')), findsOneWidget);
      for (final heading in [
        'Duur 1e AI-run',
        'Totale tijd',
        'Start',
        'Einde',
        'Fouten',
        'Limiet',
      ]) {
        expect(find.text(heading), findsWidgets);
      }
      expect(find.text('52 sec'), findsOneWidget);
      expect(find.text('3 min 43 sec'), findsWidgets);
      expect(find.text('1 hersteld'), findsOneWidget);
      expect(find.text('Kort venster'), findsWidgets);
      expect(find.textContaining('hkh-capacity-one-direct'), findsNothing);
      expect(find.textContaining('Attempts:'), findsNothing);
      await tester.tap(find.text('Resultaat bekijken'));
      expect(paths.single, AdminPaths.capacityResult(c, 'r1'));
      await tester.tap(find.text('Uitvoeringsdetails'));
      expect(paths.last, AdminPaths.capacityExecution(c, 'r1'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'execution details explain phases and hide technical data until requested',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAiCapacityExecutionPage(
                identity: const AdminIdentity('admin'),
                source: _Source(),
                campaignId: c,
                runId: 'r1',
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Onderzoek richten'), findsOneWidget);
      expect(find.text('Antwoord schrijven'), findsOneWidget);
      expect(find.text('Herpogingen'), findsOneWidget);
      expect(find.textContaining('Runtimejob:'), findsNothing);
      await tester.tap(find.text('Technische details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Runtimejob: j1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
