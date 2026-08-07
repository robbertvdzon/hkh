# SF-2000 - Koppeling met backend verwijderen uit homepage

## Story

Koppeling met backend verwijderen uit homepage

<!-- refined-by-factory -->

## Samenvatting

Op de homepage van de app staat nu een blokje met technische informatie over de
verbinding met de server ("Service beschikbaar", plus versienummers). Dat is
informatie voor ontwikkelaars en niet voor bezoekers, dus die haalt de app weg.

Daarnaast wacht de homepage nu eerst op een antwoord van de server voordat er
iets te zien is; lukt dat niet, dan krijgt de bezoeker alleen een foutmelding.
Na deze wijziging opent de homepage meteen met de introductietekst, de knop naar
de productvisie en het laatste nieuws. Gaat er iets mis bij het ophalen van het
nieuws, dan blijft dat netjes gemeld binnen het nieuwsblok zelf.

## Scope

In scope (frontend, `frontend/`):

- Verwijderen van de statuskaart met de titel `Service beschikbaar` en de
  subtitel `application version · commit` uit `frontend/lib/main.dart`.
- Verwijderen van de statusafhankelijkheid van de homepage: de `FutureBuilder`
  op `BackendStatus`, de bijbehorende `_LoadingState`, `_ErrorState`
  ("De HKH-service is niet bereikbaar" + Opnieuw proberen) en de `_retry`-logica
  op paginaniveau.
- Verwijderen van de `statusSource`-parameters uit `HkhApp` en `HomePage` en van
  het meegeven ervan in `main()`.
- Opruimen van de daarmee ongebruikt geworden code: `frontend/lib/backend/backend_status.dart`
  (`BackendStatus`, `BackendStatusSource`) en `BackendClient.load()` inclusief de
  aanroepen van `/actuator/health` en `/api/version` in `frontend/lib/backend/backend_client.dart`.
- Aanpassen van `frontend/test/widget_test.dart`: statusfixtures en de assertie
  op `hkh test · abc123` vervallen; de bestaande homepage- en nieuwstests blijven
  bestaan zonder statusbron.
- Aanvullen van `docs/factory/` met concrete repo-informatie.

Buiten scope:

- De nieuws-sectie ("Laatste nieuws") en haar eigen laad- en foutafhandeling.
- De backend: de endpoints `/actuator/health` en `/api/version` blijven
  ongewijzigd bestaan.
- De self-update-flow (`update_checker.dart`, `self_update_prompt.dart`), die
  tegen de GitHub-API praat en losstaat van de backendstatus.
- `frontend-admin/` en alle overige pagina's.

## Acceptance criteria

1. Op de homepage is geen kaart of tekst meer zichtbaar over de beschikbaarheid
   van de service; de teksten `Service beschikbaar` en de weergave
   `application version · commit` komen niet meer voor in de frontend-code.
2. De homepage toont direct de introductietekst, de knop "Lees onze productvisie"
   en de sectie "Laatste nieuws", zonder eerst te wachten op een statusaanroep;
   er is geen paginabrede laadindicator meer die op de backendstatus wacht.
3. Wanneer de backend onbereikbaar is, toont de homepage géén paginabrede
   foutpagina "De HKH-service is niet bereikbaar" meer; de introductietekst en de
   knop naar de productvisie blijven zichtbaar en alleen binnen de nieuws-sectie
   verschijnt de bestaande melding "Het laatste nieuws kon niet worden geladen."
   met de knop "Opnieuw proberen".
4. De frontend doet vanaf de homepage geen aanroepen meer naar `/actuator/health`
   en `/api/version`; `BackendStatus`, `BackendStatusSource` en
   `BackendClient.load()` bestaan niet meer en er blijft geen ongebruikte code of
   ongebruikte import achter.
5. `HkhApp` en `HomePage` hebben geen `statusSource`-parameter meer; de app
   compileert en de analyzer geeft geen nieuwe waarschuwingen.
6. De testsuite van `frontend/` is groen: `widget_test.dart` is aangepast aan de
   nieuwe constructor-signatuur en dekt minimaal (a) de homepage die introtekst
   en nieuws toont, en (b) de homepage die bij een falende nieuwsbron nog steeds
   introtekst plus de nieuwsfoutmelding toont. `backend_client_test.dart` blijft
   groen.
7. `docs/factory/` is aangevuld met concrete repo-informatie in plaats van de
   template-tekst: minimaal `development.md` met de echte build-, test- en
   lint-commando's (geen `TODO`'s meer), `technical-spec.md` met de gebruikte
   stack en `README.md` met een korte beschrijving van de repo-onderdelen
   (`backend/`, `frontend/`, `frontend-admin/`, `deploy/`, `tools/`). De in
   `development.md` genoemde commando's staan ook in `.factory/verification.yaml`
   en slagen daadwerkelijk.

