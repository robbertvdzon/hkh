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
  het beheerscherm doet dat eenmalig voor de bestaande collectie (ontbrekende en eerder
  mislukte; met "alles opnieuw" worden ook al opgehaalde PDF's op wijzigingen gecontroleerd via
  hun hash). Oudere records verwijzen naar de pdf.js-viewerpagina in plaats van de PDF; de
  extractie haalt dan het bestand uit de `file`-parameter, net als de media-proxy. Een
  rescrape van de metadata raakt de tekst niet.
  De detailpagina toont de tekst onder het tabblad **Documenttekst**, met de melding dat
  herkende tekst fouten kan bevatten.
- Inclusieve periodegrenzen; bij bidprentjes betekent dit geboortejaar.
- Sortering op standaardvolgorde, nummer, titel/naam, jaar, auteur of eerste toevoegdatum.
- Lijst- en galerijweergave met de eigen metadata van iedere collectie.
- Verwijderbare filterchips, lege resultaten met herstelactie en een herhaalactie bij fouten.
- URL-behoud van alle zoekinstellingen en paginanummer, ook via details en na verversen.
- Collectie-eigen detailvelden, alle bronvelden, beschikbaar beeld/PDF en vorige/volgende resultaten.
- PDF's op de volledige objectpagina tonen de eerste pagina als afbeelding. Klikken op
  het voorbeeld of **PDF openen** opent de volledige PDF in een nieuw tabblad. Ook bij
  een ontbrekend of mislukt voorbeeld blijft de PDF te openen.

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

Bij elke nieuwe vraag met de agent-methode kiest de gebruiker de onderzoeksdiepte (bij de
pijplijn verbergt de site de keuze, zie verderop). Een zoekronde is:
zoektermen bepalen, alle resultaatpagina's ophalen, samenvattingen beoordelen en de details
van relevante treffers lezen; ronde 1 komt uit de vraag, elke volgende ronde uit
aanknopingspunten (personen, adressen, gebouwen, bedrijven) van de vorige ronde.

| Keuze | Rondes | Antwoord |
| --- | --- | --- |
| Snel (standaard) | 1 | compact maar volledig |
| Doorzoeken | max 5 | verbanden één niveau diep |
| Uitgebreid | max 15 | lang verhaal met alles eromheen, waar de vraag daarom vraagt ook straat, buren, gebouwen en collega's |

Het maximum is een plafond, geen doel: de vraag bepaalt hoe ver de onderzoeker gaat. Een
afgebakende vraag is na één ronde klaar; een vraag naar verbanden, familie of "alles" gaat door tot
de sporen op zijn. Sporen die de onderzoeker in een rondemelding opgeeft zijn bindend: hij stopt
niet zolang die lijst gevuld is. De vraagkaart toont de keuze als stappenbalk met uitleg;
het invoerveld voor een nieuwe dossierzoekopdracht gebruikt een compact keuzemenu.
Een bestaande zoekopdracht toont geen vervolgvraagveld of voorgestelde vervolgvragen.
Een nieuwe vraag begint vanuit het overzicht een aparte zoekopdracht; eerder opgeslagen
antwoorden blijven leesbaar. Het antwoord vermeldt de gebruikte diepte naast de doorlooptijd, en de
voortgangsmelding toont **Spoor wordt gevolgd: …** zodra de onderzoeker een aanknopingspunt
oppakt. De API neemt `depth` (`FAST`, `EXTENDED`, `THOROUGH`) mee in het vraagverzoek;
ontbrekend of onbekend betekent `FAST`.

Tijdens een onderzoek met meer dan één ronde toont de voortgangskaart een **Onderzoekslogboek**:
per afgeronde ronde het aantal bronnen, twee zinnen over wat er tot dan toe gevonden is en de
sporen die de onderzoeker hierna wil volgen. Daaronder staat de knop **Genoeg gevonden,
schrijf het antwoord**. Die wordt pas op de eerstvolgende rondegrens opgepakt; de kaart toont
**Wordt na deze ronde opgepakt: …** en daarna **Opgepakt: …**, en de knop is dan inactief. De
onderzoeker schrijft het antwoord met wat hij heeft (anders dan **Stoppen**, dat het onderzoek
afbreekt zonder antwoord). Een snel onderzoek (één ronde) is niet bij te sturen. Technisch
meldt de agent na iedere ronde zijn stand met een POST op een per-vraag geheime URL
(`/api/ai-search/research/{turnId}/{token}/rounds`) en krijgt in het antwoord `stop` (en een
optionele `hint`, die de app nu niet aanbiedt) terug; de eigenaar stuurt bij via
`…/turns/{turnId}/steer`, in een dossier via `…/questions/{sessionId}/turns/{turnId}/steer`
(rol met onderzoeksrecht).

