import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/main.dart';
import 'package:hkh_admin/dashboard/admin_dashboard.dart';
import 'package:hkh_admin/shell/admin_router.dart';
import 'package:hkh_admin/ai/admin_ai_model.dart';
import 'package:hkh_admin/ai/admin_ai_research.dart';
import 'package:hkh_admin/collection/admin_collection_scrape.dart';
import 'package:hkh_admin/requests/admin_request_log.dart';

class _DashboardSource implements AdminDashboardSource {
  int loads = 0;
  bool failing = false;

  @override
  Future<DashboardData> load(AdminIdentity identity) async {
    loads++;
    if (failing) throw StateError('Overzicht laden mislukt (503)');
    return DashboardData(
      ai: const DashboardAi(
        method: 'PIPELINE',
        roles: [
          DashboardRole(label: 'Agent', model: 'claude-haiku-5-5'),
          DashboardRole(label: 'Richten', model: 'claude-sonnet-5-5'),
          DashboardRole(label: 'Schrijven', model: 'claude-sonnet-5-5'),
        ],
        writeBudgetChars: 450000,
        runtimeConfigured: true,
        runtimeReachable: true,
        workersOnline: 1,
      ),
      collection: DashboardCollection(
        totalRecords: 23194,
        running: false,
        cardsDone: 23142,
        cardsFailed: 52,
        cardsPending: 0,
        lastRun: DashboardRun(
          status: 'COMPLETED',
          mode: 'CARDS',
          startedAt: DateTime(2026, 10, 20, 4, 0),
          finishedAt: DateTime(2026, 10, 20, 4, 39),
          failed: 52,
        ),
      ),
      today: const UsagePeriod(
        aiQuestions: 3,
        expansions: 1,
        searches: 9,
        uniqueVisitors: 6,
        testVisitors: 2,
        testRequests: 4,
        botRequests: 7,
        failed: 1,
        costUsd: 0.84,
        averageAnswerMs: 95000,
      ),
      last7Days: const UsagePeriod(uniqueVisitors: 31, aiQuestions: 20),
      last30Days: const UsagePeriod(uniqueVisitors: 80, aiQuestions: 64),
      retentionDays: 30,
    );
  }
}

