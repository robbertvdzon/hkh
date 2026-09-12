import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/dossier/article_history_page.dart';
import 'package:hkh_app/dossier/article_page.dart';

import 'dossier_test_support.dart';

void main() {
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
      scrollable: find.byType(Scrollable).first,
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
              matching: find.byType(FilledButton),
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
}
