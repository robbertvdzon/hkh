import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/main.dart';
import 'package:hkh_app/news/latest_news.dart';

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

final _news = LatestNewsItem(
  id: 1,
  title: 'Nieuwe historische ontdekking',
  message: 'Een bijzonder verhaal uit Heemskerk.',
  publishedAt: DateTime.utc(2026, 8, 7),
);

void main() {
  testWidgets('shows the introduction and the latest news', (tester) async {
    await tester.pumpWidget(HkhApp(newsSource: _NewsSource([_news])));
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
      HkhApp(newsSource: _NewsSource(const [], error: true)),
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
    await tester.pumpWidget(HkhApp(newsSource: _NewsSource(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Er zijn nog geen nieuwsberichten.'), findsOneWidget);
  });
}
