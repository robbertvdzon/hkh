# hkh-250 — PDF-export voor dossierartikelen: exportendpoint in dossier-module en menu-item in article_page.dart

## Plan

- [x] Repository-instructies, `docs/factory/development.md` en de mockups (ux-05 t/m ux-08) lezen.
- [x] Vooraf verifiëren dat de bouwstenen uit hkh-243 aanwezig zijn: `nl.vdzon.hkh.docexport`
  met `HtmlToPdfRenderer.render(title, bodyHtml, sources)` en de frontend deel-/downloadafhandeling
  (`answer_pdf_saver.dart`, web-download + `share_plus`).
- [x] Backend: `dossier/package-info.java` uitbreiden met `docexport`.
- [x] Backend: `ArticleExportService` die de huidige artikelversie via het bestaande
  autorisatiepad ophaalt en via de gedeelde renderer naar PDF-bytes omzet.
- [x] Backend: endpoint `GET /api/dossiers/{dossierId}/articles/{articleId}/export/pdf`
  in `ArticleController`.
- [x] Backend: tests (servicetest zonder Spring, controllertest, endpoint-integratietest,
  modulith-verificatie).
- [x] Frontend: `exportArticlePdf` op `DossierSource` en in `BackendClient`.
- [x] Frontend: menu-item 'Exporteren als PDF' tussen 'Geschiedenis' en 'Artikel verwijderen',
  met één gedeeld exportpad en foutsnackbar.
- [x] Frontend: widgettests voor zichtbaarheid/positie, foutpad en de toestand vóór het laden.
- [x] Volledig vangnet draaien (`mvn clean verify`, `flutter analyze`/`test` in beide Flutter-apps).

## Gerealiseerd

### Backend

- `dossier/package-info.java`: `allowedDependencies` is nu
  `{"auth", "aisearch", "collection", "docexport"}`. `docexport` houdt een lege
  `allowedDependencies` en krijgt dus geen afhankelijkheid terug op `dossier`; de
  Spring Modulith-verificatie in `ModulithArchitectureTest` slaagt.
- Nieuw: `dossier/ArticleExportService.kt` met `ArticlePdf`, `ArticleExportFailedException`
  en `exportArticle(dossierId, articleId, user)`.
  - Haalt de huidige artikelversie op via `ArticleService.get(articleId, user)` — precies
    hetzelfde autorisatiepad (`dossiers.access`) als de bestaande artikel-endpoints. Er is
    geen apart, zwakker of sterker pad en geen nieuw gekozen foutstatus.
  - Een artikel dat niet bij het gevraagde dossier hoort geeft dezelfde 404 als een
    onbekend artikel.
  - Gebruikt exact de `contentHtml` die `MarkdownRenderer` voor het scherm produceert;
    er wordt niet opnieuw gerenderd en niet opnieuw (of zwakker) gesaniteerd.
  - Bronregels zijn de bronnen van het artikelscherm: `titel · collection/ident — detailUrl`.
    Miniaturen zitten niet in de PDF; de tekstuele bronvermelding is leidend.
  - Rendert volledig in geheugen op een aparte task met een timeout van 20 s (zelfde
    patroon als `AiAnswerExportService`); bij elke fout volgt `ArticleExportFailedException`
    en verlaten er nooit halve bytes de service. Er wordt niets opgeslagen of gecachet.
- `dossier/api/ArticleController.kt`: endpoint
  `GET /api/dossiers/{dossierId}/articles/{articleId}/export/pdf`.
  - `sessions.requireUser(authorization)` zoals de andere artikel-endpoints.
  - Succes: `Content-Type: application/pdf`, `Content-Disposition: attachment` met
    `artikel-<articleId>.pdf`, `Cache-Control: no-store`, `Content-Length` en de bytes.
  - `ArticleExportFailedException` wordt een 500 **zonder** lichaam; autorisatie- en
    ophaalfouten propageren ongewijzigd met dezelfde status als op de bestaande endpoints.

### Frontend

- `lib/dossier/dossier.dart`: `DossierSource.exportArticlePdf(dossierId, articleId)`.
- `lib/backend/backend_client.dart`: implementatie op hetzelfde pad als de backend, met de
  bestaande `_pdfExportTimeout` van 30 s. Alleen een 200 met `application/pdf` én een
  niet-lege body telt als geslaagd; 401 meldt zoals elders de verlopen sessie.
