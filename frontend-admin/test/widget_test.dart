import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_admin/auth/admin_session.dart';
import 'package:hkh_admin/main.dart';
import 'package:hkh_admin/news/admin_latest_news.dart';
import 'package:hkh_admin/ai/admin_ai_model.dart';
import 'package:hkh_admin/collection/admin_collection_scrape.dart';

class _NewsSource implements AdminLatestNewsSource {
  String? title;
  String? message;

  @override
  Future<void> create({
    required AdminIdentity identity,
    required String title,
    required String message,
  }) async {
    this.title = title;
    this.message = message;
  }
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

  AiModelState _state({AiRole role = AiRole.agent}) => AiModelState(
    role: role,
    method: method,
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
  testWidgets('shows the verified administrator', (tester) async {
    final newsSource = _NewsSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        newsSource: newsSource,
        scrapeSource: _ScrapeSource(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beheerder geverifieerd'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Nieuw bericht'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Dorpsnieuws');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Een historisch bericht.',
    );
    await tester.ensureVisible(find.text('Publiceren'));
    await tester.tap(find.text('Publiceren'));
    await tester.pumpAndSettle();

    expect(newsSource.title, 'Dorpsnieuws');
    expect(newsSource.message, 'Een historisch bericht.');
    expect(find.text('Het nieuwsbericht is gepubliceerd.'), findsOneWidget);
  });

  testWidgets('explains when Google login is not configured', (tester) async {
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: const DisabledAdminSessionSource(),
        newsSource: _NewsSource(),
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
        newsSource: _NewsSource(),
        scrapeSource: scrapeSource,
      ),
    );
    await tester.pumpAndSettle();

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
        newsSource: _NewsSource(),
        scrapeSource: scrapeSource,
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('scrape-cards'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scrapeSource.started, [ScrapeMode.cards]);
    expect(find.text('Laatste run: bezig (AI-kaarten)'), findsOneWidget);
  });

  testWidgets('the administrator can switch the AI model and go back', (
    tester,
  ) async {
    final aiModelSource = _AiModelSource();
    await tester.pumpWidget(
      HkhAdminApp(
        sessionSource: _AuthenticatedSession(),
        newsSource: _NewsSource(),
        scrapeSource: _ScrapeSource(),
        aiModelSource: aiModelSource,
      ),
    );
    await tester.pumpAndSettle();

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
        newsSource: _NewsSource(),
        scrapeSource: _ScrapeSource(),
        aiModelSource: aiModelSource,
      ),
    );
    await tester.pumpAndSettle();

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
  });
}