De bronnenlijst met beschrijvingen en beelden staat niet meer onder de antwoordtekst, maar
achter de knop **Alle bronnen (N)**, die een aparte pagina **Bronnen en afbeeldingen** opent.
Dit geldt ook voor gedeelde antwoorden. Antwoorden van vóór deze scheiding houden de lijst
in de tekst en tonen geen knop. De PDF-export bevat de bronnenlijst nog steeds na de tekst.

Foto's in antwoorden, gedeelde antwoorden en de bronnenpagina openen bij aanklikken in
een schermvullende fotoweergave. Daar kan de gebruiker zoomen met twee vingers,
dubbelklikken, het muiswiel of de zoomknoppen en de foto verslepen. **Hele foto** herstelt
de volledige afbeelding. Escape of het sluitkruisje sluit de weergave en behoudt de
leespositie in het antwoord. Een bronlink om een foto opent bij deze klik de foto;
tekstlinks naar bronnen openen een popup met de collectiegegevens, afbeelding,
beschikbare scan en documenttekst. Bij een PDF toont de popup een afbeelding van
de eerste pagina, zonder ingesloten PDF-viewer. Aanklikken van het voorbeeld of
**PDF openen** opent de volledige PDF in een nieuw tabblad en laat de bronpopup
staan. Als geen voorbeeld beschikbaar is, blijft **PDF openen** bruikbaar.
**Open volledige pagina** opent de bron in een
nieuw tabblad. De bronpopup sluit via Escape, het kruisje of **Sluiten** zonder
de leespositie van het antwoord te veranderen. Externe bronnen krijgen waar
mogelijk een ingesloten voorbeeld met dezelfde knop naar de volledige pagina.

## AI-onderzoek: methode agent of pijplijn

Een vraag wordt op één van twee manieren onderzocht; de beheerder kiest de methode voor nieuwe
vragen (instelling `ai-search.method`), en een vraag legt bij het stellen vast welke methode geldt
(`ai_search_turn.research_method`).

- **Agent**: de agent in de agent-runtime zoekt zelf via de REST-API en meldt rondes via de
  meld-URL (zie hierboven). Alleen bij de agent kiest de gebruiker een onderzoeksdiepte.
