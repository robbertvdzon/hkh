import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/collection/collection_search_page.dart';

class _RecordingSearchSource implements CollectionSearchSource {
  String? lastQuery;
  Map<String, String>? lastFieldQueries;

  @override
  Future<CollectionOverview> loadOverview() async =>
      const CollectionOverview(total: 3, collections: []);

  @override
  Future<List<String>> loadFields({String? collection}) async =>
      const ['Auteur(s)', 'Rubriek'];

  @override
  Future<SearchPage> search({
    String? query,
    String? collection,
    Map<String, String> fieldQueries = const {},
    int page = 0,
    int size = 20,
  }) async {
    lastQuery = query;
    lastFieldQueries = fieldQueries;
    return const SearchPage(items: [], total: 0, page: 0, pageSize: 20);
  }

  @override
  Future<CollectionItemDetail> loadDetail(String collection, String ident) async =>
      const CollectionItemDetail(
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
  testWidgets('uitgebreid zoeken shows one input per field, combined as fieldQueries', (
    tester,
  ) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(home: CollectionSearchPage(source: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auteur(s)'), findsNothing);

    await tester.tap(find.text('Uitgebreid zoeken'));
    await tester.pumpAndSettle();

    expect(find.text('Auteur(s)'), findsOneWidget);
    expect(find.text('Rubriek'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('advanced-field-Auteur(s)')),
      'Jansen',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(source.lastFieldQueries, {'Auteur(s)': 'Jansen'});
  });

  testWidgets('an initial query starts a search immediately', (tester) async {
    final source = _RecordingSearchSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionSearchPage(source: source, initialQuery: 'ansichtkaart'),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.lastQuery, 'ansichtkaart');
  });
}
