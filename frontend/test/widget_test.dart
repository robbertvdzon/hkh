import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/backend/backend_status.dart';
import 'package:hkh_app/main.dart';
import 'package:hkh_app/news/latest_news.dart';

class _SuccessfulStatusSource implements BackendStatusSource {
  @override
  Future<BackendStatus> load() async => const BackendStatus(
    application: 'hkh',
    version: 'test',
    commit: 'abc123',
  );
}

class _FailingStatusSource implements BackendStatusSource {
  @override
  Future<BackendStatus> load() async => throw StateError('offline');
}

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
  testWidgets('shows backend version when the service is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      HkhApp(
        statusSource: _SuccessfulStatusSource(),
        newsSource: _NewsSource([_news]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Ontdek de geschiedenis van Heemskerk vanuit een vraag',
      ),
      findsOneWidget,
    );
    expect(find.text('hkh test · abc123'), findsOneWidget);
    expect(find.text('Laatste nieuws'), findsOneWidget);
    expect(find.text('Nieuwe historische ontdekking'), findsOneWidget);
    expect(find.text('Een bijzonder verhaal uit Heemskerk.'), findsOneWidget);

    await tester.tap(find.text('Lees onze productvisie'));
    await tester.pumpAndSettle();

    expect(find.text('Productvisie'), findsWidgets);
    expect(find.text('Productprincipes'), findsOneWidget);
    expect(find.text('Verbonden'), findsOneWidget);
  });

  testWidgets('shows a retry action when the service is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      HkhApp(
        statusSource: _FailingStatusSource(),
        newsSource: _NewsSource(const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('De HKH-service is niet bereikbaar'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsOneWidget);
  });

  testWidgets('shows empty and error states for latest news', (tester) async {
    await tester.pumpWidget(
      HkhApp(
        statusSource: _SuccessfulStatusSource(),
        newsSource: _NewsSource(const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Er zijn nog geen nieuwsberichten.'), findsOneWidget);

    await tester.pumpWidget(
      HkhApp(
        statusSource: _SuccessfulStatusSource(),
        newsSource: _NewsSource(const [], error: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Het laatste nieuws kon niet worden geladen.'),
      findsOneWidget,
    );
  });
}