- **Pijplijn**: altijd twee modelaanroepen via de runtime (abonnementsmodus,
  `STRUCTURED_GENERATION`); de diepte speelt geen rol en de site verbergt de keuze
  (`GET /api/ai-search/options` geeft `depthSelectable`). De stappen:
  1. **Zoektermen uit de vraag, zonder model** (`QuestionTerms`): aangehaalde tekst, namen en
     straten (hoofdletterreeksen met tussenvoegsels, plus de achternaam apart), jaartallen,
     perioden ("1950-1960", "jaren vijftig") en de overige betekenisvolle woorden zonder
     stopwoorden; hoogstens acht termen. "Oudste/eerste" en "nieuwste/laatste" zetten de
     sortering op jaar. Alleen zonder termen of zonder treffers (bijvoorbeeld een vervolgvraag
     als "en hij?") bepaalt het model de termen in een planjob.
  2. **SQL 1, breed**: trigram-tolerant op de trefwoorden van de AI-kaarten (Oostrum vindt ook
     Oostrom en Van Oostrum), losse jaartallen als periode van ±2 jaar, de volledige tekst als
     vangnet. Rangschikking op aantal gematchte termen en score, met een bonus voor een
     titeltreffer en voor records met documenttekst, zodat artikelen niet onder foto's zakken;
     bij een jaarsignaal gesorteerd op jaar. Plafond 300 kaarten. Bij een treffer in de
     documenttekst gaat het fragment rond de treffer mee (`ts_headline`, twee fragmenten van
     hoogstens 30 woorden, treffer tussen « en »). De bronnen van het vorige antwoord in het
     gesprek doen als kaart mee.
  3. **Richten** (rol RESEARCH, één job): het model ziet de vraag, de context, per term de
     treffertelling en alle kaarten (samenvatting, trefwoorden, jaar, foto, documenttekst
     ja/nee, fragmenten) en geeft terug: een tussenconclusie (twee zinnen, zichtbaar als
     voortgang) en de definitieve zoekopdracht: termen, periode, collecties, beeldfilter,
     `sortByYear` en `includeRecords` (records die hoe dan ook mee moeten, hoogstens 60, alleen
     uit de getoonde kaarten). Geen keuzelijst per record en geen volgende ronde.
  4. **SQL 2 en het tekstbudget**: de code voert de zoekopdracht uit (vaste records vooraan, dan
     de treffers in rangorde of op jaar; zonder bruikbare zoekopdracht de kaarten van SQL 1 in
     rangorde) en haalt de volledige records op. Korte records (hoogstens 1.500 tekens
     documenttekst: foto's, bidprentjes, objecten, korte stukken) gaan altijd volledig mee. Lange
     documenten gaan in rangorde volledig mee (hoogstens 60.000 tekens per document) zolang het
     tekstbudget dat toelaat; de rest gaat als kaart met fragment mee onder "Alleen de kaart
     gelezen". Het budget is per schrijfmodel instelbaar in beheer (`ai-search.write-budget`;
     standaard 450.000 tekens, 250.000 voor kleine modellen zoals Haiku).
  5. **Schrijven** (rol WRITER, één job): het antwoord uitsluitend uit de genummerde bronnen,
     met foto's tussen de tekst, bronnummers die de code terugvertaalt naar collection/ident
     (renderer, bronnenpagina en PDF ongewijzigd), een lijst "Ook gevonden, niet gebruikt"
     (treffers van SQL 1 buiten de selectie, hoogstens 60 titels; alleen te noemen, niet te
     citeren) en 3 tot 5 concrete vervolgvragen over namen, adressen en gebeurtenissen uit de
     bronnen die niet zijn uitgewerkt. Doorvragen vervangt de verdiepingsrondes.
     Het eerste antwoord is **altijd begrensd**: hoogstens tien alinea's (ongeveer 4.000 tot
     7.000 tekens) en zes foto's. De schrijver meldt `moreAvailable` met in `moreSummary` één
     zin wat er nog meer te vertellen is (`ai_search_turn.more_available`, `more_summary`).
  6. **Volledig uitwerken**: onder een begrensd antwoord met meer toont de site "Dit is een
     beknopt antwoord. Er is meer te vertellen: …" met de knop **Volledig uitwerken (duurt
     enkele minuten)**. Die start een nieuwe beurt in dezelfde sessie (vraag "Werk het antwoord
     volledig uit", `expands_turn_id` wijst naar de basisbeurt; API
     `POST /api/ai-search/sessions/{sessionId}/turns/{turnId}/expand`) die zoeken en richten
     overslaat: dezelfde selectie (bewaard in `research_stats.selection`) wordt opnieuw uit de
     database geladen, het korte antwoord gaat als platte tekst mee als basis, en één schrijfjob
     zonder plafond (richtlengte 12.000 tot 25.000 tekens) schrijft de volledige versie. De knop
     verdwijnt zodra een uitwerking bestaat of een onderzoek loopt (na een mislukte of gestopte
     uitwerking komt hij terug als "Opnieuw volledig uitwerken"); een uitwerking meldt zelf nooit
     "meer beschikbaar". Voortgang, stopknop, bronnenpagina, delen, PDF en de vergelijktabel
     werken als bij elke beurt.
     **Eén kaart per vraag**: de site toont de uitwerking niet als eigen vraag maar in de kaart van
     de basisvraag. Tijdens het uitwerken blijft het beknopte antwoord leesbaar met daaronder een
     voortgangsregel ("Volledige uitwerking wordt geschreven, dit duurt enkele minuten") en de
     stopknop; daarna toont de kaart de volledige versie met het label **Volledige versie** en de
     link **Beknopte versie bekijken** (en terug), de doorlooptijd als "3:15 + 5:11", en delen, PDF
     en bronnen van de versie die in beeld is. Het overzicht van zoekopdrachten telt een uitwerking
     niet als vraag en toont de titel van de volledige versie; de context van een vervolgvraag
     gebruikt de volledige versie onder de oorspronkelijke vraag.

  De voortgang loopt van zoeken (6%) via richten (15%) en ophalen (45%) naar schrijven (55%).
  Na het richten toont de voortgangskaart een blok met de kop **Het antwoord komt eraan. Hier
  alvast een korte uitkomst van een eerste onderzoek:**, daaronder de eerste uitkomst (vier tot
  vijf zinnen, door het model gebaseerd op de samenvattingen en fragmenten van de gevonden
  archiefstukken) en de regel "Gebaseerd op N gevonden archiefstukken. Het volledige antwoord wordt
  nog geschreven." (zonder gevonden stukken alleen de kop "Eerste uitkomst van het onderzoek:").
  Het blok vervangt voor de pijplijn het onderzoekslogboek met "Ronde 1"; de agent behoudt zijn
  rondes. De uitkomst staat in `research_log` (veld `found`) en kost in de richtstap ongeveer
  zeven seconden extra ten opzichte van twee zinnen.
  **Stoppen** breekt het onderzoek af; **Genoeg gevonden** bestaat alleen voor de agent. Per
  vraag worden jobs, modellen, tokens en kosten bewaard in `research_stats` voor vergelijking.
  Een pijplijnonderzoek dat bij een herstart liep, wordt als mislukt gemeld.

