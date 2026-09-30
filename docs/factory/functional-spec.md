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

De AI-vraagkaart bevat het gelabelde vrije-tekstveld **Uw vraag**, het blok
**Onderzoek** met een afgeronde stappenbalk **Snel** (standaard), **Doorzoeken** en
**Uitgebreid**, daaronder één zin met de consequentie van de keuze (rondes, soort
antwoord, verwachte duur) en drie balkjes voor de grondigheid, de gevulde primaire
actie **Vraag stellen · snel, ca. 2 min** (de tekst volgt de keuze) en de link
**Eerdere vragen**. Op smalle schermen staat het label boven de balk. Een ingevulde
vraag opent de bestaande AI-zoekpagina en start die vraag met de gekozen diepte; een
lege start en de link Eerdere vragen openen het bestaande overzicht. De AI-knop is de
enige gevulde primaire actie in de homepage-inhoud.

De collectiekaart toont direct de collectie-ingangen Archief, Beeldbank, Bibliotheek,
Bidprentjes, Artikelen en Objecten, het gelabelde veld **Zoekterm**, de omrande actie
**Zoeken** en de onafhankelijke uitklappers **Zoektips** en **Uitgebreid zoeken**.
De uitklappers beginnen gesloten. De algemene zoekterm kan woorden of een frase tussen
aanhalingstekens bevatten. De homepage biedt bovendien de veldfilters Titel, Beschrijving
en Jaar met zichtbare, programmatisch gekoppelde labels.

Een zoekopdracht opent direct de volledige zoekpagina. Een leeg zoekveld toont de collectie.
De zoekpagina biedt:

- Eén veld **Zoek overal** doorzoekt alle gegevens en beschikbare documenttekst binnen de
  gekozen collectie. **Alles** doorzoekt alle collecties. Een nieuwe zoekopdracht behoudt
  de gekozen collectie; de collectieknoppen tonen de aantallen per collectie.
- Doorzoekbare filters per collectie. Keuzelijsten komen uit de database en houden rekening
  met de overige filters; meerdere waarden binnen één filter gelden als OF.
- Inklapbaar **Gericht zoeken** met optionele, blijvend gelabelde velden Titel, Beschrijving
  en Jaar. Alle ingevulde velden gelden samen met de algemene zoekterm. **Zoekveld toevoegen**
  voegt een verwijderbaar invoerveld toe uit de gekozen collectie, zoals Straatnaam bij Beeldbank.
- Jaar en periode delen één plek: **Periode invullen** vervangt het exacte jaar door een bereik;
  **Eén jaar invullen** verwijdert de periode. Er is geen losse periodeknop naast het formulier.
- Geen keuzelijsten voor zoekwoordcombinaties of zoeken in een veld, en geen OCR-checkbox.
  Gewoon zoeken ondersteunt aanhalingstekens; alleen bij nul resultaten wordt zoeken op delen
  van woorden aangeboden, met een voorbeeld. Oude URL-instellingen blijven herkenbaar en wisbaar.
- Treffers in documenttekst tonen **Gevonden in documenttekst** met een kort fragment. De volledige
  documenttekst staat niet in de zoekresultaten-API, wel in de detail-API (`documentText`).
- Documenttekst is de tekstlaag uit de PDF van een record (archief, artikelen). De backend haalt
  die bij **Volledig ophalen** direct na elk nieuw record uit de PDF; **Documenttekst ophalen** in
  het beheerscherm doet dat eenmalig voor de bestaande collectie (alleen ontbrekende, met
  "alles opnieuw" ook eerder mislukte). Een rescrape van de metadata raakt de tekst niet.
  De detailpagina toont de tekst onder het tabblad **Documenttekst**, met de melding dat
  herkende tekst fouten kan bevatten.
- Inclusieve periodegrenzen; bij bidprentjes betekent dit geboortejaar.
- Sortering op standaardvolgorde, nummer, titel/naam, jaar, auteur of eerste toevoegdatum.
- Lijst- en galerijweergave met de eigen metadata van iedere collectie.
- Verwijderbare filterchips, lege resultaten met herstelactie en een herhaalactie bij fouten.
- URL-behoud van alle zoekinstellingen en paginanummer, ook via details en na verversen.
- Collectie-eigen detailvelden, alle bronvelden, beschikbaar beeld/PDF en vorige/volgende resultaten.

De laatste zoekactie wint bij overlappende netwerkverzoeken; een oudere respons mag de nieuwe
resultaten niet overschrijven. Op kleine schermen zijn minder gebruikte filters bereikbaar
via **Alle filters**. Filterkeuzes worden tijdens het wisselen per collectie onthouden.

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

