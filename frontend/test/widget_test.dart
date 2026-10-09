import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/auth/user_session.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/content/site_structure.dart';
import 'package:hkh_app/main.dart';
import 'package:hkh_app/theme/app_style.dart';

/// Vast peilmoment: vrijdag 9 oktober 2026, zodat de agenda voorspelbaar is.
final _now = DateTime(2026, 10, 9, 12);

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
  String? lastQuery;
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
    return SearchPage(items: const [], total: 0, page: page, pageSize: size);
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
  final List<(String, bool?, String?)> steerings = [];
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
  Future<AiSearchSession> startAiSearch(
    String question, {
    AiResearchDepth depth = AiResearchDepth.fast,
  }) async {
    startedQuestions.add(question);
    return current = _session(question);
  }

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) async => current!;

  @override
  Future<AiSearchSession> askFollowUp(
    String sessionId,
    String question, {
    AiResearchDepth depth = AiResearchDepth.fast,
  }) async => current!;

  @override
  Future<AiSearchSession> cancelAiSearch(String sessionId) async => current!;

  @override
  Future<AiSearchSession> steerAiSearch(
    String sessionId,
    String turnId, {
    bool? stop,
    String? hint,
  }) async {
    steerings.add((turnId, stop, hint));
    return current!;
  }

  @override
  Future<void> deleteAiSearch(String sessionId) async {}
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

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required Size size,
  _SearchSource? searchSource,
  _AiSource? aiSource,
  UserSessionController? session,
  double textScaleFactor = 1,
  String? route,
}) async {
  _setViewport(tester, size, textScaleFactor: textScaleFactor);
  await tester.pumpWidget(
    HkhApp(
      searchSource: searchSource ?? _SearchSource(),
      aiSearchSource: aiSource ?? _AiSource(),
      session: session,
      now: _now,
    ),
  );
  await tester.pumpAndSettle();
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  if (route != null) {
    router.go(route);
    await tester.pumpAndSettle();
  }
  return router;
}

