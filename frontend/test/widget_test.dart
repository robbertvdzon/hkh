import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hkh_app/theme/app_style.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/auth/user_session.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/main.dart';

import 'dossier_test_support.dart';

class _SignedInSession extends UserSessionController {
  UserIdentity? _identity = const UserIdentity(
    email: 'jan@example.com',
    displayName: 'Jan Jansen',
    isAdmin: false,
    token: 'sess-1',
  );
  int signOutCalls = 0;
  void loginAs(String email) {
    _identity = UserIdentity(
      email: email,
      isAdmin: false,
      token: 'session-$email',
    );
    notifyListeners();
  }

  @override
  bool get configured => true;
  @override
  UserIdentity? get identity => _identity;
  @override
  bool get busy => false;
  @override
  String? get error => null;
  @override
  Future<void> bootstrap() async {}
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {
    signOutCalls++;
    _identity = null;
    notifyListeners();
  }
}

class _SearchSource implements CollectionSearchSource {
  _SearchSource({this.results = const [], this.total});

  final List<CollectionItemSummary> results;
  final int? total;
  bool throwOnSearch = false;
  String? lastQuery;
  Map<String, String> lastFieldQueries = const {};
  int? lastYear;
  int? lastSize;
  int searchCalls = 0;

  @override
  Future<CollectionOverview> loadOverview() async =>
      const CollectionOverview(total: 0, collections: []);

  @override
  Future<SearchPage> search({
    String? query,
    String? collection,
    Map<String, String> fieldQueries = const {},
    int? year,
    int page = 0,
    int size = 20,
    CollectionSearchOptions? options,
  }) async {
    searchCalls++;
    lastQuery = query;
    lastFieldQueries = fieldQueries;
    lastYear = year;
    lastSize = size;
    if (throwOnSearch) throw StateError('backend niet bereikbaar');
    return SearchPage(
      items: results,
      total: total ?? results.length,
      page: page,
      pageSize: size,
    );
  }

  @override
  Future<CollectionFacet> loadFacet({
    required String collection,
    required String field,
    String query = '',
    Map<String, String> fieldQueries = const {},
    int? year,
    CollectionSearchOptions? options,
    String valueQuery = '',
  }) async => CollectionFacet(field: field);

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async => const CollectionItemDetail(
    collection: '',
    ident: '',
    title: '',
    description: '',
    year: null,
    imageUrl: null,
    pdfUrl: null,
    detailUrl: '',
    fields: {},
  );
}

class _AiSource implements AiSearchSource {
  final List<String> startedQuestions = [];
  int listCalls = 0;
  AiSearchSession? current;

  AiSearchSession _session(String question) => AiSearchSession(
    id: 'session-1',
    turns: [
      AiSearchTurn(
        id: 'turn-1',
        turnNumber: 1,
        question: question,
        status: 'SUCCEEDED',
        progressPercent: 100,
        progressMessage: 'Onderzoek afgerond',
        title: 'Antwoord',
        answerHtml: '<p>Gevonden antwoord.</p>',
        sources: const [],
        suggestedFollowUps: const [],
        errorMessage: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        completedAt: DateTime(2026),
        durationSeconds: 3,
      ),
    ],
  );

  @override
  Future<List<AiSearchSummary>> listAiSearches() async {
    listCalls++;
    return const [];
  }

  @override
  Future<AiSearchSession> startAiSearch(String question) async {
    startedQuestions.add(question);
    return current = _session(question);
  }

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) async => current!;

  @override
  Future<AiSearchSession> askFollowUp(
    String sessionId,
    String question,
  ) async => current!;

  @override
  Future<AiSearchSession> cancelAiSearch(String sessionId) async => current!;

  @override
  Future<void> deleteAiSearch(String sessionId) async {}
}

const _result = CollectionItemSummary(
  collection: 'beeldbank',
  ident: '10001',
  title: 'Foto Kerklaan, hoek Rijksstraatweg (1932)',
  description: 'Zwart-witfoto van de kruising.',
  year: 1932,
  imageUrl: null,
  hasPdf: false,
);

