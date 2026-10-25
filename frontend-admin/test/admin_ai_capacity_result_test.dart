import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:hkh_admin/ai/admin_ai_capacity.dart';
import 'package:hkh_admin/ai/admin_ai_capacity_result.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/shell/admin_router.dart';

const campaign = '00000000-0000-4000-8000-000000000001';
const run = '00000000-0000-4000-8000-000000000002';

class _Results implements AdminAiCapacitySource {
  int reads = 0;
  int writes = 0;
  String status = 'SUCCEEDED';
  @override
  Future<Map<String, dynamic>> result(
    AdminIdentity identity,
    String campaignId,
    String runId,
  ) async {
    reads++;
    return {
      'run': {
        'id': runId,
        'status': status,
        'campaign_name': 'Mistral duurtest',
        'ordinal': 3,
        'question': {'question': 'Wat is bekend over de Kerklaan?'},
        'config': {
          'execution': {
            'vendorId': 'mistral',
            'model': 'glm-5-3',
            'mode': 'SUBSCRIPTION',
          },
        },
      },
      'turns': [
        {
          'id': 'turn1',
          'turnNumber': 1,
          'status': status,
          'title': 'De Kerklaan',
          'answerHtml':
              '<h2>Een straat met geschiedenis</h2><p>Dit is het <strong>opgemaakte antwoord</strong>.</p><figure><img src="https://example.org/foto.jpg" alt="Kerklaan in 1950"><figcaption>Kerklaan in 1950</figcaption></figure>',
          'sourcesHtml': '<h3>Bronnen uit het archief</h3><p>Beeldbank 123</p>',
        },
        {
          'id': 'turn2',
          'turnNumber': 2,
          'question': 'Wie woonden er?',
          'status': status,
          'title': 'De bewoners',
          'answerHtml': '<p>Het antwoord op de vervolgvraag.</p>',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> load(AdminIdentity identity) async => {};
  @override
  Future<Map<String, dynamic>> detail(
    AdminIdentity identity,
    String id,
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
    writes++;
  }
}

void main() {
  test(
    'result requests carry admin authentication and use the scoped result API',
    () async {
      final client = AdminAiCapacityClient(
        'https://api.example',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/admin/ai-search/capacity/campaigns/$campaign/runs/$run/result',
          );
          expect(request.headers['Authorization'], 'Bearer synthetic-admin');
          return http.Response('{"run":{},"turns":[]}', 200);
        }),
      );
      await client.result(
        const AdminIdentity(
          'admin',
          requestHeaders: {'Authorization': 'Bearer synthetic-admin'},
        ),
        campaign,
        run,
      );
    },
  );

  test(
    'result addresses survive bookmarks and invalid IDs do not become routes',
    () {
      final path = AdminPaths.capacityResult(campaign, run);
      expect(AdminPaths.normalise(path), path);
      expect(AdminPaths.resultIds(path), [campaign, run]);
      expect(AdminPaths.title(path), 'Testresultaat');
      expect(AdminPaths.normalise('/ai-capaciteit/geen/id'), AdminPaths.start);
    },
  );

  testWidgets(
    'stored answers render text and pictures, with sources and a separate follow up',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _Results();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAiCapacityResultPage(
                identity: const AdminIdentity('admin'),
                source: source,
                campaignId: campaign,
                runId: run,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(
        find.text('Een straat met geschiedenis', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('<h2>'), findsNothing);
      expect(find.byType(HtmlWidget), findsWidgets);
      expect(find.byTooltip('Foto vergroten'), findsOneWidget);
      expect(find.text('Vervolgvraag'), findsOneWidget);
      expect(find.text('Wie woonden er?'), findsOneWidget);
      await tester.ensureVisible(find.text('Bronnen bekijken'));
      await tester.tap(find.text('Bronnen bekijken'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bronnen uit het archief', findRichText: true),
        findsOneWidget,
      );
      expect(source.reads, 1);
      expect(source.writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unfinished results explain that no answer is ready yet', (
    tester,
  ) async {
    final source = _Results()..status = 'RUNNING';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminAiCapacityResultPage(
              identity: const AdminIdentity('admin'),
              source: source,
              campaignId: campaign,
              runId: run,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Het onderzoek loopt nog.'), findsWidgets);
    expect(find.byType(HtmlWidget), findsNothing);
    expect(source.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
