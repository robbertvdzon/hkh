# Functional Spec

De HKH-app ontsluit de geschiedenis van Heemskerk voor bezoekers. De
gebruikersapp (`frontend/`) is publiek; beheerders onderhouden de inhoud via de
aparte adminapp (`frontend-admin/`).

## Uitgangspunten

- De app toont bezoekersinhoud, geen technische of ontwikkelaarsinformatie.
- Laden en foutafhandeling horen bij de sectie die de data nodig heeft, niet op
  paginaniveau. Een onbereikbare backend maakt de rest van een pagina niet
  onbruikbaar.
- Alle gebruikersteksten in de UI zijn Nederlands.
- De publieke app blijft bruikbaar zonder account. Een account voegt dossiers
  toe, maar verandert de publieke zoekroutes niet.

## Homepage (`frontend/lib/main.dart`)

De homepage heeft een rustige, warme achtergrond (`#FBF6EE`) en rendert de
primaire inhoud in deze toetsenbord- en visuele volgorde:

1. De hero zonder archiefpictogram, met de titel **Ontdek historisch Heemskerk**
   en de introductie **Stel een vraag over plekken, personen of gebeurtenissen
   uit de geschiedenis van Heemskerk.**
2. De lichtgroene (`#DCE9DA`) AI-vraagkaart met de titel **Wat wilt u weten?**
   en de toelichting **Bijv. wat is er bekend over de Kerklaan? De digitale
   onderzoeker zoekt bronnen bij elkaar. Dit kan enkele minuten duren.**
3. De neutrale, omrande sectie **Zelf zoeken in de collectie**.

De AI-vraagkaart bevat het gelabelde vrije-tekstveld **Uw vraag**, de gevulde
primaire actie **Vraag stellen** en de link **Eerdere vragen**. Een ingevulde
vraag opent de bestaande AI-zoekpagina en start die vraag; een lege start en de
link Eerdere vragen openen het bestaande overzicht. De AI-knop is de enige
gevulde primaire actie in de homepage-inhoud.

De collectiekaart bevat het gelabelde veld **Zoekterm**, de ondergeschikte,
omrande actie **Zoeken**, de onafhankelijke uitklappers **Zoektips** en
**Uitgebreid zoeken**, en de link **Doorzoek de collectie**. Beide uitklappers
beginnen bij iedere eerste weergave ingeklapt. Zoektips toont bij uitklappen
letterlijk de bestaande zoeksyntax:

> Los woorden voor een EN-zoekopdracht, of zet een zin tussen "aanhalingstekens" voor een exacte frase.

Uitgebreid zoeken toont de velden Titel, Beschrijving en Jaar. Het openen of
sluiten van een uitklapper verandert de toestand van de andere niet.

Een collectiezoekopdracht toont maximaal drie treffers op de homepage en linkt
met **Alle _n_ resultaten** door naar de bestaande volledige resultatenpagina.
Zonder treffers staat er **Geen resultaten gevonden.** Bij een fout staat er
**Zoeken in de collectie is niet gelukt. Controleer de verbinding en probeer
het opnieuw.** De ingevoerde algemene en uitgebreide zoekwaarden blijven bij
deze fout staan.

## Responsief gedrag en toegankelijkheid

- Tot en met 600 px staan het AI-vraagveld en zijn knop en het
  collectiezoekveld en de knop onder elkaar; de knoppen vullen de beschikbare
  breedte. Boven 600 px staan veld en bijbehorende knop naast elkaar.
- De indeling veroorzaakt ook bij 320 px breedte en 200% tekstschaling geen
  horizontale overflow. Tekst mag afbreken en de pagina blijft verticaal
  scrollbaar.
- In de brede weergave is tussen hero, AI-kaart en collectiekaart minimaal
  32 px verticale ruimte.
- Beide hoofdkaarten hebben een afronding van 16 px; velden, knoppen,
  focusranden en de collectie-foutmelding gebruiken 10 px.
- Donkergroen `#1F3B2E` is de tekst-, link-, focus- en primaire actiekleur op
  de warme, lichtgroene en witte achtergronden. Velden hebben zichtbare labels,
  disclosures melden hun uitgevouwen toestand, foutmeldingen worden als live
  status aangeboden en alle acties houden Material-aanraakdoelen en zichtbare
  toetsenbordfocus.
- De contrastverhoudingen zijn 11,33:1 voor donkergroen op `#FBF6EE`, 9,70:1
  op `#DCE9DA`, 12,19:1 voor wit op donkergroen, 4,91:1 voor de veldrand
  `#647566` op wit en 6,64:1 voor de fouttekst `#9F201B` op `#FBE9E7`. Daarmee
  voldoen tekst en betekenisvolle bediening-/focusranden aan WCAG 2.2 AA.

## Appbalk en dossiers

Niet-ingelogde gebruikers behouden de bestaande inlogactie. Voor ingelogde
gebruikers staat **Mijn dossiers** als eigen appbalkactie, visueel gescheiden van
het accountmenu. Boven 600 px bestaat deze uit een mapicoon en het zichtbare
label **Mijn dossiers**. Tot en met 600 px staat alleen het mapicoon, met de
toegankelijke naam en tooltip **Mijn dossiers**. De actie opent rechtstreeks de
bestaande `DossierListPage`; er is geen nieuwe route.

Het accountmenu van een ingelogde gebruiker bevat uitsluitend **Uitloggen**.
Op smalle schermen gebruikt ook de accountbediening een compacte icoonweergave,
zodat de appbalk niet horizontaal overloopt.

## Testerregels van de factory

Een testerresultaat bereikt alleen `tested` met compleet groen machinebewijs uit
`.factory/verification.yaml` voor exact dezelfde HEAD/worktree-tree. Missing
bewijs/config, onbekende versie, tool-missing, timeout, non-zero en
revisionmismatch leveren altijd `test-rejected` op; pre-existing, flaky en
omgevingsfouten zijn nooit groen.