De dossierschermen en -dialogen (Mijn dossiers, Nieuw dossier, het dossierdetail
met Vragen, Feitenlijst en Artikelen, In dossier zetten en Delen en leden)
gebruiken dezelfde vormgeving als de homepage: achtergrond `#FBF6EE`,
donkergroen `#1F3B2E` voor titels, primaire knoppen en links, dunne randen
`#D9CFBB` op neutrale kaarten, 16 px afronding op kaarten, 10 px op velden en
knoppen en minimaal 32 px tussen inhoudelijke secties. Rolchips hebben een vaste
kleur per rol: Eigenaar `#DCE9DA`, Bewerker `#F0E6D2`, Onderzoeker `#D9ECE7` en
Lezer `#ECE8DD`. Tot en met 600 px vullen dialogen de beschikbare breedte binnen
de normale schermmarges en stapelen kaartinhoud, dialoogvelden en ledenacties
verticaal; ook bij 320 px breedte en 200% tekstschaling ontstaat geen
horizontale overflow en worden lange e-mailadressen met ellipsis afgekapt. Deze
vormgeving raakt alleen de presentatie: teksten, validatie, de `canResearch`-
filter van In dossier zetten en de `canManage`-autorisatie van Delen en leden
blijven ongewijzigd.

## AI-onderzoek: diepte en bronnen

Bij elke vraag en vervolgvraag kiest de gebruiker de onderzoeksdiepte. Een zoekronde is:
zoektermen bepalen, alle resultaatpagina's ophalen, samenvattingen beoordelen en de details
van relevante treffers lezen; ronde 1 komt uit de vraag, elke volgende ronde uit
aanknopingspunten (personen, adressen, gebouwen, bedrijven) van de vorige ronde.

| Keuze | Rondes | Antwoord |
| --- | --- | --- |
| Snel (standaard) | 1 | compact maar volledig |
| Doorzoeken | max 5 | verbanden één niveau diep |
| Uitgebreid | max 15 | lang verhaal met alles eromheen |

Het maximum is een plafond: de onderzoeker stopt eerder zodra een ronde niets nieuws oplevert,
en niet-gevolgde sporen komen terug als voorgestelde vervolgvragen. De vraagkaart toont de
keuze als stappenbalk met uitleg; de vervolgvraagbalk als pil **Snel · ca. 2 min** naast de
verzendknop die een menu met de drie opties en hun consequentie opent, zodat de balk één
regel hoog blijft (op smalle schermen zonder duur). Het antwoord vermeldt de gebruikte diepte naast de doorlooptijd, en de
voortgangsmelding toont **Spoor wordt gevolgd: …** zodra de onderzoeker een aanknopingspunt
oppakt. De API neemt `depth` (`FAST`, `EXTENDED`, `THOROUGH`) mee in het vraagverzoek;
ontbrekend of onbekend betekent `FAST`.

Tijdens een onderzoek met meer dan één ronde toont de voortgangskaart een **Onderzoekslogboek**:
per afgeronde ronde het aantal bronnen, twee zinnen over wat er tot dan toe gevonden is en de
sporen die de onderzoeker hierna wil volgen. Daaronder staat **Bijsturen**: een veld
**Aanwijzing voor de volgende ronde** met verzendknop en de knop **Genoeg gevonden, schrijf het
antwoord**. Een bijsturing wordt pas op de eerstvolgende rondegrens opgepakt; de kaart toont
**Wordt na deze ronde opgepakt: …** en daarna **Opgepakt: …**. Na "genoeg gevonden" is de
knop inactief en schrijft de onderzoeker het antwoord met wat hij heeft (anders dan **Stoppen**,
dat het onderzoek afbreekt zonder antwoord). Een snel onderzoek (één ronde) is niet bij te
sturen. Technisch meldt de agent na iedere ronde zijn stand met een POST op een per-vraag
geheime URL (`/api/ai-search/research/{turnId}/{token}/rounds`) en krijgt in het antwoord
`stop` en `hint` terug; de eigenaar stuurt bij via `…/turns/{turnId}/steer`, in een dossier via
`…/questions/{sessionId}/turns/{turnId}/steer` (rol met onderzoeksrecht).

De bronnenlijst met beschrijvingen en beelden staat niet meer onder de antwoordtekst, maar
achter de knop **Alle bronnen (N)**, die een aparte pagina **Bronnen en afbeeldingen** opent.
Dit geldt ook voor gedeelde antwoorden. Antwoorden van vóór deze scheiding houden de lijst
in de tekst en tonen geen knop. De PDF-export bevat de bronnenlijst nog steeds na de tekst.

## PDF-export van een AI-antwoord

