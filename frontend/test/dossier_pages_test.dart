import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/dossier/dossier.dart';
import 'package:hkh_app/dossier/dossier_dialogs.dart';
import 'package:hkh_app/dossier/dossier_list_page.dart';
import 'package:hkh_app/dossier/dossier_members_dialog.dart';
import 'package:hkh_app/dossier/dossier_page.dart';
import 'package:hkh_app/theme/app_style.dart';

import 'dossier_test_support.dart';

/// Ieder scherm wordt zowel smal (≤600px) als breed getest.
const _formats = <String, Size>{'smal': narrowSize, 'breed': wideSize};

const _longEmail =
    'een.heel.lang.mailadres.van.een.lid@historische-kring-heemskerk.example';
const _longTitle =
    'De Kerklaan en haar bewoners tussen 1850 en 1970, met alle zijstraten';
const _longGoal =
    'Een uitgebreid artikel schrijven over de ontwikkeling van de Kerklaan en '
    'haar bewoners voor de jubileumuitgave van het verenigingsblad.';

void main() {
  _formats.forEach((format, size) {
    testWidgets('het dossieroverzicht toont dossiers als kaarten ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(
        dossiers: [
          dossierSummary(memberCount: 4),
          dossierSummary(
            id: 'd2',
            title: 'De Sint-Laurentiuskerk',
            role: DossierRole.reader,
            questionCount: 0,
            articleCount: 0,
          ),
        ],
      );
      await pumpDossierApp(tester, DossierListPage(source: source), size: size);

      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(find.text('De Sint-Laurentiuskerk'), findsOneWidget);
      expect(find.text('Artikel voor het verenigingsblad'), findsNWidgets(2));
      expect(find.text('Eigenaar'), findsOneWidget);
      expect(find.text('Lezer'), findsOneWidget);
      expect(find.text('2 vragen'), findsOneWidget);
      expect(find.text('1 artikel'), findsOneWidget);
      expect(find.text('4 leden'), findsOneWidget);
      expect(find.textContaining('Gewijzigd'), findsNWidgets(2));
      expect(find.text('Nieuw dossier'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, appBackground);
      final decoration = cardDecoration(tester, const Key('dossier-card-d1'));
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(appCardRadius));
      expect((decoration.border! as Border).top.color, appCardBorder);

      expect(
        chipDecoration(tester, const Key('role-chip-OWNER')).color,
        appRoleOwnerBackground,
      );
      expect(
        chipDecoration(tester, const Key('role-chip-READER')).color,
        appRoleReaderBackground,
      );
      expect(
        tester.widget<Text>(find.text('Eigenaar')).style?.color,
        appRoleOwnerForeground,
      );
      expect(
        tester.widget<Text>(find.text('Lezer')).style?.color,
        appRoleReaderForeground,
      );

      await tester.tap(find.text('De Kerklaan'));
      await tester.pumpAndSettle();

      expect(source.calls, contains('loadDossier:d1'));
      expect(find.text('Vragen'), findsOneWidget);
      expect(find.text('Feitenlijst'), findsOneWidget);
      expect(find.text('Artikelen'), findsOneWidget);
    });

    testWidgets(
      'het dossieroverzicht zonder dossiers houdt lege status en knop ($format)',
      (tester) async {
        final source = FakeDossierSource(dossiers: []);
        await pumpDossierApp(
          tester,
          DossierListPage(source: source),
          size: size,
        );

        expect(find.text('Nog geen dossiers'), findsOneWidget);
        expect(
          find.textContaining('Een dossier is een onderzoek met een titel'),
          findsOneWidget,
        );
        expect(find.text('Nieuw dossier'), findsOneWidget);

        final decoration = cardDecoration(
          tester,
          const Key('dossier-empty-state'),
        );
        expect(decoration.borderRadius, BorderRadius.circular(appCardRadius));
        expect((decoration.border! as Border).top.color, appCardBorder);
      },
    );

    testWidgets('de dialoog Nieuw dossier valideert en maakt aan ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(dossiers: []);
      await pumpDossierApp(tester, DossierListPage(source: source), size: size);

      await tester.tap(find.text('Nieuw dossier'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dossier-title-field')), findsOneWidget);
      expect(find.byKey(const Key('dossier-goal-field')), findsOneWidget);
      expect(find.text('Annuleren'), findsOneWidget);
      expect(find.text('Aanmaken'), findsOneWidget);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(radiusOf(dialog.shape), BorderRadius.circular(appCardRadius));
      final border =
          fieldBorder(tester, find.byKey(const Key('dossier-title-field')))
              as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(appControlRadius));
      expect(
        buttonRadius(tester, find.byKey(const Key('dossier-submit-button'))),
        BorderRadius.circular(appControlRadius),
      );

      final surface = dialogSurfaceRect(tester);
      if (size == narrowSize) {
        // Smal: de dialoog vult de breedte binnen de normale schermmarges.
        expect(surface.left, closeTo(16, 1));
        expect(surface.right, closeTo(size.width - 16, 1));
      } else {
        expect(surface.width, lessThanOrEqualTo(600));
        expect(surface.center.dx, closeTo(size.width / 2, 1));
      }

      // Zonder titel gebeurt er niets: het titelveld blijft verplicht.
      await tester.tap(find.byKey(const Key('dossier-submit-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        source.calls.where((call) => call.startsWith('createDossier')),
        isEmpty,
      );

      // Het doel blijft optioneel.
      await tester.enterText(
        find.byKey(const Key('dossier-title-field')),
        'Vissersbuurt door de eeuwen heen',
      );
      await tester.tap(find.byKey(const Key('dossier-submit-button')));
      await tester.pumpAndSettle();

      expect(
        source.calls,
        contains('createDossier:Vissersbuurt door de eeuwen heen'),
      );
    });

    testWidgets(
      'de dialoog Nieuw dossier annuleert zonder aanmaken ($format)',
      (tester) async {
        final source = FakeDossierSource(dossiers: []);
        await pumpDossierApp(
          tester,
          DossierListPage(source: source),
          size: size,
        );

        await tester.tap(find.text('Nieuw dossier'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('dossier-title-field')),
          'Vissersbuurt',
        );
        await tester.tap(find.text('Annuleren'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          source.calls.where((call) => call.startsWith('createDossier')),
          isEmpty,
        );
      },
    );

    testWidgets('het dossierdetail toont de drie tabbladen ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(
        detail: dossierDetail(
          sheet: factSheet(dirty: true),
          articles: [articleSummary(proposalState: 'READY')],
        ),
      );
      await pumpDossierApp(
        tester,
        DossierPage(source: source, dossierId: 'd1'),
        size: size,
      );

      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(find.text('Vragen'), findsOneWidget);
      expect(find.text('Feitenlijst'), findsOneWidget);
      expect(find.text('Artikelen'), findsOneWidget);
      expect(find.text('Vragen in dit dossier'), findsOneWidget);
      final firstTab = tester.getRect(find.text('Vragen'));
      final lastTab = tester.getRect(find.text('Artikelen'));
      expect(lastTab.right - firstTab.left, lessThan(500));
      if (format == 'breed') expect(lastTab.right, lessThan(size.width));
      expect(find.text('Doel'), findsOneWidget);
      expect(find.text('Artikel voor het verenigingsblad'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, appBackground);

      await tester.ensureVisible(find.text('Feitenlijst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feitenlijst'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Kerklaan 12: familie Jansen', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Bijgewerkt op'), findsOneWidget);
      expect(find.text('Bewerken'), findsOneWidget);
      expect(find.text('Laten bijwerken'), findsOneWidget);

      final sheetCard = cardDecoration(tester, const Key('fact-sheet-card'));
      expect(sheetCard.borderRadius, BorderRadius.circular(appCardRadius));
      final actionsRect = tester.getRect(
        find.byKey(const Key('fact-sheet-actions')),
      );
      final sheetRect = tester.getRect(
        find.byKey(const Key('fact-sheet-card')),
      );
      expect(
        sheetRect.top - actionsRect.bottom,
        greaterThanOrEqualTo(appSectionGap),
      );

      await tester.tap(find.text('Laten bijwerken'));
      await tester.pumpAndSettle();
      expect(source.calls, contains('refreshFactSheet'));

      await tester.ensureVisible(find.text('Artikelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artikelen'));
      await tester.pumpAndSettle();

      expect(find.text('De bewoners van de Kerklaan'), findsOneWidget);
      expect(find.text('Versie 2'), findsOneWidget);
      expect(find.text('AI-voorstel klaar'), findsOneWidget);
      expect(find.text('Nieuw artikel'), findsOneWidget);
      expect(find.text('Laat AI schrijven'), findsOneWidget);

      final articleCard = cardDecoration(tester, const Key('article-card-a1'));
      expect(articleCard.borderRadius, BorderRadius.circular(appCardRadius));
      final articleActions = tester.getRect(
        find.byKey(const Key('article-actions')),
      );
      final articleRect = tester.getRect(
        find.byKey(const Key('article-card-a1')),
      );
      expect(
        articleRect.top - articleActions.bottom,
        greaterThanOrEqualTo(appSectionGap),
      );
    });

    testWidgets('een lezer houdt de alleen-lezenmelding ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(
        detail: dossierDetail(role: DossierRole.reader),
      );
      await pumpDossierApp(
        tester,
        DossierPage(source: source, dossierId: 'd1'),
        size: size,
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Je bent lezer'), findsOneWidget);

      await tester.ensureVisible(find.text('Artikelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artikelen'));
      await tester.pumpAndSettle();
      expect(find.text('Nieuw artikel'), findsNothing);
    });

    testWidgets('In dossier zetten toont alleen geschikte dossiers ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(
        dossiers: [
          dossierSummary(),
          dossierSummary(
            id: 'd2',
            title: 'Molens van Heemskerk',
            role: DossierRole.reader,
          ),
          dossierSummary(
            id: 'd3',
            title: "Schoolfoto's Kerklaan",
            role: DossierRole.researcher,
          ),
        ],
      );
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showAdoptToDossierDialog(context, source, 'sessie-1'),
        ),
        size: size,
      );
      await openDialog(tester);

      expect(find.text('In dossier zetten'), findsOneWidget);
      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(find.text("Schoolfoto's Kerklaan"), findsOneWidget);
      // Een lezer mag geen vragen stellen, dus dat dossier ontbreekt.
      expect(find.text('Molens van Heemskerk'), findsNothing);
      expect(find.text('Eigenaar'), findsOneWidget);
      expect(find.text('Onderzoeker'), findsOneWidget);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(radiusOf(dialog.shape), BorderRadius.circular(appCardRadius));
      final introRect = tester.getRect(
        find.textContaining('Kies een dossier. Een kopie'),
      );
      final firstRect = tester.getRect(
        find.byKey(const Key('adopt-option-d1')),
      );
      expect(
        firstRect.top - introRect.bottom,
        greaterThanOrEqualTo(appSectionGap),
      );

      await tester.ensureVisible(find.byKey(const Key('adopt-option-d3')));
      await tester.tap(find.byKey(const Key('adopt-option-d3')));
      await tester.pumpAndSettle();
      expect(source.calls, contains('adoptSearch:d3:sessie-1'));
    });

    testWidgets('In dossier zetten meldt het ontbreken van dossiers ($format)', (
      tester,
    ) async {
      final source = FakeDossierSource(
        dossiers: [dossierSummary(role: DossierRole.reader)],
      );
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showAdoptToDossierDialog(context, source, 'sessie-1'),
        ),
        size: size,
      );
      await openDialog(tester);

      expect(
        find.text(
          'Je hebt nog geen dossier waarin je vragen mag stellen. Maak eerst een dossier aan bij Mijn dossiers.',
        ),
        findsOneWidget,
      );
      expect(find.text('Annuleren'), findsOneWidget);
      expect(
        source.calls.where((call) => call.startsWith('adoptSearch')),
        isEmpty,
      );
    });

    testWidgets('Delen en leden geeft de eigenaar alle acties ($format)', (
      tester,
    ) async {
      final detail = dossierDetail(
        members: [
          member(email: 'j.bakker@voorbeeld.nl', role: DossierRole.editor),
          member(email: 'l.smit@voorbeeld.nl'),
        ],
      );
      final source = FakeDossierSource(detail: detail);
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showMembersDialog(context, source: source, detail: detail),
        ),
        size: size,
      );
      await openDialog(tester);

      expect(find.text('Delen en leden'), findsOneWidget);
      expect(find.text('jan@example.com'), findsOneWidget);
      expect(find.text('Eigenaar'), findsOneWidget);
      expect(find.text('j.bakker@voorbeeld.nl'), findsOneWidget);
      expect(find.text('l.smit@voorbeeld.nl'), findsOneWidget);
      expect(find.text('Lid toevoegen'), findsOneWidget);
      expect(
        find.byKey(const Key('member-role-j.bakker@voorbeeld.nl')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('member-remove-j.bakker@voorbeeld.nl')),
        findsOneWidget,
      );

      final lastMember = tester.getRect(
        find.byKey(const Key('member-l.smit@voorbeeld.nl')),
      );
      final addSection = tester.getRect(
        find.byKey(const Key('add-member-section')),
      );
      expect(
        addSection.top - lastMember.bottom,
        greaterThanOrEqualTo(appSectionGap),
      );

      final emailBorder =
          fieldBorder(tester, find.byKey(const Key('new-member-email')))
              as OutlineInputBorder;
      expect(emailBorder.borderRadius, BorderRadius.circular(appControlRadius));

      // De rolkeuze en de verwijderactie stapelen alleen als het moet.
      final emailRect = tester.getRect(find.text('l.smit@voorbeeld.nl'));
      final roleRect = tester.getRect(
        find.byKey(const Key('member-role-l.smit@voorbeeld.nl')),
      );
      if (size == narrowSize) {
        expect(roleRect.top, greaterThanOrEqualTo(emailRect.bottom));
      } else {
        expect(roleRect.left, greaterThan(emailRect.right));
      }

      await tester.enterText(
        find.byKey(const Key('new-member-email')),
        'nieuw@voorbeeld.nl',
      );
      await tester.tap(find.byKey(const Key('add-member-button')));
      await tester.pumpAndSettle();
      expect(source.calls, contains('setMember:nieuw@voorbeeld.nl:RESEARCHER'));

      await tester.tap(
        find.byKey(const Key('member-role-l.smit@voorbeeld.nl')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bewerker').last);
      await tester.pumpAndSettle();
      expect(source.calls, contains('setMember:l.smit@voorbeeld.nl:EDITOR'));

      await tester.tap(
        find.byKey(const Key('member-remove-j.bakker@voorbeeld.nl')),
      );
      await tester.pumpAndSettle();
      expect(source.calls, contains('removeMember:j.bakker@voorbeeld.nl'));
    });

    testWidgets('Delen en leden toont een lid geen beheeracties ($format)', (
      tester,
    ) async {
      final detail = dossierDetail(
        role: DossierRole.researcher,
        members: [
          member(email: 'j.bakker@voorbeeld.nl', role: DossierRole.editor),
        ],
      );
      final source = FakeDossierSource(detail: detail);
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showMembersDialog(context, source: source, detail: detail),
        ),
        size: size,
      );
      await openDialog(tester);

      expect(find.text('jan@example.com'), findsOneWidget);
      expect(find.text('j.bakker@voorbeeld.nl'), findsOneWidget);
      expect(find.text('Bewerker'), findsOneWidget);
      expect(
        find.byKey(const Key('member-role-j.bakker@voorbeeld.nl')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('member-remove-j.bakker@voorbeeld.nl')),
        findsNothing,
      );
      expect(find.byKey(const Key('add-member-section')), findsNothing);
      expect(find.text('Lid toevoegen'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('320px met 200% tekstschaling', () {
    testWidgets('het dossieroverzicht loopt niet over', (tester) async {
      final source = FakeDossierSource(
        dossiers: [
          dossierSummary(title: _longTitle, goal: _longGoal, memberCount: 4),
        ],
      );
      await pumpDossierApp(
        tester,
        DossierListPage(source: source),
        size: tinySize,
        textScaleFactor: 2,
      );

      expectNoHorizontalOverflow(tester, [
        find.byKey(const Key('dossier-card-d1')),
        find.byKey(const Key('role-chip-OWNER')),
      ]);
      // De rolchip staat dan boven de titel in plaats van ernaast.
      final chipRect = tester.getRect(find.byKey(const Key('role-chip-OWNER')));
      final titleRect = tester.getRect(find.text(_longTitle));
      expect(chipRect.bottom, lessThanOrEqualTo(titleRect.top));
    });

    testWidgets('de lege status loopt niet over', (tester) async {
      final source = FakeDossierSource(dossiers: []);
      await pumpDossierApp(
        tester,
        DossierListPage(source: source),
        size: tinySize,
        textScaleFactor: 2,
      );

      expect(find.text('Nog geen dossiers'), findsOneWidget);
      expectNoHorizontalOverflow(tester, [
        find.byKey(const Key('dossier-empty-state')),
      ]);
    });

    testWidgets('de dialoog Nieuw dossier loopt niet over', (tester) async {
      final source = FakeDossierSource(dossiers: []);
      await pumpDossierApp(
        tester,
        DossierListPage(source: source),
        size: tinySize,
        textScaleFactor: 2,
      );
      await tester.tap(find.text('Nieuw dossier'));
      await tester.pumpAndSettle();

      expectNoHorizontalOverflow(tester, [find.byType(AlertDialog)]);
      final surface = dialogSurfaceRect(tester);
      expect(surface.left, closeTo(16, 1));
      expect(surface.right, closeTo(tinySize.width - 16, 1));
    });

    testWidgets('het dossierdetail loopt op geen enkel tabblad over', (
      tester,
    ) async {
      final source = FakeDossierSource(
        detail: dossierDetail(
          title: _longTitle,
          articles: [articleSummary(proposalState: 'READY')],
        ),
      );
      await pumpDossierApp(
        tester,
        DossierPage(source: source, dossierId: 'd1'),
        size: tinySize,
        textScaleFactor: 2,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Feitenlijst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feitenlijst'));
      await tester.pumpAndSettle();
      expectNoHorizontalOverflow(tester, [
        find.byKey(const Key('fact-sheet-card')),
      ]);

      await tester.ensureVisible(find.text('Artikelen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artikelen'));
      await tester.pumpAndSettle();
      expectNoHorizontalOverflow(tester, [
        find.byKey(const Key('article-card-a1')),
      ]);
    });

    testWidgets('In dossier zetten loopt niet over', (tester) async {
      final source = FakeDossierSource(
        dossiers: [dossierSummary(title: _longTitle)],
      );
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showAdoptToDossierDialog(context, source, 'sessie-1'),
        ),
        size: tinySize,
        textScaleFactor: 2,
      );
      await openDialog(tester);

      expectNoHorizontalOverflow(tester, [find.byType(AlertDialog)]);
    });

    testWidgets('Delen en leden kapt lange e-mailadressen af', (tester) async {
      final detail = dossierDetail(
        members: [member(email: _longEmail, role: DossierRole.editor)],
      );
      final source = FakeDossierSource(detail: detail);
      await pumpDossierApp(
        tester,
        DialogHost(
          open: (context) =>
              showMembersDialog(context, source: source, detail: detail),
        ),
        size: tinySize,
        textScaleFactor: 2,
      );
      await openDialog(tester);

      expectNoHorizontalOverflow(tester, [find.byType(AlertDialog)]);

      final emailText = tester.widget<Text>(find.text(_longEmail));
      expect(emailText.overflow, TextOverflow.ellipsis);
      expect(emailText.maxLines, 1);

      // De ledenacties staan onder het e-mailadres, niet er overheen.
      final emailRect = tester.getRect(find.text(_longEmail));
      final roleRect = tester.getRect(
        find.byKey(Key('member-role-$_longEmail')),
      );
      expect(roleRect.top, greaterThanOrEqualTo(emailRect.bottom));
    });
  });
}
