# hkh-229 — Dossierschermen herstijlen en tests/documentatie bijwerken

## Plan

- [x] Repository-instructies, `docs/factory/development.md`, de bestaande
  dossierschermen en de mockups ux-11 t/m ux-22 lezen.
- [x] De stijltokens van de homepage uit `main.dart` halen en herbruikbaar maken.
- [x] Dossieroverzicht, `Nieuw dossier`, dossierdetail met de drie tabbladen,
  `In dossier zetten` en `Delen en leden` in de gedeelde vormgeving zetten.
- [x] Responsief gedrag regelen: ≤600 px volle dialoogbreedte, verticale
  stapeling en geen overflow bij 320 px met 200% tekstschaling.
- [x] `dossier_pages_test.dart` en `dossier_test_support.dart` uitbreiden met
  ieder voorgeschreven scenario op smal én breed formaat.
- [x] Sectie 4 van `docs/architecture/accounts-en-dossiers.md` bijwerken.
- [x] Gerichte analyse en de volledige frontendtests draaien.

## Gerealiseerd

- `frontend/lib/theme/app_style.dart` is nieuw en bevat de gedeelde vormgeving:
  `#FBF6EE`, `#1F3B2E`, `#D9CFBB`, kaartafronding 16 px, veld- en knopafronding
  10 px, sectieritme van 32 px, de vier rolchipkleuren, `appSurfaceTheme`
  (velden/knoppen zoals de homepage), `appDossierTheme` (kaarten, appbalk,
  tabbladen, FAB) en de bouwstenen `AppDialog` en `AppCard`.
- `frontend/lib/main.dart` gebruikt diezelfde tokens en `appSurfaceTheme`; de
  homepage is daarmee ongewijzigd maar niet langer de enige plek met de waarden.
- `DossierListPage` heeft een crèmekleurige achtergrond, een appbalk met groene
  titel en hairline, kaarten van 16 px met rand `#D9CFBB`, rolchips in de
  voorgeschreven kleuren en een lege status als kaart. Teksten, `Nieuw dossier`,
  vernieuwen, laden en navigatie zijn ongewijzigd.
- `showDossierDialog`, `showAdoptToDossierDialog`, `showMembersDialog`, de
  bevestigingsdialoog en de artikeldialogen lopen via `AppDialog`: witte kaart
  van 16 px, groene titel, velden en knoppen van 10 px, scrollbare inhoud en
  ≤600 px de volle breedte binnen de schermmarges.
- `DossierPage` en de tabbladen Feitenlijst en Artikelen zijn visueel
  bijgewerkt (secties van 32 px, kaarten met rand, statuschips, groene
  accenten). Vragen blijft de embedded `AiSearchPage` met dezelfde teksten,
  bronnen en alleen-lezenmelding; die erft nu het dossierthema.
- `Delen en leden` toont eigenaar en leden met een e-mailadres op één regel met
  ellipsis. Bij weinig ruimte (smal scherm of grote letters) staan de rolkeuze
  en de verwijderactie op een eigen regel onder het adres. De `canManage`-
  autorisatie en alle acties zijn ongewijzigd.
- `In dossier zetten` filtert nog steeds op `canResearch` en houdt de bestaande
  melding als er geen geschikt dossier is.
- `frontend/test/dossier_pages_test.dart` dekt alle negen scenario's zowel smal
  (360 px) als breed (1280 px), plus vijf overflowtests op 320 px met 200%
  tekstschaling, inclusief de ellipsis van een lang e-mailadres en de gestapelde
  ledenacties. `dossier_test_support.dart` heeft daarvoor viewport-, dialoog- en
  stijlhulpmiddelen gekregen.
- Sectie 4 van `docs/architecture/accounts-en-dossiers.md` beschrijft de
  gedeelde vormgeving; dossiermodel en rollenmatrix zijn ongemoeid gelaten.

## Verificatie

- `flutter analyze` in `frontend/`: geen issues.
- `flutter test --reporter github` in `frontend/`: 65 tests geslaagd.
- `flutter analyze` en `flutter test` in `frontend-admin/`: ongewijzigd groen.
- Geen `pubspec.lock`-churn ontstaan.

## Niet gedaan / aangepast

- Geen wijzigingen aan dossier-CRUD, rollen, autorisatie, routes, backend-API's,
  AI-zoeklogica of bestaande meldingen; alleen de presentatielaag is aangepast.
- De homepage is functioneel en visueel ongewijzigd; alleen de tokens zijn naar
  het gedeelde bestand verplaatst.
- Artikelscherm, artikelgeschiedenis en de AI-zoekpagina zelf vallen buiten deze
  story en zijn niet herstijld; ze erven alleen het dossierthema waar ze binnen
  een dossierscherm getoond worden.
