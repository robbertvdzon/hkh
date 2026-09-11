import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/main.dart';
import 'package:hkh_app/news/latest_news.dart';
import 'package:hkh_app/collection/collection_search.dart';

class _NewsSource implements LatestNewsSource {
  _NewsSource(this.items, {this.error = false});

  final List<LatestNewsItem> items;
  final bool error;

  @override
  Future<List<LatestNewsItem>> loadLatestNews() async {
    if (error) throw StateError('offline');
    return items;
  }
}

class _SearchSource implements CollectionSearchSource {
  _SearchSource({this.results = const []});

  final List<CollectionItemSummary> results;

  @override
  Future<CollectionOverview> loadOverview() async =>
      const CollectionOverview(total: 0, collections: []);
  @override
  Future<SearchPage> search({
    String? query,
    String? collection,
    Map<String, String> fieldQueries = const {},
    int page = 0,
    int size = 20,
  }) async => SearchPage(
    items: results,
    total: results.length,
    page: 0,
    pageSize: size,
  );
  @override
  Future<List<String>> loadFields({String? collection}) async => const [];
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

final _news = LatestNewsItem(
  id: 1,
  title: 'Nieuwe historische ontdekking',
  message: 'Een bijzonder verhaal uit Heemskerk.',
  publishedAt: DateTime.utc(2026, 8, 7),
);

void main() {
  testWidgets('shows the introduction and the latest news', (tester) async {
    await tester.pumpWidget(HkhApp(newsSource: _NewsSource([_news]), searchSource: _SearchSource()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Ontdek de geschiedenis van Heemskerk vanuit een vraag',
      ),
      findsOneWidget,
    );
    expect(find.text('Laatste nieuws'), findsOneWidget);
    expect(find.text('Nieuwe historische ontdekking'), findsOneWidget);
    expect(find.text('Een bijzonder verhaal uit Heemskerk.'), findsOneWidget);

    await tester.tap(find.text('Lees onze productvisie'));
    await tester.pumpAndSettle();

    expect(find.text('Productvisie'), findsWidgets);
    expect(find.text('Productprincipes'), findsOneWidget);
    expect(find.text('Verbonden'), findsOneWidget);
  });

  testWidgets('keeps the homepage usable when the news source fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      HkhApp(
        newsSource: _NewsSource(const [], error: true),
        searchSource: _SearchSource(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Ontdek de geschiedenis van Heemskerk vanuit een vraag',
      ),
      findsOneWidget,
    );
    expect(find.text('Lees onze productvisie'), findsOneWidget);
    expect(find.text('De HKH-service is niet bereikbaar'), findsNothing);
    expect(
      find.text('Het laatste nieuws kon niet worden geladen.'),
      findsOneWidget,
    );
    expect(find.text('Opnieuw proberen'), findsOneWidget);
  });

  testWidgets('shows an empty state when there is no news', (tester) async {
    await tester.pumpWidget(HkhApp(newsSource: _NewsSource(const []), searchSource: _SearchSource()));
    await tester.pumpAndSettle();

    expect(find.text('Er zijn nog geen nieuwsberichten.'), findsOneWidget);
  });

  testWidgets('the homepage search box shows results without leaving the page', (
    tester,
  ) async {
    final searchSource = _SearchSource(
      results: const [
        CollectionItemSummary(
          collection: 'beeldbank',
          ident: '10001',
          title: 'Straten Maerten van Heemskerckstraat',
          description: 'Dorpsweg vanaf Beverwijk. Ansichtkaart uit 1900.',
          year: 1900,
          imageUrl: null,
          hasPdf: false,
        ),
      ],
    );
    await tester.pumpWidget(
      HkhApp(newsSource: _NewsSource([_news]), searchSource: searchSource),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ansichtkaart');
    await tester.tap(find.text('Zoeken'));
    await tester.pumpAndSettle();

    expect(find.text('Straten Maerten van Heemskerckstraat'), findsOneWidget);
    expect(find.text('Alle 1 resultaten en uitgebreid zoeken'), findsOneWidget);
  });
}
