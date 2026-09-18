import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/collection/collection_search_page.dart';
import 'package:hkh_app/navigation.dart';

class ExplorerSource implements CollectionSearchSource {
  CollectionSearchOptions? lastOptions;
  String? lastCollection, lastQuery;
  int searches = 0, facetSearches = 0;
  Completer<SearchPage>? pending;
  @override
  Future<CollectionOverview> loadOverview() async => const CollectionOverview(
    total: 6,
    collections: [
      CollectionCount(collection: 'archief', count: 2),
      CollectionCount(collection: 'bidprent', count: 2),
    ],
  );
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
    lastQuery = query;
    lastCollection = collection;
    lastOptions = options;
    if (query == 'slow') return pending!.future;
    return SearchPage(
      items: [
        CollectionItemSummary(
          collection: collection ?? 'archief',
          ident: '42',
          title: query == 'fast' ? 'Nieuw resultaat' : 'Een kasteel',
          description: 'Beschrijving',
          year: 1900,
          imageUrl: null,
          hasPdf: false,
          fields: const {
            'Type publicatie': 'Kaart',
            'Materiaal': 'Hout',
            'Geboren op': '01-01-1880',
          },
        ),
      ],
      total: 1,
      page: 0,
      pageSize: 20,
      documentTextAvailable: true,
      collectionCounts: const [
        CollectionCount(collection: 'archief', count: 1),
        CollectionCount(collection: 'bidprent', count: 1),
      ],
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
  }) async {
    facetSearches++;
    return CollectionFacet(
      field: field,
      values: [
        for (final v in ['Kaart', 'Krantenartikel'])
          if (v.toLowerCase().contains(valueQuery.toLowerCase()))
            FacetValue(v, 1),
      ],
      totalValues: 2,
    );
  }

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async => CollectionItemDetail(
    collection: collection,
    ident: ident,
    title: 'Een kasteel',
    description: 'Beschrijving',
    year: 1900,
    imageUrl: null,
    pdfUrl: null,
    detailUrl: 'https://hkh.vdzonsoftware.nl/#/objecten/$collection/$ident',
    fields: const {
      'Geboren op': '01-01-1880',
      'Overleden op': '01-01-1960',
      'Materiaal': 'Hout',
    },
  );
}