- `lib/dossier/article_page.dart`:
  - Menu-item 'Exporteren als PDF' met `Icons.description_outlined`, geplaatst tussen
    'Geschiedenis' en 'Artikel verwijderen' (conform ux-05 en ux-06). Het menu is
    ongewijzigd voor de rest; lay-out en navigatie van het scherm blijven gelijk.
  - Vóór het laden van een artikelversie bestaat het hele artikelmenu nog niet
    (`if (article != null && !_editing)`), dus het exportitem is **afwezig** — de bestaande
    gedragsvariant van dit menu. De widgettest legt die variant vast.
  - Eén gedeelde `_exportPdf()` voor web en Android: dezelfde aanroep, dezelfde
    `AnswerPdfSaver` uit `ai_search/answer_pdf_saver.dart` (web-download via Blob,
    Android tijdelijk bestand + `share_plus`) en één gemeenschappelijk foutpad. Geen tweede
    PDF-bibliotheek, renderpad of deelmechanisme; geen extra Android-permissies.
  - Bestandsnaam `artikel-<articleId>.pdf`; een lege body wordt als fout behandeld.
  - Bij elke mislukking verschijnt de snackbar 'PDF-export mislukt. Probeer het opnieuw.'
    met actie 'Opnieuw' (ux-07, ux-08), die exact dezelfde poging herhaalt. Er wordt niet
    genavigeerd en het artikel (inclusief bronnenblok) blijft zichtbaar.

### Tests

- `dossier/ArticleExportServiceTest.kt` (zonder Spring, zonder database — draait dus ook
  zonder Docker): draait op een **echte** `ArticleService` + `MarkdownRenderer` met mocks voor
  repository, `DossierService` en `CollectionSearchService`.
  - PDF-inhoud via PDFBox-tekstextractie: titel, artikeltekst, kop 'Bronnen' en de
    bronvermelding met detaillink.
  - De HTML die naar de renderer gaat is byte-voor-byte gelijk aan `current.contentHtml`
    van het artikelscherm; ruwe `<script>` en een losse afbeelding in de Markdown komen er
    niet als element in terug.
  - Geen dossiertoegang levert dezelfde `statusCode` op als `ArticleService.get` — expliciet
    vergeleken in plaats van hard gecodeerd.
  - Artikel uit een ander dossier → 404; renderfout → `ArticleExportFailedException`.
- `dossier/api/ArticleExportControllerTest.kt`: headers en body bij succes, 500 zonder body
  bij een renderfout, en twee statusvergelijkingen met het bestaande `GET /api/articles/{id}`
  (geen toegang en geen sessie).
- `dossier/api/ArticleExportApiIntegrationTest.kt` (Testcontainers, `disabledWithoutDocker`):
  HTTP-contract tegen een echte database, statusvergelijking met het bestaande endpoint en
  een renderfout zonder lichaam via de al bestaande `SwitchableRenderer` uit hkh-243.
- `frontend/test/article_page_test.dart`: (a) het exportitem staat na het laden zichtbaar en
  actief tussen 'Geschiedenis' en 'Artikel verwijderen' en levert de bytes met naam
  `artikel-a1.pdf` bij de saver af, (b) een gesimuleerde mislukking toont exact
  'PDF-export mislukt. Probeer het opnieuw.' met 'Opnieuw', zonder navigatie en met het
  artikel plus bronnenblok nog zichtbaar, waarna 'Opnieuw' dezelfde poging herhaalt,
  (c) vóór de eerste artikelversie is het item afwezig.
- `frontend/test/backend_client_test.dart`: het exportpad en de afwijzing van een antwoord
  dat geen niet-lege `application/pdf` is.
- `frontend/test/dossier_test_support.dart`: `FakeDossierSource` implementeert
  `exportArticlePdf` met een instelbaar foutpad (`failArticlePdf`).

## Verificatie

Volledig vangnet uit `docs/factory/development.md`, alles groen:

- `backend-maven-verify` (`mvn -B --no-transfer-progress clean verify`): BUILD SUCCESS,
  Tests run: 101, Failures: 0, Errors: 0, Skipped: 37.
- `frontend-flutter-analyze`: No issues found!
- `frontend-flutter-test`: 87 tests passed.
- `admin-flutter-analyze`: No issues found!
- `admin-flutter-test`: 8 tests passed.

De 37 overgeslagen backendtests zijn de `@Testcontainers(disabledWithoutDocker = true)`-klassen;
het execution-image heeft geen Docker-daemon. Daarom bewijzen de Docker-vrije
`ArticleExportServiceTest` en `ArticleExportControllerTest` het gedrag (PDF-inhoud,
autorisatiestatus, foutpad) ook in deze omgeving.

## Niet gedaan / aangepast

- De bouwstenen uit story `8b819453-…` (hkh-243) waren volledig aanwezig; er is niets aan de
  gedeelde `docexport`-module of aan het AI-antwoordscherm gewijzigd.
- Het endpoint is aan de bestaande `ArticleController` toegevoegd in plaats van aan een aparte
  controllerklasse: het hoort bij dezelfde artikelroutes en hergebruikt daar `sessions`.
- De gedeelde saver heet nog `saveAnswerPdf` in `ai_search/answer_pdf_saver.dart`. Hij is
  hergebruikt zoals hij is; hernoemen zou het AI-antwoordscherm raken en valt buiten scope.
- Deze worklog is een extra bestand naast de in de story genoemde bestanden; dat volgt de
  worklog-conventie uit `docs/factory/agents/developer.md`.
