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
- AI-archiefonderzoek met een overzicht van eerdere vragen, voortgang,
  antwoorden, bronnen en vervolgvragen (`lib/ai_search/`). Zodra een antwoord
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
- Self-update-check bij het openen van de app (`lib/update_checker.dart`,
  `lib/self_update_prompt.dart`), die op niet-webplatformen tegen de GitHub-API
  praat.

## Backendkoppeling

`BackendClient` (`lib/backend/backend_client.dart`) implementeert de
datasource-interfaces voor collectiezoeken, AI-archiefonderzoek, de PDF-export
van een AI-antwoord (`AiAnswerPdfSource`) en dossiers. De optionele
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

Zie `docs/factory/development.md` voor het volledige vangnet en
`docs/factory/functional-spec.md` voor het functionele gedrag.