Future<void> setup(
  WidgetTester tester,
  ExplorerSource source, {
  String? collection,
}) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CollectionSearchPage(source: source, initialCollection: collection),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'six collection entrances remain visible without initially loading results',
    (tester) async {
      final source = ExplorerSource();
      await setup(tester, source);
      expect(source.searches, 0);
      expect(source.lastQuery, isNull);
      for (final label in [
        'Archief',
        'Beeldbank',
        'Bibliotheek',
        'Bidprentjes',
        'Artikelen',
        'Objecten',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('1 resultaat'), findsNothing);
    },
  );
  testWidgets(
    'facet alternatives remain active when filtering another collection',
    (tester) async {
      final source = ExplorerSource();
      await setup(tester, source, collection: 'archief');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Type publicatie'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Kaart'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Krantenartikel'));
      await tester.tap(find.text('Toepassen'));
      await tester.pumpAndSettle();
      expect(source.lastOptions!.filters, {
        'Type publicatie': ['Kaart', 'Krantenartikel'],
      });
      await tester.tap(find.text('Bidprentjes (1)'));
      await tester.pumpAndSettle();
      expect(source.lastOptions!.filters['Type publicatie'], [
        'Kaart',
        'Krantenartikel',
      ]);
      await tester.tap(find.text('Archief (1)'));
      await tester.pumpAndSettle();
      expect(source.lastOptions!.filters['Type publicatie'], [
        'Kaart',
        'Krantenartikel',
      ]);
    },
  );
  testWidgets(
    'filter value search queries the server instead of just the first page',
    (tester) async {
      final source = ExplorerSource();
      await setup(tester, source, collection: 'archief');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Type publicatie'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Zoek in type publicatie'),
        'krant',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(source.facetSearches, 2);
      expect(
        find.widgetWithText(CheckboxListTile, 'Krantenartikel'),
        findsOneWidget,
      );
      expect(find.widgetWithText(CheckboxListTile, 'Kaart'), findsNothing);
    },
  );
  testWidgets(
    'counts cover every collection and a new query keeps the selected tab',
    (tester) async {
      final source = ExplorerSource();
      await setup(tester, source);
      await tester.enterText(find.byKey(const Key('collection-query')), 'kerk');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.lastCollection, isNull);
      expect(find.text('Alles (2)'), findsOneWidget);
      expect(find.text('Archief (1)'), findsOneWidget);
      expect(find.text('Beeldbank (0)'), findsOneWidget);
      await tester.tap(find.text('Bidprentjes (1)'));
      await tester.pumpAndSettle();
      expect(source.lastCollection, 'bidprent');
      expect(find.text('1 resultaat'), findsOneWidget);
      expect(find.text('Archief (1)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('collection-query')),
        'plein',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.lastCollection, 'bidprent');
      final searches = source.searches;
      await tester.enterText(find.byKey(const Key('collection-query')), '');
      await tester.pumpAndSettle();
      expect(source.searches, searches);
      expect(find.text('Een kasteel'), findsNothing);
      expect(find.text('Alles (2)'), findsNothing);
      expect(
        find.text('Voer een zoekterm in om de collectie te doorzoeken.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('birth period validates bounds and sends an inclusive range', (
    tester,
  ) async {
    final source = ExplorerSource();
    await setup(tester, source, collection: 'bidprent');
    await tester.tap(find.text('Gericht zoeken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periode invullen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Van jaar'),
      '1900',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tot en met jaar'),
      '1800',
    );
    await tester.tap(find.text('Toepassen'));
    await tester.pumpAndSettle();
    expect(find.text('Het eindjaar ligt vóór het beginjaar.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tot en met jaar'),
      '1910',
    );
    await tester.tap(find.text('Toepassen'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(source.searches, 0);
    await tester.tap(find.byKey(const Key('targeted-search-submit')));
    await tester.pumpAndSettle();
    expect(source.lastCollection, 'bidprent');
    expect(source.lastOptions!.yearFrom, 1900);
    expect(source.lastOptions!.yearTo, 1910);
    await tester.tap(find.text('Eén jaar invullen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Jaar'), '1905');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(source.lastOptions!.yearFrom, isNull);
    expect(source.lastOptions!.yearTo, isNull);
  });
  testWidgets('an older request cannot overwrite a newer search', (
    tester,
  ) async {
    final source = ExplorerSource()..pending = Completer<SearchPage>();
    await setup(tester, source);
    await tester.enterText(find.byKey(const Key('collection-query')), 'slow');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('collection-query')), 'fast');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    source.pending!.complete(
      const SearchPage(items: [], total: 0, page: 0, pageSize: 20),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nieuw resultaat'), findsOneWidget);
    expect(find.text('Geen resultaten gevonden.'), findsNothing);
  });
  testWidgets(
    'search and collection details fit a narrow viewport with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ExplorerSource();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CollectionSearchPage(
            source: source,
            initialCollection: 'bidprent',
            initialQuery: 'kasteel',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Een kasteel').hitTestable(),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Een kasteel').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Persoonsgegevens'), findsOneWidget);
      expect(find.text('01-01-1880'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'all search settings survive a copied URL including punctuation in facets',
    () {
      const options = CollectionSearchOptions(
        mode: 'or',
        partial: false,
        field: 'Auteur(s)',
        yearFrom: 1800,
        yearTo: 1900,
        filters: {
          'Type publicatie': ['Kaart: dorp & duin', 'Krantenartikel'],
        },
        sort: 'title',
        recentDays: 30,
        documentText: false,
        view: 'gallery',
      );
      final url = searchLocation(
        query: 'Jan & Piet',
        collection: 'archief',
        fields: {'Uitgever': 'HKH'},
        page: 3,
        options: options,
      );
      final restored = CollectionSearchOptions.fromParameters(
        Uri.parse(url).queryParametersAll,
      );
      expect(restored.toParameters(), options.toParameters());
      expect(Uri.parse(url).queryParameters['field.Uitgever'], 'HKH');
    },
  );
}
