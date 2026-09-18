import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hkh_app/dossier/article_history_page.dart';
import 'package:hkh_app/dossier/article_page.dart';
import 'package:hkh_app/dossier/dossier_page.dart';
import 'package:hkh_app/dossier/dossier.dart';

import 'dossier_test_support.dart';

void main() {
  for (final tab in ['Vragen', 'Feitenlijst', 'Artikelen']) {
    testWidgets('article menu opens dossier tab $tab', (tester) async {
      final source = FakeDossierSource();
      final router = GoRouter(
        initialLocation: '/artikelen/a1',
        routes: [
          GoRoute(
            path: '/artikelen/:id',
            builder: (_, state) => ArticlePage(
              source: source,
              articleId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/dossiers/:id',
            builder: (_, state) => DossierPage(
              source: source,
              dossierId: state.pathParameters['id']!,
              initialTab: int.parse(state.uri.queryParameters['tab']!),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.controller!.index, 2);
      await tester.ensureVisible(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.byType(DossierPage), findsOneWidget);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        ['Vragen', 'Feitenlijst', 'Artikelen'].indexOf(tab),
      );
      expect(source.calls, contains('loadDossier:d1'));
    });
  }
  testWidgets('cancelling article tab navigation preserves unsaved edits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePage(source: FakeDossierSource(), articleId: 'a1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bewerken'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Mijn nog niet opgeslagen tekst',
    );
    await tester.tap(find.text('Vragen'));
    await tester.pumpAndSettle();
    expect(find.text('Wijzigingen niet opgeslagen'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Annuleren'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticlePage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Mijn nog niet opgeslagen tekst',
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
  });

  testWidgets('shows the article, opens the editor and saves with the base', (
    tester,
  ) async {
    final source = FakeDossierSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePage(source: source, articleId: 'a1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('De bewoners van de Kerklaan'), findsOneWidget);
    expect(find.textContaining('Versie 2'), findsOneWidget);
    expect(
      find.textContaining('De familie Jansen woonde op', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Bronnen'), findsOneWidget);
    expect(find.text('Kerklaan 12 in 1932'), findsOneWidget);

    await tester.tap(find.text('Bewerken'));
    await tester.pumpAndSettle();

    expect(find.textContaining('hkh:collection/ident'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(1), 'Nieuwe tekst.');
    await tester.scrollUntilVisible(
      find.text('Opslaan'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Opslaan'));
    await tester.pumpAndSettle();

    expect(source.lastSave, {
      'title': 'De bewoners van de Kerklaan',
      'contentMarkdown': 'Nieuwe tekst.',
      'basedOnVersionId': 'v2',
    });
    expect(find.textContaining('Versie 3'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows a ready proposal with accept and reject', (tester) async {
    final source = FakeDossierSource(
      article: articleDetail(
        proposal: articleVersion(
          id: 'v3',
          number: 3,
          authorKind: 'AI',
          state: 'PROPOSED',
          jobStatus: 'SUCCEEDED',
          changeSummary: 'Hoofdstuk over de school toegevoegd.',
          aiInstruction: 'Voeg een hoofdstuk toe over de school.',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePage(source: source, articleId: 'a1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI-voorstel (versie 3)'), findsOneWidget);
    expect(find.text('Hoofdstuk over de school toegevoegd.'), findsOneWidget);
    expect(find.text('Accepteren'), findsOneWidget);
    expect(find.text('Verwerpen'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Vraag AI om een wijziging'),
              matching: find.bySubtype<FilledButton>(),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Bekijk verschil'));
    await tester.pumpAndSettle();
    expect(source.calls, contains('loadDiff:3:2'));
    expect(find.text('+ Nieuwe regel over de school.'), findsOneWidget);
    expect(find.text('- Oude regel.'), findsOneWidget);

    await tester.tap(find.text('Accepteren'));
    await tester.pumpAndSettle();

    expect(source.calls, contains('acceptProposal:v3'));
    expect(find.text('AI-voorstel (versie 3)'), findsNothing);
    expect(find.textContaining('Versie 3'), findsOneWidget);
  });

  testWidgets('shows a running proposal with progress', (tester) async {
    final source = FakeDossierSource(
      article: articleDetail(
        proposal: articleVersion(
          id: 'v3',
          number: 3,
          authorKind: 'AI',
          state: 'PROPOSED',
          jobStatus: 'RUNNING',
          progressMessage: 'De AI schrijft het hoofdstuk',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePage(source: source, articleId: 'a1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('De AI schrijft het hoofdstuk'), findsOneWidget);
    expect(find.text('Stoppen'), findsOneWidget);
    expect(find.text('Accepteren'), findsNothing);
  });

  testWidgets('history lists versions and shows a diff on tap', (tester) async {
    final source = FakeDossierSource(
      versions: [
        versionSummary(number: 2, isCurrent: true),
        versionSummary(
          number: 1,
          authorKind: 'AI',
          changeSummary: 'Eerste versie geschreven.',
          aiInstruction: 'Schrijf een artikel over de Kerklaan.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleHistoryPage(source: source, article: articleDetail()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Versie 2 (huidig)'), findsOneWidget);
    expect(find.text('Versie 1'), findsOneWidget);
    expect(find.text('Eerste versie geschreven.'), findsOneWidget);
    expect(find.text('Geaccepteerd'), findsNWidgets(2));
    expect(find.text('Terugzetten'), findsOneWidget);

    await tester.tap(find.text('Versie 1'));
    await tester.pumpAndSettle();

    expect(source.calls, contains('loadDiff:1:2'));
    expect(find.text('+ Nieuwe regel over de school.'), findsOneWidget);
  });

  testWidgets(
    'offers the pdf export between history and delete and hands the file over',
    (tester) async {
      final source = FakeDossierSource();
      final saved = <String, Uint8List>{};
      await tester.pumpWidget(
        MaterialApp(
          home: ArticlePage(
            source: source,
            articleId: 'a1',
            pdfSaver: (fileName, bytes) async => saved[fileName] = bytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Artikelmenu'));
      await tester.pumpAndSettle();

      expect(menuText('Exporteren als PDF'), findsOneWidget);
      final export = tester.getTopLeft(menuText('Exporteren als PDF')).dy;
      expect(
        export,
        greaterThan(tester.getTopLeft(menuText('Geschiedenis')).dy),
      );
      expect(
        export,
        lessThan(tester.getTopLeft(menuText('Artikel verwijderen')).dy),
      );
      final item =
          tester.widget(
                find
                    .ancestor(
                      of: menuText('Exporteren als PDF'),
                      matching: find.byWidgetPredicate(
                        (widget) => widget is PopupMenuItem,
                      ),
                    )
                    .first,
              )
              as PopupMenuItem;
      expect(item.enabled, isTrue);

      await tester.tap(menuText('Exporteren als PDF'));
      await tester.pumpAndSettle();

      expect(source.calls, contains('exportArticlePdf:d1:a1'));
      expect(saved.keys.toList(), ['artikel-a1.pdf']);
      expect(saved['artikel-a1.pdf'], isNotEmpty);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'a failed export shows the retry snackbar and keeps the article',
    (tester) async {
      final source = FakeDossierSource()..failArticlePdf = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ArticlePage(
            source: source,
            articleId: 'a1',
            pdfSaver: (fileName, bytes) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Artikelmenu'));
      await tester.pumpAndSettle();
      await tester.tap(menuText('Exporteren als PDF'));
      await tester.pumpAndSettle();

      expect(
        find.text('PDF-export mislukt. Probeer het opnieuw.'),
        findsOneWidget,
      );
      expect(find.text('Opnieuw'), findsOneWidget);
      // Het artikel blijft volledig zichtbaar en er is niet genavigeerd.
      expect(find.byType(ArticlePage), findsOneWidget);
      expect(find.text('De bewoners van de Kerklaan'), findsOneWidget);
      expect(find.text('Bronnen'), findsOneWidget);
      expect(find.text('Kerklaan 12 in 1932'), findsOneWidget);

      // "Opnieuw" doet exact dezelfde exportpoging nog een keer.
      await tester.tap(find.text('Opnieuw'));
      await tester.pumpAndSettle();

      expect(
        source.calls.where((call) => call == 'exportArticlePdf:d1:a1').length,
        2,
      );
      expect(find.byType(ArticlePage), findsOneWidget);
    },
  );

  testWidgets('the pdf export is absent until a version is loaded', (
    tester,
  ) async {
    final source = PendingArticleSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePage(
          source: source,
          articleId: 'a1',
          pdfSaver: (fileName, bytes) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Artikelmenu'), findsNothing);
    expect(menuText('Exporteren als PDF'), findsNothing);

    source.complete(articleDetail());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Artikelmenu'));
    await tester.pumpAndSettle();
    expect(menuText('Exporteren als PDF'), findsOneWidget);
  });
}

/// Tekst van een item uit het artikelmenu; het scherm zelf heeft knoppen met
/// dezelfde labels.
Finder menuText(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

/// Houdt het laden van het artikel open, zodat de toestand vóór de eerste
/// artikelversie te testen is.
class PendingArticleSource extends FakeDossierSource {
  final _pending = Completer<ArticleDetail>();

  void complete(ArticleDetail detail) => _pending.complete(detail);

  @override
  Future<ArticleDetail> loadArticle(String articleId) => _pending.future;
}
