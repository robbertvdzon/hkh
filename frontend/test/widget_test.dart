import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/auth/user_session.dart';
import 'package:hkh_app/main.dart';
import 'package:hkh_app/collection/collection_search.dart';

import 'dossier_test_support.dart';

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
    int? year,
    int page = 0,
    int size = 20,
  }) async => SearchPage(
    items: results,
    total: results.length,
    page: 0,
    pageSize: size,
  );
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
  testWidgets(
    'shows the introduction and a search box with uitgebreid zoeken',
    (tester) async {
      await tester.pumpWidget(HkhApp(searchSource: _SearchSource()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Ontdek de geschiedenis van Heemskerk vanuit een vraag',
        ),
        findsOneWidget,
      );
      expect(find.text('Zoeken'), findsOneWidget);
      expect(find.text('Uitgebreid zoeken'), findsOneWidget);

      await tester.tap(find.text('Uitgebreid zoeken'));
      await tester.pumpAndSettle();

      expect(find.text('Jaar'), findsOneWidget);
    },
  );

  testWidgets(
    'the homepage search box shows results without leaving the page',
    (tester) async {
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
      await tester.pumpWidget(HkhApp(searchSource: searchSource));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'ansichtkaart');
      await tester.tap(find.text('Zoeken'));
      await tester.pumpAndSettle();

      expect(find.text('Straten Maerten van Heemskerckstraat'), findsOneWidget);
      expect(find.text('Alle 1 resultaten'), findsOneWidget);
    },
  );

  testWidgets('shows no login button when Google login is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(HkhApp(searchSource: _SearchSource()));
    await tester.pumpAndSettle();

    expect(find.text('Inloggen'), findsNothing);
  });

  testWidgets(
    'a signed-in user gets an account menu with dossiers and logout',
    (tester) async {
      final session = _SignedInSession();
      await tester.pumpWidget(
        HkhApp(
          searchSource: _SearchSource(),
          dossierSource: FakeDossierSource(),
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jan Jansen'), findsOneWidget);
      expect(find.text('Inloggen'), findsNothing);

      await tester.tap(find.text('Jan Jansen'));
      await tester.pumpAndSettle();

      expect(find.text('Mijn dossiers'), findsOneWidget);
      expect(find.text('Uitloggen'), findsOneWidget);

      await tester.tap(find.text('Mijn dossiers'));
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(find.text('Nieuw dossier'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Jansen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uitloggen'));
      await tester.pumpAndSettle();

      expect(session.signOutCalls, 1);
      expect(find.text('Jan Jansen'), findsNothing);
      expect(find.text('Inloggen'), findsOneWidget);
    },
  );
}
