# Technical Spec

## Stack

| Onderdeel | Technologie |
| --- | --- |
| `backend/` | Kotlin op JDK 21, Spring Boot 4.x, Spring Modulith, Spring Web, Actuator, Validation, JDBC, Flyway, PostgreSQL, springdoc-openapi, openhtmltopdf (HTML naar PDF); gebouwd met Maven |
| `frontend/` | Flutter (Dart SDK ^3.9), Material 3, `http`-package, `share_plus` en `path_provider` (PDF delen/opslaan op Android); doelen web en Android |
| `frontend-admin/` | Flutter-webapp voor beheerders, zelfde stack als `frontend/` |
| `deploy/` | OpenShift/Kustomize/ArgoCD-manifesten, sealed secrets |
| CI/CD | GitHub Actions (`.github/`), images gepind op commit-sha |

## Architectuurafspraken

- De backend volgt de architectuurconventies van Personal News Feed; referentie en
  bewuste afwijkingen staan in `docs/architecture/reference-baseline.md`.
- Backendmodules zijn Spring Modulith-modules; cross-module toegang loopt via de
  publieke package-API van de module. Generieke techniek staat in een eigen
  module zonder afhankelijkheden op featuremodules: `nl.vdzon.hkh.docexport`
  (`HtmlToPdfRenderer.render(title, bodyHtml, sources)`) kent `aisearch` en
  `dossier` niet; `aisearch` noemt `docexport` in zijn `allowedDependencies`.
  De renderer saniteert of herschrijft de aangeleverde HTML niet en haalt geen
  externe bronnen (afbeeldingen, stylesheets, fonts) op; het Unicode-font staat
  in `backend/src/main/resources/fonts/`.
- De frontends praten alleen via HTTP-endpoints onder `/api/...` met de backend.
  `/actuator/health` en `/api/version` bestaan voor monitoring en deploy en worden
  niet vanuit de homepage aangeroepen.
- Datasources in de frontend zijn interfaces (zoals `CollectionSearchSource`,
  `AiSearchSource`, `AiAnswerPdfSource` en `DossierSource`) met `BackendClient`
  als productie-implementatie; widgets krijgen de interface geïnjecteerd zodat ze
  testbaar blijven.
- Platformspecifiek gedrag zit achter een kleine abstractie met conditionele
  import: `lib/ai_search/answer_pdf_saver.dart` kiest op `dart.library.html` de
  web-variant (Blob-download) en anders de io-variant (tijdelijk bestand plus
  deeldialoog). Widgettests injecteren daar een fake voor en draaien zo zonder
  browser-API's of Android-plugins.
- Laad- en foutafhandeling hoort bij de sectie die de data nodig heeft, niet op
  paginaniveau: een falende backend maakt de homepage niet onbruikbaar.
- De gedeelde vormgeving van de publieke app staat één keer in
  `frontend/lib/theme/app_style.dart` (kleuren, afrondingen, sectieritme,
  rolchipkleuren, `appSurfaceTheme`, `appDossierTheme`, `AppDialog`, `AppCard`).
  Schermen halen die waarden daar op in plaats van kleuren of afrondingen
  opnieuw te definiëren.

## Codeconventies

- Kotlin: officiële Kotlin-stijl, constructor-injectie, geen field injection.
- Dart: `flutter_lints` via `analysis_options.yaml`; `flutter analyze` moet schoon
  zijn. Gebruikersteksten in de UI zijn Nederlands, code en tests Engels.
- Database-wijzigingen uitsluitend via Flyway-migraties.

## Bekende valkuilen

- `flutter test`/`flutter analyze` draaien impliciet `flutter pub get`, wat
  `pubspec.lock` kan bijwerken; controleer of die wijziging bedoeld is.
- De backend leest `secrets.env` uit de repositoryroot; proces-environment
  heeft voorrang. Echte secrets nooit committen.
- `mvn clean verify` heeft een draaiende Postgres nodig voor integratietests
  (`docker compose -f docker-compose.dev.yml up -d`).

## Verificatie

De commando's uit `.factory/verification.yaml` staan uitgewerkt in
`development.md`: `backend-maven-verify`, `frontend-flutter-analyze`,
`frontend-flutter-test`, `admin-flutter-analyze` en `admin-flutter-test`.

Na een tester-AI-run voert de agentworker deze zelf uit en schrijft additive
revisiongebonden evidence in `AgentResultFile`; de factory valideert config,
commandset, exitcodes en HEAD/worktree-tree onafhankelijk en fail-closed. Timeout
stopt parent en child-processen; een output-readerfout is nooit groen. Duration
moet exact met start/eind overeenkomen en samenvatting/rapportlocatie zijn
begrensd.
