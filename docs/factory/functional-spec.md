# Functional Spec

De HKH-app ontsluit de geschiedenis van Heemskerk voor bezoekers. De
gebruikersapp (`frontend/`) is publiek; beheerders onderhouden de inhoud via de
aparte adminapp (`frontend-admin/`).

## Uitgangspunten

- De app toont bezoekersinhoud, geen technische of ontwikkelaarsinformatie
  (zoals servicestatus, versienummers of commit-hashes).
- Laden en foutafhandeling horen bij de sectie die de data nodig heeft, niet op
  paginaniveau. Een onbereikbare backend maakt een pagina nooit onbruikbaar.
- Alle gebruikersteksten in de UI zijn Nederlands.

## Homepage (`frontend/lib/main.dart`)

De homepage rendert direct, zonder eerst op een backendaanroep te wachten. Vaste
inhoud, van boven naar beneden:

1. Het HKH-icoon.
2. De introductietekst ("Ontdek de geschiedenis van Heemskerk vanuit een vraag,
   plek, persoon of gebeurtenis. …").
3. De knop **Lees onze productvisie**, die naar de productvisiepagina navigeert.
4. De kop **Laatste nieuws** met daaronder de nieuws-sectie.

Er is geen paginabrede laadindicator en geen paginabrede foutpagina. De homepage
roept zelf geen `/actuator/health` of `/api/version` aan; de enige backendaanroep
vanaf de homepage is `GET /api/news` vanuit de nieuws-sectie.

Bij het openen van de app wordt eenmalig de self-update-check uitgevoerd
(`update_checker.dart` / `self_update_prompt.dart`, tegen de GitHub-API). Die
staat los van de backend.

## Sectie "Laatste nieuws"

De sectie laadt zelf via een `LatestNewsSource` (productie-implementatie:
`BackendClient.loadLatestNews()`, `GET /api/news`) en heeft vier toestanden:

| Toestand | Weergave |
| --- | --- |
| Laden | Voortgangsindicator binnen de sectie |
| Fout | "Het laatste nieuws kon niet worden geladen." met de knop **Opnieuw proberen** |
| Leeg | "Er zijn nog geen nieuwsberichten." |
| Gevuld | Kaart per bericht met titel, publicatiedatum en bericht |

De introductietekst en de knop naar de productvisie blijven in alle vier de
gevallen zichtbaar.

## Terugkerende acceptatiecriteria

- Geen technische status- of versie-informatie in de bezoekers-UI.
- Een falende datasource degradeert alleen de eigen sectie en biedt daar een
  herstelactie (Opnieuw proberen) aan.
- Widgets krijgen hun datasource als interface geïnjecteerd, zodat elke toestand
  in een widgettest met een fake source afgedekt kan worden.

## Testerregels van de factory

Een testerresultaat bereikt alleen `tested` met compleet groen machinebewijs uit
`.factory/verification.yaml` voor exact dezelfde HEAD/worktree-tree. Missing bewijs/config, onbekende
versie, tool-missing, timeout, non-zero en revisionmismatch leveren altijd `test-rejected` op;
pre-existing, flaky en omgevingsfouten zijn nooit groen.