## AI-kaarten en trefwoorden

Voor de pijplijn heeft elk record een kaart (`document_card`): een korte feitensamenvatting en
getypeerde trefwoorden (`keyword`, `keyword_mention`: persoon, adres, straat, jaar met bereik,
instelling, gebeurtenis, overig; bron FIELD uit een metadataveld of MODEL uit de vrije tekst).
Trefwoorden uit metadatavelden (straatnaam, fotograaf, auteurs, uitgever, thema, wijk, datums)
maakt de code zonder model; de vrije tekst (beschrijving, documenttekst) gaat in batches van
maximaal 40 records (en 180.000 tekens) als job naar de runtime met de rol **extractie**
(standaard een klein model, `hkh.ai-search.extraction-model`), drie batches tegelijk (`hkh.zcbs.card-parallelism`; de worker heeft zes plekken voor
applicatiewerk en de rest blijft vrij voor onderzoek). Een kaart
wordt opnieuw gemaakt als de extractieversie of de invoer (hash van tekst en documenttekst)
verandert. Het beheerscherm heeft de knop **AI-kaarten maken (ontbrekende)** (scrape-modus
`CARDS`; met "alles opnieuw" ook eerder mislukte); een volledige collectie-import sluit af met
kaarten voor nieuwe records. De status toont het aantal gemaakte en mislukte kaarten.

Grote invoer (records voor kaarten, kaarten voor het richten, documenten voor de schrijver)
gaat niet in de instructie van de runtime-job (maximaal 65.536 tekens) maar als genummerde
tekstbestanden (`/job/input/objects/<naam>-<n>/content`, elk hoogstens 45.000 tekens, regels
afgebroken op 400 tekens); de instructie verwijst ernaar en vraagt ze volledig te lezen.

## Beheer: startpagina en onderdelen

Het beheerscherm (hkh-admin) opent met een **startpagina** en heeft per onderdeel een eigen
pagina met een eigen adres (`#/collectie`, `#/ai-instellingen`, `#/ai-vergelijken`,
`#/logboek`), zodat terug, vooruit en bladwijzers in de browser werken; onbekende adressen vallen
terug op de startpagina. Op elke onderpagina staat links in de balk een terugknop naar het
overzicht en rechts het uitloggen.

De startpagina toont bovenaan "Beheerder geverifieerd · <e-mailadres>" en een ververs-knop, een
rood blok **Aandacht** als er iets mis is (AI-runtime niet bereikbaar of zonder worker, AI-vragen
mislukt vandaag, laatste collectie-run mislukt, records zonder AI-kaart), de kaart **Gebruik** en
een tegel per onderdeel met statusregels:

- **Gebruik**: per vandaag, 7 en 30 dagen de unieke bezoekers (met "waarvan N test"), AI-vragen,
  uitwerkingen, zoekopdrachten, gemiddelde antwoordtijd van AI, kosten (API-equivalent), mislukte
  AI-vragen, testverkeer en bots (niet meegeteld), plus de bewaartermijn van IP-adressen.
- **Collectie**: aantal records, laatste run (status, soort en tijdstip) en de stand van de
  AI-kaarten (klaar, mislukt, te doen).
- **AI-instellingen**: methode, modellen van richten en schrijven (of agent), en of de runtime
  bereikbaar is met hoeveel workers online.
- **AI vergelijken** en **Logboek van verzoeken**: de verzoeken van vandaag en de unieke
  bezoekers van de week.

Een tegel ontbreekt als zijn bron niet beschikbaar is. Zonder statusgegevens (fout of storing)
blijven de tegels staan met een foutmelding erboven. API: `GET /api/admin/dashboard` (module
`dashboard`, alleen voor beheerders). Het plaatsen van nieuwsberichten via beheer bestaat niet meer
(`/api/admin/news` is verwijderd; het openbare `GET /api/news` blijft bestaan).

## Beheer: vergelijken en testset

Het blok **AI-onderzoek: vergelijken** in het beheerscherm toont de testset (vaste vragen met
diepte; toevoegen en verwijderen) met de knop **Testset draaien**, die de vragen één voor één
opnieuw stelt met de nu ingestelde methode en modellen (sessies van de testset-eigenaar, niet
zichtbaar voor bezoekers), en een tabel van recente onderzoeken over alle gebruikers: wanneer,
vraag/titel, methode (met "(testset)"), diepte, status, duur, rondes, bronnen, modellen, tokens
in/uit en wie vroeg. De tokens en modellen komen uit `research_stats` (per job: rol, stap,
runtime-job, model, tokens, seconden), dat ook voor de agent-methode wordt gevuld. API:
`GET /api/admin/ai-search/turns?limit=&benchmarkOnly=`, `GET/POST /api/admin/ai-search/benchmark`,
`DELETE /api/admin/ai-search/benchmark/{id}`, `POST /api/admin/ai-search/benchmark/run`.

## Beheer: methode en modellen van de AI-onderzoeker