## Aannames

- "Dat kan weg" betekent zowel de zichtbare statuskaart als de onderliggende
  statuskoppeling van de homepage; de kaart was de enige consument van die data,
  dus het laten staan van de call zou zinloze netwerkverkeer en een
  blokkerende foutpagina opleveren.
- Het laten vervallen van de paginabrede foutstate is gewenst: de homepage is
  daarmee ook zonder backend bruikbaar, en het nieuwsblok meldt zelf al wanneer
  data ontbreekt.
- Versie- en commit-informatie hoeft nergens anders in de frontend zichtbaar te
  worden gemaakt; er komt geen vervangende plek voor.
- De backend-endpoints blijven bestaan voor monitoring/deploy en worden niet
  verwijderd.

## Eindsamenvatting

# SF-2000 — Koppeling met backend verwijderen uit homepage

## Wat is gebouwd

De homepage van de HKH-frontend is losgekoppeld van de backendstatus.

- De statuskaart "Service beschikbaar" (met `application version · commit`) is van de homepage verdwenen.
- De homepage wacht niet meer op een statusaanroep: de introtekst, de knop "Lees onze productvisie" en de sectie "Laatste nieuws" worden direct gerenderd. De paginabrede laadindicator en de foutpagina "De HKH-service is niet bereikbaar" (incl. paginabrede *Opnieuw proberen*) bestaan niet meer.
- Dode code opgeruimd: `frontend/lib/backend/backend_status.dart` is verwijderd en `BackendClient.load()` (de calls naar `/actuator/health` en `/api/version`) is geschrapt. `BackendClient` levert nu alleen nog het laatste nieuws.
- De `statusSource`-parameter is weg uit `HkhApp`, `HomePage` en `main()`.
- `docs/factory/` is met concrete repo-informatie gevuld (echte build-/test-/lintcommando's, stack, moduleoverzicht) in plaats van template-tekst; `docs/factory/deployment.md` is bijgewerkt voor de preview-omgeving.

## Gemaakte keuzes

- Niet alleen de kaart, maar ook de onderliggende statuscall is verwijderd: de kaart was de enige consument, dus laten staan zou zinloos netwerkverkeer en een blokkerende foutpagina opleveren.
- Foutafhandeling ligt nu waar de data hoort: als het nieuws niet geladen kan worden, blijft de rest van de pagina bruikbaar en meldt alleen het nieuwsblok "Het laatste nieuws kon niet worden geladen." met een *Opnieuw proberen*-knop.
- `HomePage` blijft stateful vanwege de bestaande self-update-prompt; dat gedrag is ongewijzigd.
- `.factory/verification.yaml` bevatte alle vijf verificatiecommando's al en is niet aangepast.

## Wat is getest

Volledig vangnet groen op deze HEAD (alle exitcode 0):

| Check | Resultaat |
| --- | --- |
| `backend-maven-verify` | BUILD SUCCESS — 20 tests, 0 failures |
| `frontend-flutter-analyze` | No issues found |
| `frontend-flutter-test` | 5 tests passed |
| `admin-flutter-analyze` | No issues found |
| `admin-flutter-test` | 4 tests passed |

Daarnaast is de story functioneel getest op de preview-omgeving (`hkh-pr-15`) met een headless browser, met screenshots per acceptatiecriterium:

- Homepage opent direct, zonder statuskaart en zonder paginabrede laadindicator.
- Met geblokkeerde API-calls blijven introtekst en productvisieknop zichtbaar; alleen het nieuwsblok toont de foutmelding.
- Netwerkverkeer van de homepage bevat uitsluitend `GET /api/news`; in het gedeployde webbundel komen `Service beschikbaar`, `actuator/health` en `api/version` niet meer voor.

Alle 7 acceptatiecriteria zijn afgevinkt; reviewer en tester meldden geen bevindingen.

## Bewust niet gedaan

- De backend is ongemoeid: `/actuator/health` en `/api/version` blijven bestaan voor monitoring en deploy.
- De nieuws-sectie met haar eigen laad- en foutafhandeling is niet gewijzigd.
- De self-update-flow (tegen de GitHub-API) is niet aangeraakt.
- `frontend-admin/` en de overige pagina's zijn ongewijzigd.
- Er is geen vervangende plek gemaakt voor versie-/commit-informatie in de frontend.

<!-- deploy-summary:start -->
De startpagina van de site opent nu meteen met de welkomsttekst, de knop naar de productvisie en het laatste nieuws. Het technische blokje met serverinformatie is weg, want dat was niet bedoeld voor bezoekers. Is er even een storing, dan blijft de pagina gewoon bruikbaar en zie je alleen bij het nieuws een melding dat het niet geladen kon worden.
<!-- deploy-summary:end -->
