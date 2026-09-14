# HKH user frontend

De Flutter-app voor bezoekers (web en Android).

## Inhoud

- Homepage (`lib/main.dart`) met een primaire AI-vraagroute, een ondergeschikte
  collectiezoeker en een responsieve appbalk. De pagina rendert direct en toont
  geen technische status- of versie-informatie.
- AI-archiefonderzoek met een overzicht van eerdere vragen, voortgang,
  antwoorden, bronnen en vervolgvragen (`lib/ai_search/`).
- Gewoon en uitgebreid collectiezoeken, resultaten en itemdetails
  (`lib/collection/`).
- Optionele Google-login en onderzoeksdossiers met vragen, feitenlijsten,
  artikelen, versiegeschiedenis en delen (`lib/auth/` en `lib/dossier/`). Voor
  ingelogde gebruikers opent de losse appbalkactie **Mijn dossiers** deze
  functionaliteit; het accountmenu bevat alleen **Uitloggen**.
- Self-update-check bij het openen van de app (`lib/update_checker.dart`,
  `lib/self_update_prompt.dart`), die op niet-webplatformen tegen de GitHub-API
  praat.

## Backendkoppeling

`BackendClient` (`lib/backend/backend_client.dart`) implementeert de
datasource-interfaces voor collectiezoeken, AI-archiefonderzoek en dossiers. De
optionele gebruikerssessie staat in `lib/auth/user_session.dart`. Deze clients
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

Zie `docs/factory/development.md` voor het volledige vangnet en
`docs/factory/functional-spec.md` voor het functionele gedrag.