/// Opent een onderdeel vanaf de startpagina via zijn tegel.
Future<void> _open(WidgetTester tester, String tile) async {
  final finder = find.byKey(Key('admin-tile-$tile'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _ScrapeSource implements AdminScrapeSource {
  final List<ScrapeMode> started = [];
  ScrapeStatus? current;
  @override
  Future<ScrapeStatus?> loadStatus(AdminIdentity identity) async => current;
  @override
  Future<ScrapeStatus> start({
    required AdminIdentity identity,
    required ScrapeMode mode,
    required bool force,
  }) async {
    started.add(mode);
    return current = ScrapeStatus.fromJson({
      'status': 'RUNNING',
      'running': true,
      'mode': mode.apiValue,
      'total': 0,
      'processed': 0,
      'skipped': 0,
      'failed': 0,
    });
  }

  int stops = 0;
  @override
  Future<ScrapeStatus?> stop(AdminIdentity identity) async {
    stops++;
    final c = current;
    if (c == null) return null;
    return current = ScrapeStatus.fromJson({
      'status': 'FAILED',
      'running': false,
      'mode': c.mode.apiValue,
      'total': c.total,
      'processed': c.processed,
      'skipped': 0,
      'failed': 0,
      'message': 'Gestopt door de beheerder',
    });
  }
}

class _AiModelSource implements AdminAiModelSource {
  AiExecution current = const AiExecution(
    vendorId: 'anthropic',
    model: 'claude-sonnet-5-5',
    mode: 'SUBSCRIPTION',
    label: 'anthropic · claude-sonnet-5-5 · subscription',
  );
  bool fromSetting = false;
  final List<AiExecution> selected = [];
  final List<AiRole> selectedRoles = [];
  final List<AiRole> loadedRoles = [];
  AiResearchMethod method = AiResearchMethod.agent;
  int? writeBudget;

  AiModelState _state({AiRole role = AiRole.agent}) => AiModelState(
    role: role,
    method: method,
    writeBudgetChars: writeBudget ?? 450000,
    writeBudgetFromSetting: writeBudget != null,
    writeBudgetDefault: 450000,
    roles: [
      for (final each in AiRole.values)
        AiRoleModel(role: each, current: current, fromSetting: fromSetting),
    ],
    current: current,
    fromSetting: fromSetting,
    updatedAt: null,
    updatedBy: fromSetting ? 'admin@example.com' : null,
    options: const [
      AiModelOption(
        execution: AiExecution(
          vendorId: 'anthropic',
          model: 'claude-opus-5',
          mode: 'SUBSCRIPTION',
          label: 'anthropic · claude-opus-5 · subscription',
        ),
        available: true,
        onlineWorkers: 1,
      ),
      AiModelOption(
        execution: AiExecution(
          vendorId: 'anthropic',
          model: 'claude-sonnet-5-5',
          mode: 'SUBSCRIPTION',
          label: 'anthropic · claude-sonnet-5-5 · subscription',
        ),
        available: true,
        onlineWorkers: 1,
      ),
    ],
    catalogError: null,
  );

  @override
  Future<AiModelState> load(
    AdminIdentity identity, {
    AiRole role = AiRole.agent,
  }) async {
    loadedRoles.add(role);
    return _state(role: role);
  }

  @override
  Future<AiModelState> select(
    AdminIdentity identity,
    AiExecution execution, {
    AiRole role = AiRole.agent,
  }) async {
    selected.add(execution);
    selectedRoles.add(role);
    current = execution;
    fromSetting = true;
    return _state(role: role);
  }

  @override
  Future<AiModelState> reset(
    AdminIdentity identity, {
    AiRole role = AiRole.agent,
  }) async {
    fromSetting = false;
    current = const AiExecution(
      vendorId: 'anthropic',
      model: 'claude-sonnet-5-5',
      mode: 'SUBSCRIPTION',
      label: 'anthropic · claude-sonnet-5-5 · subscription',
    );
    return _state(role: role);
  }

  @override
  Future<AiModelState> selectMethod(
    AdminIdentity identity,
    AiResearchMethod method,
  ) async {
    this.method = method;
    return _state();
  }

  @override
  Future<AiModelState> selectWriteBudget(
    AdminIdentity identity,
    int chars,
  ) async {
    writeBudget = chars;
    return _state(role: AiRole.writer);
  }

  @override
  Future<AiModelState> resetWriteBudget(AdminIdentity identity) async {
    writeBudget = null;
    return _state(role: AiRole.writer);
  }
}

class _RequestLogSource implements AdminRequestLogSource {
  final List<int> limits = [];

  @override
  Future<List<RequestLogEntry>> recent(
    AdminIdentity identity, {
    int limit = 200,
  }) async {
    limits.add(limit);
    return [
      RequestLogEntry(
        id: 4,
        createdAt: DateTime(2026, 10, 20, 18, 10, 0),
        kind: 'AI_QUESTION',
        question: 'testvraag over de touwslagerij',
        expansion: false,
        status: 'SUCCEEDED',
        ip: '198.51.100.7',
        userAgent: 'HKH-Test/claude',
        test: true,
        model: 'anthropic/claude-sonnet-5-5',
        firstFeedbackMs: 35000,
        answerMs: 108000,
        costUsd: 0.02,
      ),
      RequestLogEntry(
        id: 3,
        createdAt: DateTime(2026, 10, 20, 18, 7, 0),
        kind: 'COLLECTION_SEARCH',
        question: 'Grard',
        collection: 'beeldbank',
        expansion: false,
        status: 'SUCCEEDED',
        ip: '198.51.100.9',
        ipAnonymized: true,
        userAgent: 'curl/8.7.1',
        bot: true,
        firstFeedbackMs: 12,
        answerMs: 12,
      ),
      RequestLogEntry(
        id: 2,
        createdAt: DateTime(2026, 10, 20, 18, 5, 0),
        kind: 'AI_QUESTION',
        question: 'Werk het antwoord volledig uit',
        expansion: true,
        status: 'SUCCEEDED',
        ip: '203.0.113.7',
        userEmail: 'robbert@example.com',
        userAgent: 'Mozilla/5.0 (Macintosh) Chrome/130',
        model: 'anthropic/claude-sonnet-5-5',
        firstFeedbackMs: 95000,
        answerMs: 311000,
        costUsd: 0.46,
      ),
      RequestLogEntry(
        id: 1,
        createdAt: DateTime(2026, 10, 20, 18, 0, 0),
        kind: 'COLLECTION_SEARCH',
        question: 'Oostrum',
        collection: 'beeldbank',
        expansion: false,
        status: 'SUCCEEDED',
        ip: '203.0.113.7',
        userAgent: 'Mozilla/5.0 (Macintosh) Chrome/130',
        firstFeedbackMs: 42,
        answerMs: 42,
      ),
    ];
  }
}

class _AiResearchSource implements AdminAiResearchSource {
  final List<AiBenchmarkQuestion> questions = [];
  bool running = false;
  int runs = 0;

  AiBenchmarkState _state() =>
      AiBenchmarkState(questions: List.of(questions), running: running);

  @override
  Future<List<AiTurnComparison>> turns(
    AdminIdentity identity, {
    int limit = 40,
  }) async => [
    AiTurnComparison(
      id: 't1',
      question: 'Wie waren Toos en Ciska Oostrum?',
      title: 'De tweelingjuffen',
      status: 'SUCCEEDED',
      depth: 'THOROUGH',
      method: 'PIPELINE',
      createdAt: DateTime(2026, 10, 18, 12, 0),
      durationSeconds: 245,
      rounds: 3,
      sourceCount: 41,
      models: ['anthropic/claude-sonnet-5-5', 'anthropic/claude-opus-5-5'],
      jobs: 5,
      inputTokens: 312000,
      outputTokens: 14000,
      costUsd: 0.85,
      askedBy: 'robbert@example.com',
      benchmarkQuestionId: null,
      errorMessage: null,
    ),
  ];

  @override
  Future<AiBenchmarkState> benchmark(AdminIdentity identity) async => _state();

  @override
  Future<AiBenchmarkState> addQuestion(
    AdminIdentity identity,
    String question,
    String depth,
  ) async {
    questions.add(
      AiBenchmarkQuestion(
        id: questions.length + 1,
        question: question,
        depth: depth,
      ),
    );
    return _state();
  }

  @override
  Future<AiBenchmarkState> deleteQuestion(
    AdminIdentity identity,
    int id,
  ) async {
    questions.removeWhere((q) => q.id == id);
    return _state();
  }

  @override
  Future<AiBenchmarkState> runBenchmark(AdminIdentity identity) async {
    runs++;
    running = true;
    return _state();
  }
}

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

void main() {
  testWidgets('the start page shows status and opens the sections', (
    tester,
  ) async {
    final dashboard = _DashboardSource();
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        aiModelSource: _AiModelSource(),
        aiResearchSource: _AiResearchSource(),
        requestLogSource: _RequestLogSource(),
        dashboardSource: dashboard,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Beheerder geverifieerd · admin@example.com'),
      findsOneWidget,
    );
    expect(find.text('Nieuw bericht'), findsNothing);
    // Gebruik: unieke bezoekers met testverkeer apart, tijden, kosten, bots.
    expect(find.byKey(const Key('admin-usage-table')), findsOneWidget);
    expect(find.text('6 (waarvan 2 test)'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1:35'), findsOneWidget);
    expect(find.text('\$0.84'), findsOneWidget);
    expect(find.text('Bots (niet meegeteld)'), findsOneWidget);
    // Aandacht voor wat misgaat.
    expect(find.text('1 AI-vraag mislukt vandaag.'), findsOneWidget);
    // Een tegel per onderdeel, met statusregels.
    expect(find.text('23.194 records'), findsOneWidget);
    expect(
      find.text('AI-kaarten: 23.142 klaar, 52 mislukt, 0 te doen'),
      findsOneWidget,
    );
    expect(find.text('Methode: pijplijn'), findsOneWidget);
    expect(
      find.text('Richten: claude-sonnet-5-5 · Schrijven: claude-sonnet-5-5'),
      findsOneWidget,
    );
    expect(find.text('Runtime bereikbaar, 1 worker online'), findsOneWidget);
    expect(find.byKey(const Key('admin-tile-ai-vergelijken')), findsOneWidget);
    expect(find.byKey(const Key('admin-tile-logboek')), findsOneWidget);

    // Een tegel opent het onderdeel; de terugknop brengt je terug.
    await _open(tester, 'collectie');
    expect(find.text('HKH Beheer · Collectie'), findsOneWidget);
    expect(find.byKey(const ValueKey('scrape-cards')), findsOneWidget);
    expect(find.byKey(const Key('admin-usage-table')), findsNothing);
    await tester.tap(find.byKey(const Key('admin-back')));
    await tester.pumpAndSettle();
    expect(find.text('HKH Beheer'), findsOneWidget);
    expect(find.byKey(const Key('admin-tile-collectie')), findsOneWidget);
  });

  testWidgets('the start page keeps its buttons when the status fails', (
    tester,
  ) async {
    final dashboard = _DashboardSource()..failing = true;
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        requestLogSource: _RequestLogSource(),
        dashboardSource: dashboard,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overzicht laden mislukt (503)'), findsOneWidget);
    expect(find.byKey(const Key('admin-tile-collectie')), findsOneWidget);
    expect(find.byKey(const Key('admin-tile-logboek')), findsOneWidget);
    // Zonder modelbron ontbreken de AI-tegels.
    expect(find.byKey(const Key('admin-tile-ai-instellingen')), findsNothing);

    dashboard.failing = false;
    await tester.tap(find.byKey(const Key('dashboard-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Overzicht laden mislukt (503)'), findsNothing);
    expect(dashboard.loads, 2);
  });

  testWidgets('a deep link opens the section and unknown addresses fall back', (
    tester,
  ) async {
    Future<void> openAt(String route) async {
      tester.platformDispatcher.defaultRouteNameTestValue = route;
      await tester.pumpWidget(
        HkhAdminApp(
          sessionSource: _AuthenticatedSession(),
          scrapeSource: _ScrapeSource(),
          requestLogSource: _RequestLogSource(),
          dashboardSource: _DashboardSource(),
        ),
      );
      await tester.pumpAndSettle();
    }

    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.binding.setSurfaceSize(const Size(1800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openAt('/logboek');
    expect(find.text('HKH Beheer · Logboek van verzoeken'), findsOneWidget);
    expect(find.byKey(const Key('request-log-table')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await openAt('/bestaat-niet');
    expect(find.text('HKH Beheer'), findsOneWidget);
    expect(find.byKey(const Key('admin-usage-table')), findsOneWidget);
    expect(AdminPaths.normalise('/collectie/'), AdminPaths.collection);
    expect(AdminPaths.normalise('/x'), AdminPaths.start);
  });

  testWidgets('explains when Google login is not configured', (tester) async {
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: const DisabledAdminSessionSource(),
        scrapeSource: _ScrapeSource(),
        googleButtonBuilder: () => const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Google-login is nog niet geconfigureerd.'),
      findsOneWidget,
    );
  });

  testWidgets('the document text button starts a text-only run', (
    tester,
  ) async {
    final scrapeSource = _ScrapeSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: scrapeSource,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'collectie');

    final button = find.byKey(const ValueKey('scrape-text'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    // Een lopende run toont een doorlopende voortgangsbalk; niet wachten tot alles stilstaat.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scrapeSource.started, [ScrapeMode.text]);
    expect(find.text('Laatste run: bezig (documenttekst)'), findsOneWidget);
    expect(find.text('Bezig met ophalen (documenttekst)…'), findsOneWidget);
  });

  testWidgets('the AI cards button starts a cards-only run', (tester) async {
    final scrapeSource = _ScrapeSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: scrapeSource,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'collectie');

    final button = find.byKey(const ValueKey('scrape-cards'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scrapeSource.started, [ScrapeMode.cards]);
    expect(find.text('Laatste run: bezig (AI-kaarten)'), findsOneWidget);

    // Een lopende run is te stoppen; daarna is de startknop weer vrij.
    final stop = find.byKey(const ValueKey('scrape-stop'));
    await tester.ensureVisible(stop);
    await tester.pump();
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(scrapeSource.stops, 1);
    expect(find.byKey(const ValueKey('scrape-stop')), findsNothing);
    expect(find.text('Laatste run: mislukt (AI-kaarten)'), findsOneWidget);
  });

  testWidgets('the administrator can switch the AI model and go back', (
    tester,
  ) async {
    final aiModelSource = _AiModelSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        aiModelSource: aiModelSource,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'ai-instellingen');

    expect(
      find.textContaining(
        'Nu actief voor agent: anthropic · claude-sonnet-5-5',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('(uit de configuratie)'), findsOneWidget);
    final save = find.byKey(const Key('ai-model-save'));
    expect(tester.widget<FilledButton>(save).enabled, isFalse);

    await tester.ensureVisible(find.byKey(const Key('ai-model-select')));
    await tester.tap(find.byKey(const Key('ai-model-select')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('anthropic · claude-opus-5 · subscription').last,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).enabled, isTrue);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(aiModelSource.selected.single.model, 'claude-opus-5');
    expect(aiModelSource.selectedRoles, [AiRole.agent]);
    expect(
      find.textContaining('Nu actief voor agent: anthropic · claude-opus-5'),
      findsOneWidget,
    );
    expect(find.text('Het model is gewijzigd.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-model-reset')));
    await tester.pumpAndSettle();
    expect(find.textContaining('(uit de configuratie)'), findsOneWidget);
  });

  testWidgets('the administrator switches the research method and a role', (
    tester,
  ) async {
    final aiModelSource = _AiModelSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        aiModelSource: aiModelSource,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'ai-instellingen');

    await tester.ensureVisible(find.byKey(const Key('ai-method-select')));
    await tester.tap(find.text('Pijplijn'));
    await tester.pumpAndSettle();
    expect(aiModelSource.method, AiResearchMethod.pipeline);
    expect(find.text('De onderzoeksmethode is gewijzigd.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('ai-role-select')));
    await tester.tap(find.byKey(const Key('ai-role-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schrijven').last);
    await tester.pumpAndSettle();
    expect(aiModelSource.loadedRoles.last, AiRole.writer);
    expect(
      find.textContaining(
        'Nu actief voor schrijven: anthropic · claude-sonnet-5-5',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('ai-model-select')));
    await tester.tap(find.byKey(const Key('ai-model-select')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('anthropic · claude-opus-5 · subscription').last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-model-save')));
    await tester.pumpAndSettle();
    expect(aiModelSource.selectedRoles, [AiRole.writer]);

    // Bij de rol Schrijven is het tekstbudget in te stellen en terug te zetten.
    await tester.ensureVisible(find.byKey(const Key('ai-write-budget')));
    expect(
      find.textContaining('Nu: 450.000 tekens (standaard voor dit model)'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('ai-write-budget')), '250000');
    await tester.ensureVisible(find.byKey(const Key('ai-write-budget-save')));
    await tester.tap(find.byKey(const Key('ai-write-budget-save')));
    await tester.pumpAndSettle();
    expect(aiModelSource.writeBudget, 250000);
    expect(
      find.textContaining('Nu: 250.000 tekens (door een beheerder gekozen)'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('ai-write-budget-reset')));
    await tester.tap(find.byKey(const Key('ai-write-budget-reset')));
    await tester.pumpAndSettle();
    expect(aiModelSource.writeBudget, isNull);
  });

  testWidgets('the administrator reads and filters the request log', (
    tester,
  ) async {
    final logSource = _RequestLogSource();
    await tester.binding.setSurfaceSize(const Size(1800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        scrapeSource: _ScrapeSource(),
        requestLogSource: logSource,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'logboek');

    expect(find.text('HKH Beheer · Logboek van verzoeken'), findsOneWidget);
    expect(find.byKey(const Key('request-log-table')), findsOneWidget);
    expect(find.text('AI (uitwerking)'), findsOneWidget);
    expect(find.text('Collectie: beeldbank'), findsOneWidget);
    expect(find.text('203.0.113.7'), findsNWidgets(2));
    expect(find.text('robbert@example.com'), findsOneWidget);
    expect(find.text('1:35'), findsOneWidget);
    expect(find.text('5:11'), findsOneWidget);
    expect(find.text('42 ms'), findsNWidgets(2));
    expect(find.text('\$0.46'), findsOneWidget);
    expect(find.text('Mozilla/5.0 (Macintosh) Chrome/130'), findsNWidgets(2));
    expect(logSource.limits, [200]);

    // Bots zijn standaard verborgen, testverkeer is zichtbaar en gemarkeerd.
    expect(find.byKey(const Key('request-log-count')), findsOneWidget);
    expect(find.text('3 van 4 regels'), findsOneWidget);
    expect(find.text('curl/8.7.1'), findsNothing);
    expect(find.text('test'), findsOneWidget);
    await tester.tap(find.byKey(const Key('request-log-bots')));
    await tester.pumpAndSettle();
    expect(find.text('4 van 4 regels'), findsOneWidget);
    expect(find.text('curl/8.7.1'), findsOneWidget);
    expect(find.text('198.51.100.9 *'), findsOneWidget);
    expect(find.text('bot'), findsOneWidget);

    // Testverkeer is uit te zetten en de soort te filteren.
    await tester.tap(find.byKey(const Key('request-log-test')));
    await tester.pumpAndSettle();
    expect(find.text('3 van 4 regels'), findsOneWidget);
    expect(find.text('test'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('request-log-kind')),
        matching: find.text('Collectie'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 van 4 regels'), findsOneWidget);
    expect(find.text('AI (uitwerking)'), findsNothing);
  });

  testWidgets(
    'the administrator manages the test set and sees the comparison',
    (tester) async {
      final researchSource = _AiResearchSource();
      await tester.pumpWidget(
        HkhAdminApp(
          sessionSource: _AuthenticatedSession(),
          scrapeSource: _ScrapeSource(),
          aiResearchSource: researchSource,
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester, 'ai-vergelijken');

      await tester.ensureVisible(find.byKey(const Key('ai-research-table')));
      expect(find.text('De tweelingjuffen'), findsOneWidget);
      expect(find.text('pijplijn'), findsOneWidget);
      expect(find.text('4 min 5 s'), findsOneWidget);
      expect(find.text('claude-sonnet-5-5, claude-opus-5-5'), findsOneWidget);
      expect(find.text('312.0k / 14.0k'), findsOneWidget);
      expect(find.text('\$0.85'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('benchmark-run')))
            .enabled,
        isFalse,
      );

      await tester.ensureVisible(find.byKey(const Key('benchmark-question')));
      await tester.enterText(
        find.byKey(const Key('benchmark-question')),
        'Wie was burgemeester Nielen?',
      );
      await tester.ensureVisible(find.byKey(const Key('benchmark-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('benchmark-add')));
      await tester.pumpAndSettle();
      expect(
        researchSource.questions.single.question,
        'Wie was burgemeester Nielen?',
      );
      expect(find.text('Vraag toegevoegd.'), findsOneWidget);
      expect(
        find.textContaining('snel · Wie was burgemeester Nielen?'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('benchmark-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('benchmark-run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(researchSource.runs, 1);
      expect(find.text('Testset draait…'), findsOneWidget);
    },
  );
}
