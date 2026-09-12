import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/collection/collection_search_page.dart';

class _RecordingSearchSource implements CollectionSearchSource {
  String? lastQuery;
  Map<String, String>? lastFieldQueries;
  int? lastYear;

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
  }) async {
    lastQuery = query;
    lastFieldQueries = fieldQueries;
    lastYear = year;
    return const SearchPage(items: [], total: 0, page: 0, pageSize: 20);
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

void main() {
  testWidgets('uitgebreid zoeken shows Titel, Beschrijving and Jaar', (
    tester,
  ) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(home: CollectionSearchPage(source: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Titel'), findsNothing);

    await tester.tap(find.text('Uitgebreid zoeken'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Uitgebreid zoeken'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(3), '1954');
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
      expect(find.text('Titel'), findsOneWidget);
    },
  );
}
