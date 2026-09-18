import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/collection/collection_search_page.dart';

class _RecordingSearchSource implements CollectionSearchSource {
  String? lastQuery;
  Map<String, String>? lastFieldQueries;
  int? lastYear;
  String? lastCollection;
  CollectionSearchOptions? lastOptions;
  int searches = 0;

  @override
  Future<CollectionOverview> loadOverview() async =>
      const CollectionOverview(total: 3, collections: []);

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
    searches++;
    lastCollection = collection;
    lastOptions = options;
    lastQuery = query;
    lastFieldQueries = fieldQueries;
    lastYear = year;
    return const SearchPage(items: [], total: 0, page: 0, pageSize: 20);
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

void main() {
  testWidgets('gericht zoeken shows Titel, Beschrijving and Jaar', (
    tester,
  ) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(home: CollectionSearchPage(source: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Titel'), findsNothing);

    await tester.tap(find.text('Gericht zoeken'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Titel'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Beschrijving'), findsOneWidget);
    expect(find.text('Jaar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Kring');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(source.lastFieldQueries, {'title': 'Kring'});
  });

  testWidgets('a filled-in year is sent as an exact match', (tester) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(home: CollectionSearchPage(source: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gericht zoeken'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Jaar'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Jaar'), '1954');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(source.lastYear, 1954);
  });

  testWidgets('an initial query starts a search immediately', (tester) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionSearchPage(
          source: source,
          initialQuery: 'ansichtkaart',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.lastQuery, 'ansichtkaart');
  });

  testWidgets(
    'initial field queries and year open the advanced panel pre-filled',
    (tester) async {
      final source = _RecordingSearchSource();
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionSearchPage(
            source: source,
            initialFieldQueries: const {'title': 'Kerk'},
            initialYear: 1900,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(source.lastFieldQueries, {'title': 'Kerk'});
      expect(source.lastYear, 1900);
      await tester.scrollUntilVisible(
        find.text('Titel'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Titel'), findsOneWidget);
    },
  );
  testWidgets(
    'collection fields combine with general text and survive submitting',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _RecordingSearchSource();
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionSearchPage(
            source: source,
            initialCollection: 'beeldbank',
          ),
        ),
      );
      await tester.tap(find.text('Gericht zoeken'));
      await tester.pumpAndSettle();
      for (final label in [
        'Zoekwoorden combineren',
        'Zoeken in veld',
        'Ook delen van woorden',
        'Ook documenttekst (OCR)',
        'Periode / jaar',
      ]) {
        expect(find.text(label), findsNothing);
      }
      await tester.tap(find.text('Zoekveld toevoegen'));
      await tester.pumpAndSettle();
      expect(find.text('Titel + Beschrijving'), findsNothing);
      expect(find.text('Achternaam overledene'), findsNothing);
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Straatnaam'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('collection-query')),
        'school',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'klas');
      await tester.enterText(
        find.widgetWithText(TextField, 'Beschrijving'),
        'kinderen',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Jaar'), '1950');
      await tester.enterText(
        find.widgetWithText(TextField, 'Straatnaam'),
        'Kerklaan',
      );
      await tester.tap(find.byKey(const Key('targeted-search-submit')));
      await tester.pumpAndSettle();
      expect(source.lastCollection, 'beeldbank');
      expect(source.lastQuery, 'school');
      expect(source.lastYear, 1950);
      expect(source.lastFieldQueries, {
        'title': 'klas',
        'description': 'kinderen',
        'Straatnaam': 'Kerklaan',
      });
      expect(source.lastOptions!.field, 'all');
      expect(source.lastOptions!.mode, 'web');
      expect(source.lastOptions!.partial, isFalse);
      expect(source.lastOptions!.documentText, isTrue);
      await tester.tap(find.byTooltip('Straatnaam verwijderen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('targeted-search-submit')));
      await tester.pumpAndSettle();
      expect(source.lastFieldQueries, {
        'title': 'klas',
        'description': 'kinderen',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a collection field can be used alone and reset without leaving the collection',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _RecordingSearchSource();
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionSearchPage(
            source: source,
            initialCollection: 'beeldbank',
          ),
        ),
      );
      await tester.tap(find.text('Gericht zoeken'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zoekveld toevoegen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Straatnaam'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Straatnaam'),
        'Kerklaan',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.lastQuery, '');
      expect(source.lastCollection, 'beeldbank');
      expect(source.lastFieldQueries, {'Straatnaam': 'Kerklaan'});
      await tester.tap(find.text('Wissen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Straatnaam'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Beeldbank'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid year does not silently broaden a field search', (
    tester,
  ) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionSearchPage(
          source: source,
          initialFieldQueries: const {'title': 'school'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final searches = source.searches;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Jaar'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Jaar'), '195x');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(source.searches, searches);
    await tester.scrollUntilVisible(
      find.text('Vul een geldig jaar tussen 1 en 2100 in.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Vul een geldig jaar tussen 1 en 2100 in.'),
      findsOneWidget,
    );
  });

  testWidgets('document-only matches explain their source on result cards', (
    tester,
  ) async {
    final item = CollectionItemSummary.fromJson({
      'collection': 'artikelen',
      'ident': '42',
      'title': 'Dorpsnieuws',
      'description': 'Een verslag uit 1950',
      'documentSnippet': 'De nieuwe school aan de Kerklaan is geopend.',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionResultCard(item: item, onTap: () {}),
        ),
      ),
    );
    expect(find.text('Gevonden in documenttekst'), findsOneWidget);
    expect(
      find.text('De nieuwe school aan de Kerklaan is geopend.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'partial matching is offered after no results and keeps the search constraints',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _RecordingSearchSource();
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionSearchPage(
            source: source,
            initialQuery: 'kerk',
            initialCollection: 'beeldbank',
            initialYear: 1950,
            initialFieldQueries: const {'Straatnaam': 'Dorps'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zoek ook op delen van woorden'));
      await tester.pumpAndSettle();
      expect(source.lastOptions!.partial, isTrue);
      expect(source.lastOptions!.mode, 'and');
      expect(source.lastCollection, 'beeldbank');
      expect(source.lastYear, 1950);
      expect(source.lastFieldQueries, {'Straatnaam': 'Dorps'});
      expect(find.text('Zoek ook op delen van woorden'), findsNothing);
    },
  );

  testWidgets('targeted fields fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: CollectionSearchPage(
          source: _RecordingSearchSource(),
          initialCollection: 'beeldbank',
          initialFieldQueries: const {'Straatnaam': 'Kerklaan'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('targeted-search-submit')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
