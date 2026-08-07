# HKH user frontend

De Flutter-app voor bezoekers (web en Android).

## Inhoud

- Homepage (`lib/main.dart`): introductietekst, de knop "Lees onze productvisie"
  en de sectie "Laatste nieuws". De pagina rendert direct en toont geen
  technische status- of versie-informatie.
- Productvisiepagina (`lib/product_vision_page.dart`).
- Self-update-check bij het openen van de app (`lib/update_checker.dart`,
  `lib/self_update_prompt.dart`), die tegen de GitHub-API praat.

## Backendkoppeling

`BackendClient` (`lib/backend/backend_client.dart`) implementeert
`LatestNewsSource` en roept uitsluitend `GET /api/news` aan. De homepage doet
geen aanroepen naar `/actuator/health` of `/api/version`; die endpoints bestaan
alleen voor monitoring en deploy. Faalt het ophalen van nieuws, dan blijft de
rest van de homepage zichtbaar en meldt alleen de nieuws-sectie de fout met een
knop *Opnieuw proberen*.

De basis-URL komt uit `AppConfig.apiBaseUrl`, in te stellen met
`--dart-define=API_BASE_URL=...` (standaard `http://localhost:8080`).

## Commands

```bash
flutter analyze
flutter test
flutter run -d chrome
```

Zie `docs/factory/development.md` voor het volledige vangnet en
`docs/factory/functional-spec.md` voor het functionele gedrag.
