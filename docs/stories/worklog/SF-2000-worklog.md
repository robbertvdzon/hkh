# SF-2000 - Worklog

Story-context bij eerste pickup:
Backendstatus-koppeling uit homepage verwijderen

1) frontend/lib/main.dart: verwijder de statuskaart 'Service beschikbaar' (incl. 'application version · commit') en de statusafhankelijkheid van de pagina: de FutureBuilder<BackendStatus>, _status, _retry(), _LoadingState en _ErrorState ('De HKH-service is niet bereikbaar'). Render de inhoud van _ReadyState direct als body (introtekst, knop 'Lees onze productvisie', kop 'Laatste nieuws' + _LatestNewsSection) en houd de spacing net. Verwijder de statusSource-parameter uit HkhApp en HomePage en het meegeven ervan in main(); HomePage blijft stateful vanwege maybePromptSelfUpdate in initState (gedrag ongewijzigd). 2) Ruim dode code op: verwijder frontend/lib/backend/backend_status.dart (BackendStatus, BackendStatusSource) en BackendClient.load() inclusief de calls naar /actuator/health en /api/version; BackendClient implementeert alleen nog LatestNewsSource. Geen ongebruikte imports laten staan. 3) Werk frontend/test/widget_test.dart bij (tests schrijven hoort bij deze subtaak): verwijder de statusfixtures en de assertie op 'hkh test · abc123'; dek minimaal (a) homepage toont introtekst + nieuws en (b) homepage met falende nieuwsbron toont nog steeds introtekst en de knop naar de productvisie plus binnen de nieuws-sectie 'Het laatste nieuws kon niet worden geladen.' met 'Opnieuw proberen'. Bestaande tests voor lege nieuwslijst en navigatie naar de productvisie behouden. backend_client_test.dart blijft ongewijzigd en groen. 4) Vul docs/factory/ met concrete repo-informatie: development.md met de echte build-, test- en lint-commando's per module (geen TODO's), technical-spec.md met de gebruikte stack (Flutter/Dart frontends, Spring Boot/Maven backend) en README.md met een korte beschrijving van backend/, frontend/, frontend-admin/, deploy/ en tools/. De genoemde commando's moeten overeenkomen met .factory/verification.yaml (backend-maven-verify, frontend-flutter-analyze, frontend-flutter-test, admin-flutter-analyze, admin-flutter-test); pas verification.yaml alleen aan als er een commando ontbreekt. 5) Verifieer zelf: 'flutter analyze' en 'flutter test' in frontend/ groen en zonder nieuwe waarschuwingen, en grep repo-breed op 'Service beschikbaar', 'statusSource' en 'BackendStatus' om achterblijvers uit te sluiten. Sluit af met een eigen review van de diff. Buiten scope: de backend-endpoints, de self-update-flow en frontend-admin/.

Stappenplan:
[x]: read issue and target docs
[x]: implement requested changes
[x]: run relevant tests
[x]: update story-log with results

Done / rationale:
- Story-log aangemaakt zodat plan, voortgang en uitvoering onderdeel worden van de PR.

## SF-2001 — Backendstatus-koppeling uit homepage verwijderen (developer)

Gedaan:
- `frontend/lib/main.dart`: statuskaart 'Service beschikbaar' (incl.
  `application version · commit`) verwijderd, samen met de `FutureBuilder<BackendStatus>`,
  `_status`, `_retry()`, `_LoadingState` en `_ErrorState`. De inhoud van het oude
  `_ReadyState` is hernoemd naar `_HomeContent` en wordt direct als body gerenderd;
  de spacing rond 'Laatste nieuws' is samengevoegd tot één `SizedBox(height: 28)`.
  `statusSource` is verdwenen uit `HkhApp`, `HomePage` en `main()`. `HomePage` blijft
  stateful voor `maybePromptSelfUpdate` in `initState` (gedrag ongewijzigd).
- Dode code opgeruimd: `frontend/lib/backend/backend_status.dart` verwijderd en
  `BackendClient.load()` (calls naar `/actuator/health` en `/api/version`) geschrapt.
  `BackendClient` implementeert nog alleen `LatestNewsSource`; geen ongebruikte imports.
- `frontend/test/widget_test.dart` herschreven: statusfixtures en de assertie op
  `hkh test · abc123` zijn weg. Drie tests: (a) introtekst + nieuws + navigatie naar
  de productvisie, (b) falende nieuwsbron toont nog steeds introtekst en de knop naar
  de productvisie plus 'Het laatste nieuws kon niet worden geladen.' met
  'Opnieuw proberen' én expliciet géén 'De HKH-service is niet bereikbaar',
  (c) lege nieuwslijst. `backend_client_test.dart` ongewijzigd.
