# HKH user frontend

De Flutter-app voor bezoekers (web en Android).

## Inhoud

- Homepage (`lib/main.dart`) met een primaire AI-vraagroute, een ondergeschikte
  collectiezoeker en een responsieve appbalk. De pagina rendert direct en toont
  geen technische status- of versie-informatie.
- Gedeelde vormgeving (`lib/theme/app_style.dart`): de kleuren, afrondingen,
  rolchipkleuren, thema's en bouwstenen (`AppDialog`, `AppCard`) die de homepage
  en de dossierschermen en -dialogen samen gebruiken. Nieuwe schermen halen deze
  waarden hier op in plaats van ze opnieuw te definiëren.
- Publieke luchtfotopagina (`/#/luchtfoto`, `lib/aerial/`) via **Luchtfoto** in
  het vaste menu. De aangeleverde historische opname rond 1963 en de moderne
  AI-bewerking vanuit dezelfde kijkhoek zijn uitgelijnd op de Dorpskerk.
  De vergelijking toont hun gezamenlijke uitsnede; beide foto's delen één
  zoom- en verplaatsingstransformatie. De schuifbalk laat de beelden overvloeien.
  Knoppen ondersteunen in-/uitzoomen, verplaatsen, de hele foto en direct de
  Dorpskerk. De moderne opname is herkenbaar als AI-bewerking; de omgeving is
  geen exact gereconstrueerde landkaart. De zeven originele boekfoto's blijven
  afzonderlijk beschikbaar. De gebundelde beelden en hun herkomst staan in
  `assets/aerial/`; deze pagina vraagt geen login of backend.
- AI-archiefonderzoek met een overzicht van eerdere vragen, voortgang,
  antwoorden en bronnen (`lib/ai_search/`). Nieuwe vragen starten vanuit het
  overzicht een aparte zoekopdracht; bij een antwoord staan geen vervolgvraagveld
  of suggestieknoppen. Foto's openen schermvullend met zoomknoppen,
  tweevingerzoomen en sluiten via Escape of het kruisje. Bronlinks openen een
  popup met collectiegegevens; **Open volledige pagina** opent desgewenst een
  nieuw tabblad. PDF's in deze popup en op de volledige objectpagina tonen de eerste pagina als afbeelding;
  aanklikken of **PDF openen** opent de volledige PDF in een nieuw tabblad.
  Sluiten behoudt de leespositie in het antwoord. Zodra een antwoord
  geladen is, staat naast het geschiedenis-icoon de appbalkactie **Exporteer als
  PDF**: op web start een directe download van `antwoord-<id>.pdf`, op Android
  opent een deel-/opslagdialoog voor hetzelfde bestand
  (`lib/ai_search/answer_pdf_saver.dart` kiest dat per platform via een
  conditionele import). Mislukt de export, dan blijft het antwoord staan en
  verschijnt de snackbar **PDF-export mislukt. Probeer het opnieuw.** met de
  actie **Opnieuw**.
- Gewoon en uitgebreid collectiezoeken, resultaten en itemdetails
  (`lib/collection/`).
- Optionele Google-login en onderzoeksdossiers met vragen, feitenlijsten,
  artikelen, versiegeschiedenis en delen (`lib/auth/` en `lib/dossier/`). Voor
  ingelogde gebruikers opent de losse appbalkactie **Mijn dossiers** deze
  functionaliteit; het accountmenu bevat alleen **Uitloggen**. De
  dossierschermen en -dialogen volgen dezelfde vormgeving als de homepage.
  Het artikelmenu (`lib/dossier/article_page.dart`) bevat tussen **Geschiedenis**
  en **Artikel verwijderen** het item **Exporteren als PDF** voor de huidige
  artikelversie: op web een directe download van `artikel-<articleId>.pdf`, op
  Android de deel-/opslagdialoog van dezelfde `answer_pdf_saver.dart`. Vóór het
  laden van een artikelversie en tijdens het bewerken is het menu er niet.
  Mislukt de export, dan blijft het artikel staan en verschijnt dezelfde
  snackbar **PDF-export mislukt. Probeer het opnieuw.** met **Opnieuw**.
- Self-update-check bij het openen van de app (`lib/update_checker.dart`,
  `lib/self_update_prompt.dart`), die op niet-webplatformen tegen de GitHub-API
  praat.

## Backendkoppeling

`BackendClient` (`lib/backend/backend_client.dart`) implementeert de
datasource-interfaces voor collectiezoeken, AI-archiefonderzoek, de PDF-export
van een AI-antwoord (`AiAnswerPdfSource`) en dossiers, inclusief de
artikel-PDF-export (`DossierSource.exportArticlePdf`). De optionele
gebruikerssessie staat in `lib/auth/user_session.dart`. Deze clients
roepen de bijbehorende routes onder `/api/collections`, `/api/ai-search`,
`/api/dossiers`, `/api/articles` en `/api/auth` aan. De homepage gebruikt geen
`/actuator/health` of `/api/version`; die endpoints zijn alleen voor monitoring
en deploy.

De basis-URL komt uit `AppConfig.apiBaseUrl`, in te stellen met
`--dart-define=API_BASE_URL=...` (standaard `http://localhost:8080`).

## Commands

```bash
flutter analyze
flutter test
flutter run -d chrome
```

Controleer fotoklikken en zoomgebaren ook in de gewone browsermodus, zonder
**Enable accessibility** in te schakelen. De HTML-platformviews en hun
eventafhandeling worden niet volledig nagebootst door Flutter-widgettests.

Zie `docs/factory/development.md` voor het volledige vangnet en
`docs/factory/functional-spec.md` voor het functionele gedrag.
