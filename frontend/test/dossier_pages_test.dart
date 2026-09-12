import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/dossier/dossier.dart';
import 'package:hkh_app/dossier/dossier_list_page.dart';
import 'package:hkh_app/dossier/dossier_page.dart';

import 'dossier_test_support.dart';

void main() {
  testWidgets('the dossier list shows dossiers and opens one', (tester) async {
    final source = FakeDossierSource(
      dossiers: [
        dossierSummary(),
        dossierSummary(
          id: 'd2',
          title: 'De Sint-Laurentiuskerk',
          role: DossierRole.reader,
          questionCount: 0,
          articleCount: 0,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: DossierListPage(source: source)));
    await tester.pumpAndSettle();

    expect(find.text('De Kerklaan'), findsOneWidget);
    expect(find.text('De Sint-Laurentiuskerk'), findsOneWidget);
    expect(find.text('Eigenaar'), findsOneWidget);
    expect(find.text('Lezer'), findsOneWidget);
    expect(find.text('2 vragen'), findsOneWidget);
    expect(find.text('1 artikel'), findsOneWidget);
    expect(find.text('Nieuw dossier'), findsOneWidget);

    await tester.tap(find.text('De Kerklaan'));
    await tester.pumpAndSettle();

    expect(source.calls, contains('loadDossier:d1'));
    expect(find.text('Vragen'), findsOneWidget);
    expect(find.text('Feitenlijst'), findsOneWidget);
    expect(find.text('Artikelen'), findsOneWidget);
  });

  testWidgets('the dossier list explains and offers nothing without dossiers', (
    tester,
  ) async {
    final source = FakeDossierSource(dossiers: []);
    await tester.pumpWidget(MaterialApp(home: DossierListPage(source: source)));
    await tester.pumpAndSettle();

    expect(find.text('Nog geen dossiers'), findsOneWidget);
  });

  testWidgets('the dossier page shows three tabs and the fact sheet', (
    tester,
  ) async {
    final source = FakeDossierSource(
      detail: dossierDetail(
        sheet: factSheet(dirty: true),
        articles: [articleSummary(proposalState: 'READY')],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DossierPage(source: source, dossierId: 'd1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('De Kerklaan'), findsOneWidget);
    expect(find.text('Vragen in dit dossier'), findsOneWidget);

    await tester.tap(find.text('Feitenlijst'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kerklaan 12: familie Jansen', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Bijgewerkt op'), findsOneWidget);
    expect(find.text('Bewerken'), findsOneWidget);
    expect(find.text('Laten bijwerken'), findsOneWidget);

    await tester.tap(find.text('Laten bijwerken'));
    await tester.pumpAndSettle();
    expect(source.calls, contains('refreshFactSheet'));

    await tester.tap(find.text('Artikelen'));
    await tester.pumpAndSettle();

    expect(find.text('De bewoners van de Kerklaan'), findsOneWidget);
    expect(find.text('Versie 2'), findsOneWidget);
    expect(find.text('AI-voorstel klaar'), findsOneWidget);
    expect(find.text('Nieuw artikel'), findsOneWidget);
    expect(find.text('Laat AI schrijven'), findsOneWidget);
  });

  testWidgets('a reader sees no composer and no article buttons', (
    tester,
  ) async {
    final source = FakeDossierSource(
      detail: dossierDetail(role: DossierRole.reader),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DossierPage(source: source, dossierId: 'd1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Je bent lezer'), findsOneWidget);

    await tester.tap(find.text('Artikelen'));
    await tester.pumpAndSettle();
    expect(find.text('Nieuw artikel'), findsNothing);
  });
}
