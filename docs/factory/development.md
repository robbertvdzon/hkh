# Development

De repository bestaat uit drie bouwbare modules: een Kotlin/Spring Boot-backend
(`backend/`) en twee Flutter-apps (`frontend/` en `frontend-admin/`). Elke module
wordt vanuit zijn eigen map gebouwd en getest.

Vereisten: JDK 21, Maven 3.9+, Flutter met Dart SDK 3.9+, Docker (voor de lokale
Postgres uit `docker-compose.dev.yml`).

## Commands

Backend (`backend/`):

- Build + unit- en integratietests: `mvn -B --no-transfer-progress clean verify`
- Lokaal draaien: `mvn spring-boot:run` (leest `secrets.env` uit de repositoryroot)

Frontend (`frontend/`):

- Lint/analyse: `flutter analyze`
- Unit-/widgettests: `flutter test`
- Lokaal draaien: `flutter run -d chrome`

Frontend-admin (`frontend-admin/`):

- Lint/analyse: `flutter analyze`
- Unit-/widgettests: `flutter test`

Er zijn geen aparte integratietest-commando's voor de Flutter-apps; de
backend-integratietests draaien mee in `mvn clean verify`.

## Vangnet

Het volledige verplichte vangnet staat in `.factory/verification.yaml` (schema 1)
en bestaat uit deze commando's:

| id | workingDirectory | argv |
| --- | --- | --- |
| `backend-maven-verify` | `backend` | `mvn -B --no-transfer-progress clean verify` |
| `frontend-flutter-analyze` | `frontend` | `flutter analyze` |
| `frontend-flutter-test` | `frontend` | `flutter test` |
| `admin-flutter-analyze` | `frontend-admin` | `flutter analyze` |
| `admin-flutter-test` | `frontend-admin` | `flutter test` |

Per command geldt: stabiele `id`, `argv`-lijst zonder impliciete shell, relatief
bestaand `workingDirectory` en `timeoutSeconds` (1..7200). Ontbrekende of
onbekende config blokkeert testergoedkeuring. Een working-directorysymlink mag
niet buiten de repository uitkomen.

## Conventions

- Repo-structuur: zie `README.md` in deze map voor de rol van elke top-levelmap.
- Backend: Kotlin met Spring Modulith; per module een eigen package onder
  `backend/src/main/kotlin`. Database-migraties via Flyway.
- Frontend: Dart-bestanden in `snake_case`, widgets in `UpperCamelCase`.
  Netwerktoegang loopt via `lib/backend/backend_client.dart`; widgets krijgen een
  datasource-interface (bv. `LatestNewsSource`) geïnjecteerd zodat ze in tests
  met een fake te vullen zijn.
- Teststrategie: backend met JUnit/Spring-tests, frontends met `flutter_test`
  (widgettests met fake sources, clienttests met `MockClient` uit `http/testing`).
- Lintregels voor de Flutter-apps staan in `analysis_options.yaml`
  (`flutter_lints`); `flutter analyze` moet zonder issues doorlopen.
