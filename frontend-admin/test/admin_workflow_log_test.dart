import 'package:flutter/material.dart';
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