Het beheerscherm toont onder de collectie-import het blok **AI-onderzoeker: methode en
modellen**: een keuze **Agent / Pijplijn** voor de onderzoeksmethode, een overzicht van het
huidige model per rol (agent, extractie, richten, schrijven; "(standaard)" zolang geen
beheerder voor die rol koos), een keuzelijst **Rol om in te stellen**, het nu actieve model van
die rol (met wie het koos), een keuzelijst met alle modellen uit de catalogus van de
agent-runtime voor dit project (leverancier · model · uitvoeringswijze, met "geen worker
online" waar dat zo is), de knop **Dit model gebruiken**, **Terug naar standaard** en
**Catalogus verversen**. Bij de rol **Schrijven** staat daaronder het **Tekstbudget van de
schrijver** (tekens; 50.000 tot 2.000.000) met **Budget opslaan** en **Standaard (…)**, dat
zonder eigen keuze het schrijfmodel volgt (450.000, kleine modellen 250.000). Keuzes staan in
`app_setting` (`ai-search.execution` voor de agent, `ai-search.execution.<rol>` voor de andere
rollen, `ai-search.method`, `ai-search.write-budget`) en gelden direct voor nieuwe vragen;
lopende onderzoeken maken hun huidige methode en model af. Zonder eigen keuze erven richten en
schrijven het model van de agent; extractie krijgt het kleine extractiemodel uit de
configuratie. Alleen modellen uit de catalogus zijn te kiezen. API:
`GET`/`PUT`/`DELETE /api/admin/ai-search/model?role=…`, `PUT /api/admin/ai-search/method`,
`PUT`/`DELETE /api/admin/ai-search/write-budget`.

## Beheer: logboek van verzoeken

De pagina **Logboek van verzoeken** toont over de volle breedte van het scherm, met horizontale
scrollbalk, alle AI-vragen (met hun uitwerkingen) en zoekopdrachten in de collecties, nieuwste
eerst, met per regel het tijdstip, het IP-adres van de bezoeker, de ingelogde gebruiker (bij de
testset "testset: <beheerder>"), de soort (AI, AI (uitwerking), Collectie of Collectie:
<collectie>), de vraag of zoektekst, het model (of de modellen) uit de onderzoeksstatistieken, de
tijd tot de eerste terugkoppeling (bij een AI-vraag de tussenconclusie, bij zoeken de duur van de
zoekopdracht), de tijd tot het antwoord, de status (bezig, afgerond, mislukt, gestopt), de kosten
(API-equivalent), het browsertype en een markering **bot** en/of **test**. Boven de tabel staan een
keuze voor de soort (Alles, AI, Collectie), de schakelaars **Bots tonen** (standaard uit) en
**Testverkeer tonen** (standaard aan), het aantal regels (50 tot 1000), een ververs-knop en
"N van M regels". De vergelijktabel **Recente onderzoeken** staat op de pagina **AI vergelijken**
over de volle breedte.

Technisch: tabel `request_log` (module `requestlog`). Een AI-vraag wordt vastgelegd bij het
aanmaken van de beurt (verwijzing = beurt-id), krijgt `first_feedback_ms` bij de eerste
rondemelding of tussenconclusie en wordt afgesloten zodra de beurt slaagt, mislukt of stopt. Een
zoekopdracht (`GET /api/collections/search` met zoektekst of filters, alleen de eerste pagina)
wordt in één keer vastgelegd met de duur. Een fout in het logboek laat een verzoek nooit
mislukken. API: `GET /api/admin/requests?limit=` (beheerder).

- **IP-adres**: de kop `CF-Connecting-IP` van Cloudflare (die een client niet zelf kan invullen),
  anders het eerste adres van `X-Forwarded-For`, anders `X-Real-IP`, anders het adres van de
  verbinding. Testsetruns hebben geen webverzoek en dus geen adres.
- **Bot**: het browsertype ontbreekt of bevat een bekende bot-, crawler- of scriptaanduiding
  (bijvoorbeeld bot, crawl, spider, curl, python-requests, headless). De Flutter-app (Dart) en
  gewone browsers zijn geen bots. Bots staan in het logboek maar tellen niet mee in de bezoekers.
- **Test**: een aanroep waarvan het browsertype met `HKH-Test` begint (zo melden testaanroepen
  van de beheerder en Claude zich), een testsetrun, of een ingelogde beheerder. Testverkeer telt
  mee in alle aantallen en is gemarkeerd; de startpagina toont "waarvan N test".
- **Unieke bezoekers**: per regel een pseudonieme sleutel: `u:` de ingelogde gebruiker, `v:` het
  bezoekerscookie, anders `h:` een HMAC van IP-adres en browsertype (geheim in `app_setting`,
  `request-log.salt`). Bots tellen niet mee.
- **Bewaartermijn**: een nachtelijke taak (03:30) kapt van regels ouder dan 30 dagen het
  IP-adres af (IPv4 naar /24, IPv6 naar /48), verwijdert de bezoekerssleutel en markeert de regel
  (`ip_anonymized`, in het logboek een * achter het adres). De regel zelf blijft staan, dus
  aantallen, tijden en kosten blijven kloppen; unieke bezoekers zijn daarna niet meer te tellen.

## Privacy- en cookieverklaring

De pagina `/vereniging/privacy-en-cookies` ("Privacy- en cookieverklaring", in de voettekst onder
Vereniging naast "Privacy · Disclaimer · ANBI") beschrijft in gewoon Nederlands: wie
verantwoordelijk is (contact info@historischekringheemskerk.nl), de cookies en browseropslag (het
bezoekerscookie `hkh_ai_visitor` van een jaar, het technische cookie van de server, de
inlogsessie en de weergavekeuze; allemaal functioneel, daarom geen cookiemelding), wat het
logboek bijhoudt en waarvoor, de bewaartermijn van 30 dagen voor het volledige IP-adres, dat
vragen zonder IP-adres langer bewaard blijven, dat vragen naar een externe AI-dienst (Anthropic)
gaan, het Google-account, Cloudflare als hosting, de rechten van bezoekers en de klachtmogelijkheid
bij de Autoriteit Persoonsgegevens. De tekst is een eerste versie en moet door het bestuur worden
gecontroleerd voordat hij live gaat. Er staat bewust geen aparte melding op de AI-pagina.

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