String _path(GoRouter router) => router.routeInformationProvider.value.uri.path;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('homepage', () {
    testWidgets('shows the six entrances, upcoming activities and news', (
      tester,
    ) async {
      final router = await _pumpApp(tester, size: const Size(1200, 1100));
      for (final item in mainMenu) {
        expect(find.byKey(Key('menu-${item.path.substring(1)}')), findsOneWidget);
      }
      expect(find.byKey(const Key('membership-action')), findsOneWidget);
      expect(
        find.text('De geschiedenis van Heemskerk, verzameld en verteld sinds 1988'),
        findsOneWidget,
      );
      expect(find.text('Binnenkort'), findsOneWidget);
      // De drie eerstvolgende activiteiten op 9 oktober 2026.
      expect(find.text('De museumschuur van Piet Diemeer'), findsOneWidget);
      expect(find.text('De Zoektocht in het Noorderveld'), findsOneWidget);
      expect(find.text('Lezing het Palmhoutwrak'), findsOneWidget);
      expect(find.text('Vol · 3 op wachtlijst'), findsOneWidget);
      expect(find.text('Lezing over Cornelis Corneliszoon'), findsNothing);
      await _scrollTo(tester, find.text('Het verhaal van Neeltje Snijders'));
      expect(find.text('Het verhaal van Neeltje Snijders'), findsOneWidget);
      await _scrollTo(tester, find.text('Voor basisscholen'));
      expect(find.text('Bekijk het lesaanbod'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(_path(router), '/');
    });

    testWidgets('hero buttons open the agenda, the search and membership', (
      tester,
    ) async {
      final router = await _pumpApp(tester, size: const Size(1200, 1100));
      await tester.tap(find.byKey(const Key('home-agenda-button')));
      await tester.pumpAndSettle();
      expect(_path(router), '/agenda');
      await tester.tap(find.byKey(const Key('hkh-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-search-button')));
      await tester.pumpAndSettle();
      expect(_path(router), '/zoeken');
      await tester.tap(find.byKey(const Key('hkh-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('membership-action')));
      await tester.pumpAndSettle();
      expect(_path(router), '/lid-worden');
      expect(find.text('Aanmelden als lid'), findsOneWidget);
    });

    testWidgets('home search field opens the search page with the query', (
      tester,
    ) async {
      final source = _SearchSource();
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1100),
        searchSource: source,
      );
      await _scrollTo(tester, find.byKey(const Key('home-search-field')));
      await tester.enterText(
        find.byKey(const Key('home-search-field')),
        'Kerklaan',
      );
      await tester.tap(find.byKey(const Key('home-search-submit')));
      await tester.pumpAndSettle();
      expect(_path(router), '/zoeken');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['q'],
        'Kerklaan',
      );
      expect(source.lastQuery, 'Kerklaan');
    });

    testWidgets('home question starts the AI search route', (tester) async {
      final aiSource = _AiSource();
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1100),
        aiSource: aiSource,
      );
      await _scrollTo(tester, find.byKey(const Key('home-question-field')));
      await tester.enterText(
        find.byKey(const Key('home-question-field')),
        'Wat gebeurde er aan de Kerklaan?',
      );
      await tester.tap(find.byKey(const Key('home-question-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_path(router), '/vragen');
      expect(aiSource.startedQuestions, ['Wat gebeurde er aan de Kerklaan?']);
    });

    testWidgets('without an AI source the question block and menu entry are gone', (
      tester,
    ) async {
      _setViewport(tester, const Size(1200, 1100));
      await tester.pumpWidget(
        HkhApp(searchSource: _SearchSource(), now: _now),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('home-search-field')));
      expect(find.byKey(const Key('home-question-field')), findsNothing);
      expect(find.byKey(const Key('home-search-field')), findsOneWidget);
    });

    testWidgets('320px at 200% text scaling has no horizontal overflow', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        size: const Size(320, 700),
        textScaleFactor: 2,
      );
      expect(tester.takeException(), isNull);
      for (final key in ['home-search-submit', 'home-question-submit']) {
        await _scrollTo(tester, find.byKey(Key(key)));
        expect(tester.takeException(), isNull);
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      }
    });
  });

  group('menu', () {
    testWidgets('wide menu opens every section', (tester) async {
      final router = await _pumpApp(tester, size: const Size(1200, 1100));
      for (final item in mainMenu) {
        await tester.tap(find.byKey(Key('menu-${item.path.substring(1)}')));
        await tester.pumpAndSettle();
        expect(_path(router), item.path, reason: item.label);
        expect(tester.takeException(), isNull, reason: item.label);
      }
      await tester.tap(find.byKey(const Key('hkh-home')));
      await tester.pumpAndSettle();
      expect(_path(router), '/');
    });

    testWidgets('narrow header shows a menu button that opens a panel', (
      tester,
    ) async {
      final router = await _pumpApp(tester, size: const Size(600, 1000));
      expect(find.byKey(const Key('menu-agenda')), findsNothing);
      await tester.tap(find.byKey(const Key('menu-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Vraag het archief'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-educatie')));
      await tester.pumpAndSettle();
      expect(_path(router), '/educatie');
      expect(
        find.text('Educatie: lesaanbod voor het basisonderwijs'),
        findsWidgets,
      );
    });

    testWidgets('header search box opens the collection search', (tester) async {
      final router = await _pumpApp(tester, size: const Size(1200, 1100));
      await tester.tap(find.byKey(const Key('header-search-field')));
      await tester.pumpAndSettle();
      expect(_path(router), '/zoeken');
      expect(find.byKey(const Key('collection-query')), findsOneWidget);
    });
  });

  group('agenda', () {
    testWidgets('lists upcoming activities, filters and opens the past', (
      tester,
    ) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda',
      );
      expect(find.text('oktober 2026'), findsOneWidget);
      expect(find.text('november 2026'), findsOneWidget);
      expect(find.text('Piet Paree – De Terugkeer van een Kanaalgraver'), findsOneWidget);
      expect(find.text('Raad je straat'), findsNothing);
      await tester.tap(find.byKey(const Key('agenda-filter-lezing')));
      await tester.pumpAndSettle();
      expect(find.text('Lezing het Palmhoutwrak'), findsOneWidget);
      expect(find.text('De museumschuur van Piet Diemeer'), findsNothing);
      await tester.tap(find.byKey(const Key('agenda-filter-lezing')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('agenda-past-button')));
      await tester.tap(find.byKey(const Key('agenda-past-button')));
      await tester.pumpAndSettle();
      expect(_path(router), '/agenda/eerder');
      expect(find.text('Raad je straat'), findsWidgets);
      expect(find.text('Lezing het Palmhoutwrak'), findsNothing);
    });

    testWidgets('an activity row opens the activity page', (tester) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda',
      );
      await tester.tap(
        find.byKey(const Key('activity-lezing-over-cornelis-corneliszoon')),
      );
      await tester.pumpAndSettle();
      expect(_path(router), '/agenda/lezing-over-cornelis-corneliszoon');
      expect(find.text('Nog 4 van de 25 plaatsen'), findsOneWidget);
    });

    testWidgets('registering shows a demo confirmation without a backend', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda/lezing-over-cornelis-corneliszoon',
      );
      await tester.enterText(
        find.byKey(const Key('registration-name')),
        'J. de Vries',
      );
      await tester.enterText(
        find.byKey(const Key('registration-email')),
        'j.devries@voorbeeld.nl',
      );
      await tester.tap(find.byKey(const Key('registration-privacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registration-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Ingeschreven'), findsOneWidget);
      expect(find.textContaining('nog niets bewaard'), findsOneWidget);
    });

    testWidgets('a full activity offers the waiting list', (tester) async {
      await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda/de-zoektocht-in-het-noorderveld',
      );
      expect(find.text('Deze activiteit is vol'), findsOneWidget);
      expect(
        find.text('25 van de 25 plaatsen bezet · 3 op de wachtlijst'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Op de wachtlijst'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('registration-name')), 'A');
      await tester.enterText(
        find.byKey(const Key('registration-email')),
        'a@b.nl',
      );
      await tester.tap(find.byKey(const Key('registration-privacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registration-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('U staat op de wachtlijst'), findsOneWidget);
    });

    testWidgets('a partner activity links to the external registration', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda/lezing-het-palmhoutwrak',
      );
      expect(find.byKey(const Key('registration-external')), findsOneWidget);
      expect(find.byKey(const Key('registration-submit')), findsNothing);
    });

    testWidgets('a past activity shows no form', (tester) async {
      await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/agenda/raad-je-straat',
      );
      expect(find.text('Deze activiteit is geweest'), findsOneWidget);
      expect(find.byKey(const Key('registration-submit')), findsNothing);
    });

    testWidgets('narrow agenda has no overflow', (tester) async {
      await _pumpApp(
        tester,
        size: const Size(360, 800),
        route: '/agenda',
        textScaleFactor: 1.3,
      );
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.byKey(const Key('agenda-past-button')));
      expect(tester.takeException(), isNull);
    });
  });

  group('content pages', () {
    testWidgets('news lists posts and opens an article', (tester) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/nieuws',
      );
      expect(find.text('Het verhaal van Neeltje Snijders'), findsOneWidget);
      await tester.tap(find.text('Het verhaal van Neeltje Snijders'));
      await tester.pumpAndSettle();
      expect(_path(router), '/nieuws/het-verhaal-van-neeltje-snijders');
      expect(find.textContaining('De Vingerbijters'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-nieuws')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('news-newsletters')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('newsletter-97')), findsOneWidget);
    });

    testWidgets('discover shows categories and a story with related links', (
      tester,
    ) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/ontdek',
      );
      expect(find.byKey(const Key('discover-kastelen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('discover-kastelen')));
      await tester.pumpAndSettle();
      expect(_path(router), '/ontdek/kastelen');
      await tester.tap(find.text('Kastelen - Assumburg'));
      await tester.pumpAndSettle();
      expect(_path(router), '/ontdek/kastelen-assumburg');
      expect(find.textContaining('Slot Assumburg dateert'), findsOneWidget);
      await _scrollTo(tester, find.byKey(const Key('more-in-collections')));
      await tester.tap(find.byKey(const Key('more-in-collections')));
      await tester.pumpAndSettle();
      expect(_path(router), '/zoeken');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['q'],
        'Assumburg',
      );
    });

    testWidgets('education lists the programme and takes a request', (
      tester,
    ) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/educatie',
      );
      for (final item in educationItems) {
        expect(find.byKey(Key('education-${item.slug}')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('education-heemskerk-in-oorlogstijd')));
      await tester.pumpAndSettle();
      expect(_path(router), '/educatie/heemskerk-in-oorlogstijd');
      await tester.enterText(find.byKey(const Key('education-school')), 'De Otterkolken');
      await tester.enterText(find.byKey(const Key('education-contact')), 'M. Bakker');
      await tester.enterText(find.byKey(const Key('education-email')), 'm@school.nl');
      await _scrollTo(tester, find.byKey(const Key('education-submit')));
      await tester.tap(find.byKey(const Key('education-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Aanvraag verstuurd'), findsOneWidget);
    });

    testWidgets('association pages render board, documents and contact', (
      tester,
    ) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        route: '/vereniging',
      );
      await tester.tap(find.byKey(const Key('association-bestuur')));
      await tester.pumpAndSettle();
      expect(find.text('Guus de Jonge'), findsOneWidget);
      expect(find.text('Voorzitter'), findsOneWidget);
      router.go('/vereniging/anbi');
      await tester.pumpAndSettle();
      expect(find.text('Financiën'), findsOneWidget);
      expect(find.text('Beleidsplan'), findsOneWidget);
      router.go('/vereniging/contact');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-submit')), findsOneWidget);
      router.go('/vereniging/werkgroepen');
      await tester.pumpAndSettle();
      expect(find.textContaining('Werkgroep Educatie'), findsOneWidget);
      expect(find.byKey(const Key('workgroups-join')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collections page opens search and the AI question', (
      tester,
    ) async {
      final aiSource = _AiSource();
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        aiSource: aiSource,
        route: '/collecties',
      );
      await tester.tap(find.byKey(const Key('collection-chip-bidprentjes')));
      await tester.pumpAndSettle();
      expect(_path(router), '/zoeken');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['collection'],
        'bidprentjes',
      );
      router.go('/collecties');
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('ai-question-field')));
      await tester.enterText(
        find.byKey(const Key('ai-question-field')),
        'Wie was Piet Diemeer?',
      );
      await tester.ensureVisible(find.byKey(const Key('ai-question-button')));
      await tester.tap(find.byKey(const Key('ai-question-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(aiSource.startedQuestions, ['Wie was Piet Diemeer?']);
      expect(_path(router), '/vragen');
    });

    testWidgets('unknown routes show the not-found page', (tester) async {
      await _pumpApp(
        tester,
        size: const Size(1200, 1000),
        route: '/agenda/bestaat-niet',
      );
      expect(find.text('Pagina niet gevonden'), findsWidgets);
    });

    testWidgets('all page backgrounds use the site colour', (tester) async {
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1100),
        session: _SignedInSession(),
      );
      for (final route in [
        '/',
        '/agenda',
        '/agenda/lezing-het-palmhoutwrak',
        '/nieuws',
        '/ontdek',
        '/ontdek/maerten-van-heemskerck',
        '/collecties',
        '/educatie',
        '/vereniging',
        '/lid-worden',
        '/vragen',
        '/zoeken',
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
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  });

  group('old links', () {
    test('old site links map to the new routes', () {
      expect(
        internalRouteFor('https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl'),
        '/zoeken?collection=beeldbank',
      );
      expect(
        internalRouteFor(
          'https://www.historischekringheemskerk.nl/cgi-bin/library.pl?ident=5280&search=toen%20&veld=all',
        ),
        '/zoeken?collection=bibliotheek&q=toen+',
      );
      expect(
        internalRouteFor('https://www.historischekringheemskerk.nl/evenementen/'),
        '/agenda',
      );
      expect(
        internalRouteFor(
          'https://www.historischekringheemskerk.nl/evenement/de-verjaardag-van-maerten/',
        ),
        '/agenda/de-verjaardag-van-maerten',
      );
      expect(internalRouteFor('/juridische-disclaimer/'), '/vereniging/anbi');
      expect(internalRouteFor('/kastelen-assumburg/'), '/ontdek/kastelen-assumburg');
      expect(
        internalRouteFor('https://www.historischekringheemskerk.nl/wp-content/uploads/x.pdf'),
        isNull,
      );
      expect(internalRouteFor('https://www.oerij.eu/'), isNull);
      expect(internalRouteFor('mailto:opgeven@historischekringheemskerk.nl'), isNull);
    });
  });

  group('account', () {
    testWidgets(
      'login links browser history from home and reloads history on account changes',
      (tester) async {
        final session = _SignedInSession();
        await session.signOut();
        final source = _AccountAiSource(session);
        final router = await _pumpApp(
          tester,
          size: const Size(1200, 1300),
          aiSource: source,
          session: session,
        );
        expect(source.syncedAccounts, isEmpty);
        session.loginAs('jan@example.com');
        await tester.pumpAndSettle();
        expect(source.syncedAccounts, ['jan@example.com']);
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
      final router = await _pumpApp(
        tester,
        size: const Size(1200, 1300),
        aiSource: source,
        session: session,
      );
      expect(source.syncedAccounts, ['jan@example.com']);
      router.go('/vragen?id=session-1');
      await tester.pumpAndSettle();
      expect(find.text('Privévraag van Jan'), findsOneWidget);
      await session.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Privévraag van Jan'), findsNothing);
      expect(find.textContaining('Gevonden antwoord.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('signed-in header has an account menu with sign-out', (
      tester,
    ) async {
      final session = _SignedInSession();
      await _pumpApp(tester, size: const Size(1200, 1000), session: session);
      expect(find.byTooltip('Mijn account'), findsOneWidget);
      expect(find.text('Mijn dossiers'), findsNothing);
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Jan Jansen'), findsOneWidget);
      await tester.tap(find.text('Uitloggen'));
      await tester.pumpAndSettle();
      expect(session.signOutCalls, 1);
    });

    testWidgets('no login action is shown when login is not configured', (
      tester,
    ) async {
      await _pumpApp(tester, size: const Size(800, 1000));
      expect(find.text('Inloggen'), findsNothing);
    });
  });
}