void _setViewport(
  WidgetTester tester,
  Size size, {
  double textScaleFactor = 1,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

class _AccountAiSource extends _AiSource implements AiSearchAccountSource {
  _AccountAiSource(this.session);
  final UserSessionController session;
  final syncedAccounts = <String?>[];
  final loadedAccounts = <String?>[];

  @override
  Future<void> syncAiSearchAccount() async =>
      syncedAccounts.add(session.identity?.email);

  @override
  Future<List<AiSearchSummary>> listAiSearches() async {
    loadedAccounts.add(session.identity?.email);
    return super.listAiSearches();
  }

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) async {
    if (session.identity?.email != 'jan@example.com') {
      throw StateError('Zoekopdracht niet gevonden');
    }
    return super.loadAiSearch(sessionId);
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  _SearchSource? searchSource,
  _AiSource? aiSource,
  UserSessionController? session,
  FakeDossierSource? dossierSource,
  double textScaleFactor = 1,
}) async {
  _setViewport(tester, size, textScaleFactor: textScaleFactor);
  await tester.pumpWidget(
    HkhApp(
      searchSource: searchSource ?? _SearchSource(),
      aiSearchSource: aiSource ?? _AiSource(),
      session: session,
      dossierSource: dossierSource,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'login links browser history from home and reloads history on account changes',
    (tester) async {
      final session = _SignedInSession();
      await session.signOut();
      final source = _AccountAiSource(session);
      await _pumpHome(
        tester,
        size: const Size(1000, 1100),
        aiSource: source,
        session: session,
      );
      expect(source.syncedAccounts, isEmpty);
      session.loginAs('jan@example.com');
      await tester.pumpAndSettle();
      expect(source.syncedAccounts, ['jan@example.com']);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/vragen');
      await tester.pumpAndSettle();
      expect(source.loadedAccounts.last, 'jan@example.com');
      expect(
        find.textContaining('Je vragen worden bewaard in je account.'),
        findsOneWidget,
      );
      session.loginAs('ander@example.com');
      await tester.pumpAndSettle();
      expect(source.loadedAccounts.last, 'ander@example.com');
      expect(source.syncedAccounts, ['jan@example.com', 'ander@example.com']);
      await session.signOut();
      await tester.pumpAndSettle();
      expect(source.loadedAccounts.last, isNull);
      expect(
        find.textContaining('Je vragen worden voor deze browser bewaard.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('logout removes an already open private answer', (tester) async {
    final session = _SignedInSession();
    final source = _AccountAiSource(session);
    await source.startAiSearch('Privévraag van Jan');
    await _pumpHome(
      tester,
      size: const Size(1000, 1100),
      aiSource: source,
      session: session,
    );
    expect(source.syncedAccounts, ['jan@example.com']);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/vragen?id=session-1');
    await tester.pumpAndSettle();
    expect(find.text('Privévraag van Jan'), findsOneWidget);
    await session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Privévraag van Jan'), findsNothing);
    expect(find.textContaining('Gevonden antwoord.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wide homepage has the new hierarchy, styling and spacing', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1000, 1300));

    expect(find.text('Ontdek historisch Heemskerk'), findsOneWidget);
    expect(
      find.text(
        'Stel een vraag over plekken, personen of gebeurtenissen uit de geschiedenis van Heemskerk.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.account_balance), findsNothing);
    expect(find.text('Wat wilt u weten?'), findsOneWidget);
    expect(
      find.text(
        'Stel gerust een uitgebreide onderzoeksvraag over families, relaties tussen mensen en plekken, of veranderingen door de tijd. De digitale onderzoeker zoekt de bronnen erbij; dit kan enkele minuten duren.',
      ),
      findsOneWidget,
    );
    expect(find.text('Zelf zoeken in de collectie'), findsOneWidget);

    final aiRect = tester.getRect(find.byKey(const Key('ai-question-card')));
    final collectionRect = tester.getRect(
      find.byKey(const Key('collection-search-section')),
    );
    final introRect = tester.getRect(
      find.text(
        'Stel een vraag over plekken, personen of gebeurtenissen uit de geschiedenis van Heemskerk.',
      ),
    );
    expect(aiRect.top - introRect.bottom, greaterThanOrEqualTo(32));
    expect(collectionRect.top - aiRect.bottom, greaterThanOrEqualTo(32));

    final aiCard = tester.widget<Card>(
      find.byKey(const Key('ai-question-card')),
    );
    expect(aiCard.color, const Color(0xFFDCE9DA));
    final aiShape = aiCard.shape! as RoundedRectangleBorder;
    expect(aiShape.borderRadius, BorderRadius.circular(16));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFFFBF6EE));

    final aiField = tester.getRect(find.byKey(const Key('ai-question-field')));
    final aiButton = tester.getRect(
      find.byKey(const Key('ai-question-button')),
    );
    expect(find.byKey(const Key('collection-search-field')), findsNothing);
    final collectionButton = tester.getRect(
      find.byKey(const Key('collection-search-button')),
    );
    expect(aiButton.top, greaterThan(aiField.bottom));
    expect(collectionButton.width, greaterThan(300));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('600px homepage stacks both search controls at full width', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(600, 1100));

    final aiField = tester.getRect(find.byKey(const Key('ai-question-field')));
    final aiButton = tester.getRect(
      find.byKey(const Key('ai-question-button')),
    );
    expect(find.byKey(const Key('collection-search-field')), findsNothing);
    final collectionButton = tester.getRect(
      find.byKey(const Key('collection-search-button')),
    );
    expect(aiButton.top, greaterThan(aiField.bottom));
    expect(aiButton.width, aiField.width);
    expect(collectionButton.width, closeTo(aiField.width, 2));
  });

  testWidgets(
    'homepage opens an empty search page without querying the backend',
    (tester) async {
      final source = _SearchSource();
      await _pumpHome(
        tester,
        size: const Size(800, 1000),
        searchSource: source,
      );
      expect(find.byKey(const Key('collection-search-field')), findsNothing);
      expect(find.text('Uitgebreid zoeken'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('collection-search-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      expect(source.searchCalls, 0);
      expect(
        find.text('Voer een zoekterm in om de collectie te doorzoeken.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('collection-query')), findsOneWidget);
    },
  );

  testWidgets('filled AI question starts the existing AI search route', (
    tester,
  ) async {
    final aiSource = _AiSource();
    await _pumpHome(tester, size: const Size(800, 1000), aiSource: aiSource);
    await tester.enterText(
      find.byKey(const Key('ai-question-field')),
      'Wat gebeurde er aan de Kerklaan?',
    );
    await tester.tap(find.byKey(const Key('ai-question-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(aiSource.startedQuestions, ['Wat gebeurde er aan de Kerklaan?']);
    expect(find.text('Vraag het archief'), findsNWidgets(2));
    expect(find.text('Wat gebeurde er aan de Kerklaan?'), findsWidgets);
  });

  testWidgets('empty AI start and Eerdere vragen open the AI overview', (
    tester,
  ) async {
    final aiSource = _AiSource();
    await _pumpHome(tester, size: const Size(800, 1000), aiSource: aiSource);
    await tester.tap(find.byKey(const Key('ai-question-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(aiSource.startedQuestions, isEmpty);
    expect(find.text('Vraag het archief'), findsNWidgets(2));
    expect(aiSource.listCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eerdere vragen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Vraag het archief'), findsNWidgets(2));
    expect(aiSource.listCalls, 2);
  });

  testWidgets(
    'ordinary and advanced collection searches keep their callbacks',
    (tester) async {
      final source = _SearchSource();
      await _pumpHome(
        tester,
        size: const Size(800, 1200),
        searchSource: source,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('collection-search-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('collection-query')),
        'Kerklaan',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.lastQuery, 'Kerklaan');
      expect(source.lastSize, 20);
      await tester.enterText(find.byKey(const Key('collection-query')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uitgebreid zoeken'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Titel'),
        'Bouwtekening',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Jaar'), '1928');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.lastFieldQueries, {'title': 'Bouwtekening'});
      expect(source.lastYear, 1928);
    },
  );

  testWidgets(
    'collection results and navigation to all results stay available',
    (tester) async {
      final source = _SearchSource(results: const [_result], total: 27);
      await _pumpHome(
        tester,
        size: const Size(800, 1200),
        searchSource: source,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('collection-search-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('collection-query')),
        'Kerklaan',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text(_result.title), findsOneWidget);
      expect(find.text('27 resultaten'), findsOneWidget);
      expect(find.text('Doorzoek de collectie'), findsNothing);
      expect(source.lastQuery, 'Kerklaan');
      expect(source.lastSize, 20);
    },
  );

  testWidgets('empty collection results show the empty state', (tester) async {
    await _pumpHome(tester, size: const Size(800, 1000));
    await tester.scrollUntilVisible(
      find.byKey(const Key('collection-search-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('collection-query')),
      'xyzyxzyx',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Geen resultaten gevonden.'), findsOneWidget);
  });

  testWidgets('failed collection search reports an error and keeps its query', (
    tester,
  ) async {
    final source = _SearchSource(results: const [_result], total: 27);
    await _pumpHome(tester, size: const Size(800, 1000), searchSource: source);
    await tester.scrollUntilVisible(
      find.byKey(const Key('collection-search-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('collection-query')),
      'Kerklaan',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('27 resultaten'), findsOneWidget);

    source.throwOnSearch = true;
    await tester.enterText(find.byType(TextField).first, 'Slot Assumburg');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.text('Zoeken is mislukt. Probeer het opnieuw.'),
      findsOneWidget,
    );
    expect(find.text('27 resultaten'), findsNothing);
    expect(find.text('Collecties'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'Slot Assumburg');
  });

  testWidgets('320px at 200% text scaling has no horizontal overflow', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(320, 700), textScaleFactor: 2);
    expect(tester.takeException(), isNull);
    for (final key in ['ai-question-button', 'collection-search-button']) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('signed-in wide app bar has a separate dossiers action', (
    tester,
  ) async {
    final session = _SignedInSession();
    await _pumpHome(
      tester,
      size: const Size(900, 1000),
      session: session,
      dossierSource: FakeDossierSource(),
    );
    expect(find.text('Mijn dossiers'), findsOneWidget);
    expect(find.byTooltip('Mijn account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dossiers-action')));
    await tester.pumpAndSettle();
    expect(find.text('De Kerklaan'), findsOneWidget);
    expect(find.text('Nieuw dossier'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Mijn dossiers'), findsOneWidget);
    expect(find.text('Jan Jansen'), findsOneWidget);
    expect(find.text('Uitloggen'), findsOneWidget);
    await tester.tap(find.text('Uitloggen'));
    await tester.pumpAndSettle();
    expect(session.signOutCalls, 1);
  });

  testWidgets(
    'signed-in narrow header keeps the labelled dossiers link visible',
    (tester) async {
      await _pumpHome(
        tester,
        size: const Size(600, 1100),
        session: _SignedInSession(),
        dossierSource: FakeDossierSource(),
      );
      expect(find.text('Mijn dossiers').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('dossiers-action')));
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Mijn dossiers'), findsOneWidget);
      expect(find.text('Uitloggen'), findsOneWidget);
    },
  );

  testWidgets(
    'multiline homepage question keeps newlines and submits only via the button',
    (tester) async {
      final source = _AiSource();
      await _pumpHome(tester, size: const Size(900, 1100), aiSource: source);
      final field = find.byKey(const Key('ai-question-field'));
      final input = tester.widget<TextField>(field);
      expect(input.minLines, greaterThanOrEqualTo(5));
      expect(input.decoration!.hintText, contains('Welke relaties'));
      await tester.enterText(
        field,
        'Onderzoek familie Jansen.\nWelke relaties zijn er met de Kerklaan?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();
      expect(source.startedQuestions, isEmpty);
      await tester.tap(find.byKey(const Key('ai-question-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(source.startedQuestions, [
        'Onderzoek familie Jansen.\nWelke relaties zijn er met de Kerklaan?',
      ]);
    },
  );

  testWidgets(
    'dossiers remain reachable from AI and collection pages with readable header actions',
    (tester) async {
      await _pumpHome(
        tester,
        size: const Size(1100, 1100),
        session: _SignedInSession(),
        dossierSource: FakeDossierSource(),
      );
      final button = tester.widget<TextButton>(
        find.byKey(const Key('dossiers-action')),
      );
      expect(button.style!.foregroundColor!.resolve({}), appHeaderForeground);
      await tester.tap(find.byKey(const Key('questions-action')));
      await tester.pumpAndSettle();
      expect(find.text('Vraag het archief'), findsNWidgets(2));
      expect(find.byTooltip('Mijn account'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dossiers-action')));
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      await tester.tap(find.byKey(const Key('search-action')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/zoeken');
      await tester.tap(find.byKey(const Key('dossiers-action')));
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hkh-home')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('Ontdek historisch Heemskerk'), findsOneWidget);
    },
  );

  testWidgets(
    'signed-out visitors can find dossiers and their sign-in explanation',
    (tester) async {
      await _pumpHome(
        tester,
        size: const Size(1100, 1100),
        session: DisabledUserSession(),
        dossierSource: FakeDossierSource(),
      );
      await tester.tap(find.byKey(const Key('dossiers-action')));
      await tester.pumpAndSettle();
      expect(find.text('Dossiers zijn persoonlijk'), findsOneWidget);
    },
  );

  testWidgets('all page backgrounds use the homepage colour', (tester) async {
    await _pumpHome(
      tester,
      size: const Size(1100, 1100),
      session: _SignedInSession(),
      dossierSource: FakeDossierSource(),
    );
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    for (final route in [
      '/',
      '/vragen',
      '/zoeken',
      '/dossiers',
      '/dossiers/d1',
      '/artikelen/a1',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      final scaffoldFinder = find.byType(Scaffold).first;
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      final theme = Theme.of(tester.element(scaffoldFinder));
      expect(
        scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
        appBackground,
        reason: route,
      );
    }
  });

  testWidgets(
    'back from a saved answer opens the question form above the history',
    (tester) async {
      final source = _AiSource();
      await source.startAiSearch('Een eerder gestelde vraag');
      await _pumpHome(tester, size: const Size(1000, 1100), aiSource: source);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/vragen?id=session-1');
      await tester.pumpAndSettle();
      expect(find.text('Een eerder gestelde vraag'), findsOneWidget);
      await tester.tap(find.byTooltip('Terug naar Vraag het archief'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/vragen');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['id'],
        isNull,
      );
      expect(
        find.byKey(const Key('ai-question-field')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('ai-question-card'))).dy,
        lessThan(tester.getTopLeft(find.text('Mijn zoekopdrachten')).dy),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-question-field')))
            .minLines,
        5,
      );
      expect(source.startedQuestions, ['Een eerder gestelde vraag']);
    },
  );

  testWidgets('no login action is shown when login is not configured', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(800, 1000));
    expect(find.text('Inloggen'), findsNothing);
  });
}
