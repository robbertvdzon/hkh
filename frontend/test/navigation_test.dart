import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/navigation.dart';

class RecordingSource implements CollectionSearchSource {
  final requests =
      <
        ({
          String? query,
          String? collection,
          Map<String, String> fields,
          int? year,
          int page,
          int size,
        })
      >[];
  final details = <String>[];

  @override
  Future<CollectionOverview> loadOverview() async => const CollectionOverview(
    total: 45,
    collections: [CollectionCount(collection: 'beeldbank', count: 45)],
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
    requests.add((
      query: query,
      collection: collection,
      fields: fieldQueries,
      year: year,
      page: page,
      size: size,
    ));
    return SearchPage(
      total: 45,
      page: page,
      pageSize: size,
      items: List.generate(
        page < 2 ? 20 : 5,
        (i) => CollectionItemSummary(
          collection: 'beeldbank',
          ident: '${page * size + i}',
          title: 'Object ${page * size + i}',
          description: 'Kerklaan',
          year: 1928,
          imageUrl: null,
          hasPdf: false,
        ),
      ),
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
  ) async {
    details.add('$collection/$ident');
    return CollectionItemDetail(
      collection: collection,
      ident: ident,
      title: 'Detail $ident',
      description: 'Volledige beschrijving',
      year: 1928,
      imageUrl: null,
      pdfUrl: null,
      detailUrl: 'https://hkh.vdzonsoftware.nl/#/objecten/$collection/$ident',
      fields: const {'Plaats': 'Heemskerk'},
    );
  }
}

void main() {
  testWidgets(
    'home search opens all collection results and stores the query in the URL',
    (tester) async {
      final source = RecordingSource();
      final router = createAppRouter(
        searchSource: source,
        initialLocation: '/',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Doorzoek de collectie'), findsNothing);
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      expect(source.requests, isEmpty);
      await tester.enterText(
        find.byKey(const Key('collection-query')),
        'Kerklaan',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.requests.single.size, 20);
      expect(source.requests.single.collection, isNull);
      expect(router.routeInformationProvider.value.uri.path, '/zoeken');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['q'],
        'Kerklaan',
      );
      await tester.scrollUntilVisible(
        find.text('45 resultaten'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('45 resultaten'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh restores collection, fields, year and page; object back keeps the results',
    (tester) async {
      final source = RecordingSource();
      final location = searchLocation(
        query: 'Kerk & straat',
        collection: 'beeldbank',
        fields: {'title': 'Bouwtekening'},
        year: 1928,
        page: 1,
      );
      final router = createAppRouter(
        searchSource: source,
        initialLocation: location,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final request = source.requests.single;
      expect(request.query, 'Kerk & straat');
      expect(request.collection, 'beeldbank');
      expect(request.fields, {'title': 'Bouwtekening'});
      expect(request.year, 1928);
      expect(request.page, 1);
      await tester.scrollUntilVisible(
        find.text('Object 20').hitTestable(),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Object 20').hitTestable());
      await tester.pumpAndSettle();
      expect(source.details, ['beeldbank/20']);
      final detailUri = router.routeInformationProvider.value.uri;
      expect(detailUri.path, '/zoeken/objecten/beeldbank/20');
      expect(detailUri.queryParameters['page'], '1');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), location);
      expect(find.text('Object 20'), findsOneWidget);
      expect(source.requests, hasLength(1));

      // Fresh application instance, as with an actual reload of the copied object URL.
      await tester.pumpWidget(const SizedBox());
      final restored = createAppRouter(
        searchSource: source,
        initialLocation: detailUri.toString(),
      );
      addTearDown(restored.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: restored));
      await tester.pumpAndSettle();
      expect(find.text('Detail 20'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(source.requests.last.page, 1);
      expect(
        restored
            .routeInformationProvider
            .value
            .uri
            .queryParameters['collection'],
        'beeldbank',
      );
    },
  );

  testWidgets('next page changes URL and old collection route redirects', (
    tester,
  ) async {
    final source = RecordingSource();
    final router = createAppRouter(
      searchSource: source,
      initialLocation: '/collecties?q=kerk',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/zoeken');
    await tester.scrollUntilVisible(
      find.byTooltip('Volgende pagina').hitTestable(),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Volgende pagina'));
    await tester.pumpAndSettle();
    expect(source.requests.last.page, 1);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['page'],
      '1',
    );
    expect(source.requests.last.query, 'kerk');
  });

  testWidgets(
    'advanced search starts across all collections and preserves its field',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = RecordingSource();
      final router = createAppRouter(
        searchSource: source,
        initialLocation: '/',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-search-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beeldbank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uitgebreid zoeken'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Kerk');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(source.requests.single.collection, isNull);
      expect(source.requests.single.fields, {'title': 'Kerk'});
      expect(source.requests.single.query, '');
    },
  );
}
