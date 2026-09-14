import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/auth/user_session.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/main.dart';

import 'dossier_test_support.dart';

const _searchTips =
    'Los woorden voor een EN-zoekopdracht, of zet een zin tussen '
    '"aanhalingstekens" voor een exacte frase.';

class _SignedInSession extends UserSessionController {
  UserIdentity? _identity = const UserIdentity(
    email: 'jan@example.com',
    displayName: 'Jan Jansen',
    isAdmin: false,
    token: 'sess-1',
  );
  int signOutCalls = 0;

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
  testWidgets('wide homepage has the new hierarchy, styling and spacing', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(1000, 1000));

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
        'Bijv. wat is er bekend over de Kerklaan? De digitale onderzoeker zoekt bronnen bij elkaar. Dit kan enkele minuten duren.',
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
    final collectionField = tester.getRect(
      find.byKey(const Key('collection-search-field')),
    );
    final collectionButton = tester.getRect(
      find.byKey(const Key('collection-search-button')),
    );
    expect(aiField.top, aiButton.top);
    expect(collectionField.top, collectionButton.top);
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
    final collectionField = tester.getRect(
      find.byKey(const Key('collection-search-field')),
    );
    final collectionButton = tester.getRect(
      find.byKey(const Key('collection-search-button')),
    );
    expect(aiButton.top, greaterThan(aiField.bottom));
    expect(aiButton.width, aiField.width);
    expect(collectionButton.top, greaterThan(collectionField.bottom));
    expect(collectionButton.width, collectionField.width);
  });

  testWidgets('Zoektips and Uitgebreid zoeken are independent disclosures', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(800, 1000));

    expect(find.text(_searchTips), findsNothing);
    expect(find.text('Jaar'), findsNothing);
    await tester.tap(find.text('Zoektips'));
    await tester.pumpAndSettle();
    expect(find.text(_searchTips), findsOneWidget);
    expect(find.text('Jaar'), findsNothing);
    await tester.tap(find.text('Uitgebreid zoeken'));
    await tester.pumpAndSettle();
    expect(find.text(_searchTips), findsOneWidget);
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Beschrijving'), findsOneWidget);
    expect(find.text('Jaar'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Titel'), findsOneWidget);
    expect(find.bySemanticsLabel('Beschrijving'), findsOneWidget);
    expect(find.bySemanticsLabel('Jaar'), findsOneWidget);
    semantics.dispose();
  });

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
    expect(find.text('Vraag het archief'), findsOneWidget);
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
    expect(find.text('AI-zoekopdrachten'), findsOneWidget);
    expect(aiSource.listCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eerdere vragen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AI-zoekopdrachten'), findsOneWidget);
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
      await tester.enterText(
        find.byKey(const Key('collection-search-field')),
        'Kerklaan',
      );
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      expect(source.lastQuery, 'Kerklaan');
      expect(source.lastSize, 3);

      await tester.tap(find.text('Uitgebreid zoeken'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Bouwtekening');
      await tester.enterText(find.byType(TextField).at(4), '1928');
      await tester.tap(find.byKey(const Key('collection-search-button')));
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
      await tester.enterText(
        find.byKey(const Key('collection-search-field')),
        'Kerklaan',
      );
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      expect(find.text(_result.title), findsOneWidget);
      expect(find.text('Alle 27 resultaten'), findsOneWidget);
      await tester.tap(find.text('Alle 27 resultaten'));
      await tester.pumpAndSettle();
      expect(find.text('Doorzoek de collectie'), findsOneWidget);
      expect(source.lastQuery, 'Kerklaan');
      expect(source.lastSize, 20);
    },
  );

  testWidgets('empty collection results show the empty state', (tester) async {
    await _pumpHome(tester, size: const Size(800, 1000));
    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      'xyzyxzyx',
    );
    await tester.tap(find.byKey(const Key('collection-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Geen resultaten gevonden.'), findsOneWidget);
  });

  testWidgets('failed collection search reports an error and keeps its query', (
    tester,
  ) async {
    final source = _SearchSource(results: const [_result], total: 27);
    await _pumpHome(tester, size: const Size(800, 1000), searchSource: source);
    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      'Kerklaan',
    );
    await tester.tap(find.byKey(const Key('collection-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Alle 27 resultaten'), findsOneWidget);

    source.throwOnSearch = true;
    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      'Slot Assumburg',
    );
    await tester.tap(find.byKey(const Key('collection-search-button')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Zoeken in de collectie is niet gelukt. Controleer de verbinding en probeer het opnieuw.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alle 27 resultaten'), findsNothing);
    expect(find.text('Doorzoek de collectie'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('collection-search-field')),
    );
    expect(field.controller!.text, 'Slot Assumburg');
  });

  testWidgets('320px at 200% text scaling has no horizontal overflow', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(320, 700), textScaleFactor: 2);
    expect(tester.takeException(), isNull);
    final list = find.byType(ListView).first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Vraag stellen'), findsOneWidget);
    expect(find.text('Zoeken'), findsOneWidget);
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
    expect(find.text('Jan Jansen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dossiers-action')));
    await tester.pumpAndSettle();
    expect(find.text('De Kerklaan'), findsOneWidget);
    expect(find.text('Nieuw dossier'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Mijn dossiers'), findsOneWidget);
    expect(find.text('Uitloggen'), findsOneWidget);
    await tester.tap(find.text('Uitloggen'));
    await tester.pumpAndSettle();
    expect(session.signOutCalls, 1);
  });

  testWidgets('signed-in narrow app bar uses an accessible dossiers icon', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(600, 1100),
      session: _SignedInSession(),
      dossierSource: FakeDossierSource(),
    );
    expect(find.byTooltip('Mijn dossiers'), findsOneWidget);
    expect(find.text('Mijn dossiers'), findsNothing);
    await tester.tap(find.byTooltip('Mijn dossiers'));
    await tester.pumpAndSettle();
    expect(find.text('De Kerklaan'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Mijn dossiers'), findsNothing);
    expect(find.text('Uitloggen'), findsOneWidget);
  });

  testWidgets('no login action is shown when login is not configured', (
    tester,
  ) async {
    await _pumpHome(tester, size: const Size(800, 1000));
    expect(find.text('Inloggen'), findsNothing);
  });
}