Zodra op het AI-antwoordscherm een antwoord geladen en zichtbaar is, toont de
appbalk rechts naast het geschiedenis-icoon een pdf-actie met de tooltip
**Exporteer als PDF**. Zolang er geen antwoord is (leeg scherm, lopende
zoekopdracht, foutstaat zonder antwoord) wordt de actie niet getoond, zodat er
nooit een export voor een leeg antwoord wordt aangevraagd. Tijdens een lopende
export is de actie inactief en staat er een kleine voortgangsindicatie op de
knoppositie; een tweede tik start dus geen tweede verzoek.

Een geslaagde export levert een PDF met de titel van de vraag of het antwoord,
de antwoordtekst zoals die op het scherm staat en de bijbehorende bronnenlijst
als tekst (collectie, ident en verwijzing). De PDF bevat exact dezelfde
gesaniteerde inhoud als het scherm, dus geen scripts; beeldbank-thumbnails
worden niet ingesloten. Op web start meteen een download van
`antwoord-<id>.pdf`, op Android opent een deel-/opslagdialoog voor dat bestand
(zonder extra Android-permissies). Er blijft geen PDF op de server achter.

Mislukt de export (netwerkfout, foutstatus, onvolledig antwoord of een
overschreden timeout), dan verschijnt de snackbar **PDF-export mislukt. Probeer
het opnieuw.** met de actie **Opnieuw**, die dezelfde export opnieuw probeert.
Het getoonde antwoord blijft ongewijzigd zichtbaar, er vindt geen navigatie
plaats en er wordt geen leeg of onvolledig bestand aangeboden. De export vraagt
geen verplichte login: hij gebruikt hetzelfde account of dezelfde anonieme
bezoekerscookie als de rest van het AI-zoeken. De export hoort bij het publieke AI-antwoordscherm; het tabblad
*Vragen* in een dossier toont deze actie niet en blijft ongewijzigd.

## PDF-export van een dossierartikel

Het artikelscherm in een dossier heeft rechtsboven het bestaande artikelmenu.
Zodra een artikelversie geladen is, staat daarin tussen **Geschiedenis** en
**Artikel verwijderen** het item **Exporteren als PDF** (ux-05 desktop, ux-06
mobiel). Iedereen met toegang tot het dossier ziet het item, ook een lezer;
**Artikel verwijderen** blijft voorbehouden aan wie mag bewerken, dus voor een
lezer sluit het exportitem het menu af. Zolang er nog geen artikelversie geladen
is, toont het scherm het artikelmenu niet, zodat er nooit een export zonder
inhoud aangevraagd kan worden. Ook tijdens het bewerken van een artikel is het
menu er niet. Een tweede keuze tijdens een lopende export start geen tweede
verzoek. De rest van het scherm — lay-out, navigatie en de overige menu-items —
blijft ongewijzigd.

Een geslaagde export levert de huidige (laatst getoonde) artikelversie als PDF:
de titel van het artikel, de inhoud zoals die op het scherm staat en het
bronnenblok **Bronnen** als tekst (titel, collectie/ident en de verwijzing naar
de bron). De PDF bevat exact dezelfde gesaniteerde inhoud als het scherm, dus
geen scripts; bronminiaturen worden niet ingesloten. Op web start meteen een
download van `artikel-<articleId>.pdf`, op Android opent dezelfde
deel-/opslagdialoog als bij de AI-antwoord-export, zonder extra
Android-permissies. De PDF wordt per verzoek gemaakt en blijft nergens op de
server achter. Historische versies en een dossier als geheel zijn niet te
exporteren.

De export vraagt dezelfde toegang als de rest van het artikelscherm: wie het
dossier niet mag zien, krijgt dezelfde foutmelding als op de bestaande
artikelroutes. Mislukt de export (netwerkfout, foutstatus, leeg of onvolledig
antwoord, mislukte download- of deelactie), dan verschijnt de snackbar
**PDF-export mislukt. Probeer het opnieuw.** met de actie **Opnieuw**, die
dezelfde poging herhaalt (ux-07 desktop, ux-08 mobiel). Het artikel blijft
inclusief bronnenblok zichtbaar, er vindt geen navigatie plaats en er wordt geen
leeg of onvolledig bestand aangeboden.

## Testerregels van de factory

Een testerresultaat bereikt alleen `tested` met compleet groen machinebewijs uit
`.factory/verification.yaml` voor exact dezelfde HEAD/worktree-tree. Missing
bewijs/config, onbekende versie, tool-missing, timeout, non-zero en
revisionmismatch leveren altijd `test-rejected` op; pre-existing, flaky en
omgevingsfouten zijn nooit groen.