- `docs/factory/development.md`, `technical-spec.md` en `README.md` gevuld met concrete
  repo-informatie (echte build-/test-/lintcommando's per module, stack, moduleoverzicht).
  `.factory/verification.yaml` bevatte alle vijf commando's al en is niet gewijzigd.

Waarom: de statuskaart was ontwikkelaarsinformatie en de enige consument van de
statuscall; door de call te laten vervallen opent de homepage direct en blijft ze
bruikbaar zonder backend. Het nieuwsblok meldt zelf al wanneer data ontbreekt.

Verificatie (volledig vangnet, alle exitcode 0):
- `backend-maven-verify`: BUILD SUCCESS, Tests run: 20, Failures: 0, Errors: 0
- `frontend-flutter-analyze`: No issues found!
- `frontend-flutter-test`: 5 tests passed
- `admin-flutter-analyze`: No issues found!
- `admin-flutter-test`: 4 tests passed

Repo-brede grep op 'Service beschikbaar', 'statusSource' en 'BackendStatus' levert geen
treffers meer op in productiecode; alleen de negatieve assertie in `widget_test.dart`
noemt de oude foutmelding nog.

## SF-2001 — review (reviewer)

Volledige story-diff (`git diff main...HEAD`) beoordeeld: alleen `frontend/`-code,
`docs/factory/` en de worklog; backend, `frontend-admin/` en de self-update-flow zijn
ongemoeid. Acceptatiecriteria 1 t/m 7 nagelopen en akkoord:

- Statuskaart, `FutureBuilder<BackendStatus>`, `_LoadingState`, `_ErrorState`, `_status`
  en `_retry()` zijn weg; `_HomeContent` rendert direct met nette spacing (één
  `SizedBox(height: 28)` boven 'Laatste nieuws').
- `backend_status.dart` verwijderd, `BackendClient.load()` geschrapt, `BackendClient`
  implementeert nog alleen `LatestNewsSource`; `dart:convert` blijft terecht in gebruik
  voor `loadLatestNews()`. Geen ongebruikte imports of achterblijvende referenties.
- Tests dekken introtekst + nieuws + navigatie, falende nieuwsbron (incl. `findsNothing`
  op de oude paginabrede foutmelding) en de lege nieuwslijst.
- `docs/factory/` bevat concrete informatie; de stackclaims (Kotlin, Spring Modulith,
  Flyway, `tools/`-scripts, `docs/architecture/reference-baseline.md`) zijn tegen de repo
  geverifieerd en de vijf commando's komen overeen met `.factory/verification.yaml`.

Gerichte hercontrole door de reviewer op deze HEAD: `flutter test` in `frontend/` → 5
tests passed; `flutter analyze` → No issues found. Werktree bleef schoon (geen
lockfile-churn).

## SF-2002 — Story-brede test (tester)

Vangnet uit `.factory/verification.yaml` volledig gedraaid op deze HEAD, alle exitcode 0:

| id | resultaat |
| --- | --- |
| `backend-maven-verify` | BUILD SUCCESS — Tests run: 20, Failures: 0, Errors: 0, Skipped: 0 |
| `frontend-flutter-analyze` | No issues found! |
| `frontend-flutter-test` | 5 tests, All tests passed! |
| `admin-flutter-analyze` | No issues found! |
| `admin-flutter-test` | 4 tests, All tests passed! |

Preview-omgeving `https://hkh-pr-15.vdzonsoftware.nl` (namespace `hkh-pr-15`) getest met
een headless Chromium; screenshots in `/work/screenshots/`.

- AC1/AC2 — `SF-2002-homepage.png`: homepage opent direct met introtekst, de knop "Lees
  onze productvisie" en de sectie "Laatste nieuws". Geen statuskaart "Service
  beschikbaar", geen `application version · commit`, geen paginabrede laadindicator.
- AC3 — `SF-2002-homepage-api-down.png`: met alle `**/api/**`-requests geblokkeerd blijven
  introtekst en de productvisieknop zichtbaar; alleen binnen het nieuwsblok verschijnt
  "Het laatste nieuws kon niet worden geladen." met "Opnieuw proberen". De oude
  paginabrede foutpagina "De HKH-service is niet bereikbaar" komt niet meer voor.
- AC4 — netwerkverkeer van de homepage bevat uitsluitend `GET /api/news`; geen
  `/actuator/health` en geen `/api/version`. Ook in het gedeployde webbundel
  (`main.1fe2862c00c4.js`) komen `Service beschikbaar`, `De HKH-service is niet
  bereikbaar`, `actuator/health` en `api/version` niet meer voor.
- Buiten scope ongewijzigd: `/actuator/health`, `/api/version` en `/api/news` op de
  preview geven alle drie HTTP 200.
- AC5/AC6/AC7 — analyzer schoon, testsuite groen, `docs/factory/` bevat geen TODO's meer
  en de vijf gedocumenteerde commando's slagen daadwerkelijk.

Geen bevindingen; geen flaky tests waargenomen.
