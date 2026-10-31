import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/main.dart';
import 'package:hkh_admin/shell/admin_router.dart';
import 'package:hkh_admin/workflow/admin_workflow_log.dart';

import 'package:hkh_admin/collection/admin_collection_scrape.dart';

const _sessionId = '0b1f6a4e-5c3d-4a2b-9e8f-7d6c5b4a3210';

class _AuthenticatedSession implements AdminSessionSource {
  @override
  bool get configured => true;
  @override
  Stream<AdminIdentity> get identities => const Stream.empty();
  @override
  Future<AdminIdentity?> bootstrap() async =>
      const AdminIdentity('admin@example.com');
  @override
  Future<AdminIdentity?> signIn() async =>
      const AdminIdentity('admin@example.com');
  @override
  Future<void> signOut() async {}
  @override
  void dispose() {}
}

class _ScrapeSource implements AdminScrapeSource {
  @override
  Future<ScrapeStatus?> loadStatus(AdminIdentity identity) async => null;
  @override
  Future<ScrapeStatus> start({
    required AdminIdentity identity,
    required ScrapeMode mode,
    required bool force,
  }) => throw UnimplementedError();
  @override
  Future<ScrapeStatus?> stop(AdminIdentity identity) async => null;
}

class _WorkflowSource implements AdminWorkflowLogSource {
  final List<WorkflowKind> kinds = [];
  final List<String?> asked = [];
  final List<String> opened = [];

  WorkflowSessionSummary _summary(
    String id,
    String kind,
    String status, {
    String source = 'macbook',
  }) => WorkflowSessionSummary(
    id: id,
    kind: kind,
    createdAt: DateTime(2026, 10, 31, 9, 15, 0),
    updatedAt: DateTime(2026, 10, 31, 9, 40, 30),
    phase: 5,
    phaseCount: 7,
    phaseLabel: 'images.exe',
    status: status,
    fileCount: 12,
    updates: 14,
    user: 'carla',
    collection: 'archief',
    computer: 'PC-CARLA',
    appVersion: '1.2.3',
    ip: '203.0.113.7',
    source: source,
  );

  final List<AppLogFilter> appLogFilters = [];
  final List<String?> appLogBefore = [];

  @override
  Future<List<AppLogOverviewRow>> appLogOverview(
    AdminIdentity identity,
  ) async => [
    AppLogOverviewRow(
      source: 'hkh',
      computer: 'FILESERVER',
      appVersion: '0.0.1+20261031.1405',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      lines24h: 120,
      warnings24h: 3,
      errors24h: 1,
    ),
    AppLogOverviewRow(
      source: 'macbook',
      computer: 'MAC-ROBBERT',
      appVersion: '0.0.1+20261030.0900',
      lastSeen: DateTime.now().subtract(const Duration(days: 3)),
      lines24h: 0,
      warnings24h: 0,
      errors24h: 0,
    ),
  ];

  @override
  Future<List<String>> appLogVersions(AdminIdentity identity) async => [
    '0.0.1+20261031.1405',
    '0.0.1+20261030.0900',
  ];

  @override
  Future<AppLogPage> appLogs(
    AdminIdentity identity,
    AppLogFilter filter, {
    String? before,
  }) async {
    appLogFilters.add(filter);
    appLogBefore.add(before);
    if (before != null) {
      return AppLogPage(
        items: [
          AppLogEntry(
            id: 1,
            time: DateTime(2026, 10, 31, 8, 0, 0),
            level: 'INFO',
            logger: 'nl.vdzon.hkhworkflow.Main',
            message: 'Oudere regel',
            source: 'hkh',
            computer: 'FILESERVER',
          ),
        ],
      );
    }
    return AppLogPage(
      items: [
        AppLogEntry(
          id: 3,
          time: DateTime(2026, 10, 31, 14, 5, 11),
          level: 'ERROR',
          logger: 'nl.vdzon.hkhworkflow.testrun.TestRunService',
          message:
              'FTP mislukt\n\tat nl.vdzon.Foo.bar(Foo.kt:12)\n\tat x.Y.z(Y.kt:1)',
          source: 'hkh',
          computer: 'FILESERVER',
          appVersion: '0.0.1+20261031.1405',
        ),
        AppLogEntry(
          id: 2,
          time: DateTime(2026, 10, 31, 14, 0, 0),
          level: 'INFO',
          logger: 'Main',
          message: '<b>geen html</b> gestart',
          source: 'hkh',
          computer: 'FILESERVER',
        ),
      ],
      next: 'cursor-1',
    );
  }

  @override
  Future<List<String>> sources(AdminIdentity identity) async => [
    'macbook',
    'windows-laptop',
  ];

  @override
  Future<List<WorkflowLoginEntry>> logins(
    AdminIdentity identity, {
    String? source,
  }) async => [
    WorkflowLoginEntry(
      id: 2,
      createdAt: DateTime(2026, 10, 31, 9, 0, 1),
      success: false,
      method: 'PASSWORD',
      user: 'onbekend',
      detail: 'Wachtwoord klopt niet',
      ip: '198.51.100.4',
      source: 'windows-laptop',
    ),
    WorkflowLoginEntry(
      id: 1,
      createdAt: DateTime(2026, 10, 31, 8, 0, 1),
      success: true,
      method: 'COOKIE',
      user: 'carla',
      computer: 'PC-CARLA',
    ),
  ];

