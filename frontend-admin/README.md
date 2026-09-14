# HKH admin frontend

De afzonderlijke Flutter-webapp voor beheerders.

## Inhoud

- Google-login met controle op de backendrol `ADMIN` en herstel van de bewaarde
  HKH-sessie.
- Een previewmodus die de afgeschermde preview-identiteit van de backend
  gebruikt.
- Starten en volgen van een snelle of volledige import van de ZCBS-collectie.
- Publiceren van nieuwsberichten via de beheer-API.

De basis-URL komt uit `API_BASE_URL` (standaard `http://localhost:8080`). Stel
`GOOGLE_CLIENT_ID` in voor de normale Google-login. `PREVIEW_MODE=true` is
uitsluitend bedoeld voor een door de backend beveiligde PR-preview.

## Commands

```bash
flutter analyze
flutter test
flutter run -d chrome
```

Zie `../docs/factory/development.md` voor het volledige vangnet en
`../docs/deployment.md` voor configuratie en deployment.