  @override
  Future<List<WorkflowSessionSummary>> sessions(
    AdminIdentity identity,
    WorkflowKind kind, {
    String? source,
  }) async {
    kinds.add(kind);
    asked.add(source);
    return kind == WorkflowKind.newFiles
        ? [_summary(_sessionId, 'NEW_FILES', 'ABANDONED')]
        : [_summary('11111111-2222-3333-4444-555555555555', 'EDIT', 'RUNNING')];
  }

  @override
  Future<WorkflowSessionDetail> session(
    AdminIdentity identity,
    String id,
  ) async {
    opened.add(id);
    return WorkflowSessionDetail(
      summary: _summary(id, 'NEW_FILES', 'RUNNING'),
      snapshot: {
        'instellingen': {'ftpHost': 'ftp.example.org'},
        'bestanden': ['a.pdf', 'b.pdf'],
        'consoles': {'images': 'regel 1\nregel 2'},
      },
      events: [
        WorkflowEvent(
          createdAt: DateTime(2026, 10, 31, 9, 15, 0),
          phase: 1,
          status: 'RUNNING',
          message: 'Sessie gestart',
        ),
        WorkflowEvent(
          createdAt: DateTime(2026, 10, 31, 9, 30, 0),
          phase: 5,
          phaseLabel: 'images.exe',
          status: 'RUNNING',
          message: 'images.exe gestart',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('the administrator reads logins and sessions and opens one', (
    tester,
  ) async {
    final source = _WorkflowSource();
    await tester.binding.setSurfaceSize(const Size(1800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        workflowLogSource: source,
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('admin-tile-workflow-logboek'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // Standaard de aangemaakte doorlopen; een lang stille doorloop is verlaten.
    expect(find.text('HKH Beheer · Workflow-logboek'), findsOneWidget);
    expect(find.byKey(const Key('workflow-session-table')), findsOneWidget);
    expect(find.text('5 van 7: images.exe'), findsOneWidget);
    expect(find.text('verlaten'), findsOneWidget);
    expect(find.text('carla'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('macbook'), findsOneWidget);

    // Filteren op bron: de lijst wordt opnieuw gevraagd met de gekozen bron.
    await tester.tap(find.byKey(const Key('workflow-log-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('windows-laptop').last);
    await tester.pumpAndSettle();
    expect(source.asked, [null, 'windows-laptop']);
    await tester.tap(find.byKey(const Key('workflow-log-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle bronnen').last);
    await tester.pumpAndSettle();
    expect(source.asked, [null, 'windows-laptop', null]);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('workflow-log-tabs')),
        matching: find.text('Aangepast'),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.kinds, [
      WorkflowKind.newFiles,
      WorkflowKind.newFiles,
      WorkflowKind.newFiles,
      WorkflowKind.edit,
    ]);
    expect(find.text('bezig'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('workflow-log-tabs')),
        matching: find.text('Inloggen'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workflow-login-table')), findsOneWidget);
    expect(find.text('mislukt'), findsOneWidget);
    expect(find.text('gelukt'), findsOneWidget);
    expect(find.text('Wachtwoord klopt niet'), findsOneWidget);
    expect(find.text('cookie'), findsOneWidget);

    // Terug naar de aangemaakte doorlopen en één openen.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('workflow-log-tabs')),
        matching: find.text('Aangemaakt'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 van 7: images.exe'));
    await tester.pumpAndSettle();
    expect(source.opened, [_sessionId]);
    expect(
      find.text('HKH Beheer · Doorloop van de workflow-app'),
      findsOneWidget,
    );
    expect(find.text('Sessie gestart  ·  '), findsNothing);
    expect(find.textContaining('images.exe gestart'), findsOneWidget);
    expect(find.text('consoles (1)'), findsOneWidget);
    await tester.tap(find.text('consoles (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('regel 2'), findsOneWidget);

    // De terugknop gaat naar het logboek, niet naar het overzicht.
    await tester.tap(find.byKey(const Key('admin-back')));
    await tester.pumpAndSettle();
    expect(find.text('HKH Beheer · Workflow-logboek'), findsOneWidget);
  });

  testWidgets('the administrator reads the app log, filters it and loads more', (
    tester,
  ) async {
    final source = _WorkflowSource();
    await tester.binding.setSurfaceSize(const Size(1800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        workflowLogSource: source,
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('admin-tile-workflow-logboek'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('workflow-log-tabs')),
        matching: find.text('App-log'),
      ),
    );
    await tester.pumpAndSettle();

    // Het overzicht per computer: een computer zonder melding in 24 uur is grijs.
    expect(find.byKey(const Key('app-log-overview')), findsOneWidget);
    expect(find.text('FILESERVER'), findsWidgets);
    expect(find.text('MAC-ROBBERT'), findsWidgets);
    expect(
      tester.widget<Text>(find.text('MAC-ROBBERT').first).style?.color,
      Colors.black38,
    );
    expect(
      tester.widget<Text>(find.text('FILESERVER').first).style?.color,
      isNull,
    );

    // De regels: niveau, ingekorte logger, versie, platte tekst en een opgeklapte stacktrace.
    final lines = find.byKey(const Key('app-log-lines'));
    expect(lines, findsOneWidget);
    expect(
      find.textContaining('n.v.h.t.TestRunService', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('<b>geen html</b> gestart', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Foo.kt:12', findRichText: true), findsNothing);
    expect(find.text('▸ 2 regels meer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-log-expand-3')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Foo.kt:12', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('▾ inklappen'), findsOneWidget);

    // Meer laden voegt de oudere regels toe met de cursor.
    expect(source.appLogBefore, [null]);
    await tester.ensureVisible(find.byKey(const Key('app-log-more')));
    await tester.tap(find.byKey(const Key('app-log-more')));
    await tester.pumpAndSettle();
    expect(source.appLogBefore, [null, 'cursor-1']);
    expect(
      find.textContaining('Oudere regel', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-log-more')), findsNothing);

    // Filteren op niveau vraagt de lijst opnieuw met dat minimumniveau.
    await tester.tap(find.byKey(const Key('app-log-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waarschuwingen en fouten').last);
    await tester.pumpAndSettle();
    expect(source.appLogFilters.last.level, 'WARN');
    expect(source.appLogBefore.last, isNull);

    // Zoeken op tekst.
    await tester.enterText(find.byKey(const Key('app-log-query')), ' ftp ');
    await tester.tap(find.byKey(const Key('app-log-search')));
    await tester.pumpAndSettle();
    expect(source.appLogFilters.last.query, ' ftp ');
    expect(source.appLogFilters.last.level, 'WARN');

    // Een computer in het overzicht kiezen filtert op die bron en computer.
    await tester.tap(find.text('MAC-ROBBERT').first);
    await tester.pumpAndSettle();
    expect(source.appLogFilters.last.source, 'macbook');
    expect(source.appLogFilters.last.computer, 'MAC-ROBBERT');
  });

  test(
    'the client asks for the app log with the chosen filters and reads the answer',
    () async {
      final urls = <Uri>[];
      final client = AdminWorkflowLogClient(
        'https://api.example',
        client: MockClient((request) async {
          urls.add(request.url);
          expect(request.headers['Authorization'], 'Bearer synthetic-admin');
          if (request.url.path.endsWith('/app-logs/overview')) {
            return http.Response(
              '[{"source":"hkh","computer":"FILESERVER","appVersion":"1.0","lastSeen":"2026-10-31T13:05:00Z","lines24h":5,"warnings24h":1,"errors24h":2}]',
              200,
            );
          }
          if (request.url.path.endsWith('/app-logs/versions')) {
            return http.Response('["1.0","0.9"]', 200);
          }
          return http.Response(
            '{"items":[{"id":7,"time":"2026-10-31T13:05:11.123Z","level":"WARN","logger":"a.B","message":"hallo","source":"hkh","computer":"FILESERVER","appVersion":"1.0"}],"next":"abc"}',
            200,
          );
        }),
      );
      const identity = AdminIdentity(
        'admin',
        requestHeaders: {'Authorization': 'Bearer synthetic-admin'},
      );
      final overview = await client.appLogOverview(identity);
      expect(overview.single.errors24h, 2);
      expect(overview.single.appVersion, '1.0');
      expect(await client.appLogVersions(identity), ['1.0', '0.9']);
      final page = await client.appLogs(
        identity,
        const AppLogFilter(
          source: 'hkh',
          level: 'WARN',
          query: ' fout ',
          version: '1.0',
        ),
        before: 'cursor',
      );
      expect(page.items.single.message, 'hallo');
      expect(page.next, 'abc');
      final query = urls.last.queryParameters;
      expect(urls.last.path, '/api/admin/workflow-log/app-logs');
      expect(query, {
        'limit': '200',
        'source': 'hkh',
        'level': 'WARN',
        'version': '1.0',
        'q': 'fout',
        'before': 'cursor',
      });
    },
  );

  test('the session address is recognised and other addresses are not', () {
    expect(
      AdminPaths.workflowSessionId('/workflow-logboek/$_sessionId'),
      _sessionId,
    );
    expect(AdminPaths.workflowSessionId('/workflow-logboek/niet'), isNull);
    expect(AdminPaths.workflowSessionId('/workflow-logboek'), isNull);
    expect(
      AdminPaths.normalise('/workflow-logboek/$_sessionId'),
      '/workflow-logboek/$_sessionId',
    );
    expect(AdminPaths.normalise('/workflow-logboek/x'), AdminPaths.start);
    expect(AdminPaths.normalise('/workflow-logboek'), AdminPaths.workflowLog);
  });
}
