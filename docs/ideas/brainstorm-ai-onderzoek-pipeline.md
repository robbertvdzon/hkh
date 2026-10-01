# AI-archiefonderzoek: besluiten en stappen

Uitkomst van de brainstorm van 30 september 2026. Vervangt het eerdere pijplijnvoorstel dat een
AI-model uit een gesprek had gedestilleerd; dat voorstel (feitenkaarten, orkestratie in code,
lokale modellen per stap) wordt niet gebouwd.

## Wat Robbert wil

1. Sneller antwoord: 2 minuten is prima, 4 minuten kan net, 10 minuten is veel te lang.
2. De bronnen onder het antwoord als aparte pagina ("klik hier voor alle bronnen").
3. Later ook kunnen zoeken met een lokaal model op een MacBook met 64 GB.
4. De tekst van de PDF's (archief, artikelen) in de database, bruikbaar voor de AI, voor gewoon
   zoeken in de collectie en zichtbaar op het scherm.

## Wat de runtime-logs lieten zien

Drie runs van dezelfde vraag (wijk Commandeurs), gemeten in de transcripten van de agent-runtime:

| Run | Totaal | Onderzoek | Antwoord schrijven | Antwoordlengte |
| --- | --- | --- | --- | --- |
| Opus 5, lang | 10:15 | 3:10 (26 tool-calls) | 2× 15.000 tokens: eerst naar bestand, daarna opnieuw als eindresultaat | ~16.000 tokens |
| Opus 5, gemiddeld | 6:32 | 2:40 (22 tool-calls) | 3:50 (66 tokens/s) | ~15.000 tokens |
| Sonnet 5.5 | 2:07 | 0:20 (6 tool-calls) | 0:34 (116 tokens/s) | ~4.000 tokens |

- Het schrijven domineert, niet het zoeken. Opus schrijft 15.000 tokens op 66 tokens/s en
  schreef in de lange run het antwoord twee keer.
- Sonnet 5.5 schrijft bijna twee keer zo snel maar koos zelf voor een kort antwoord en deed
  weinig zoekrondes. De prompt zegt niets over gewenste lengte of onderzoeksdiepte.
- De Sonnet-run verloor 70 seconden aan het pullen van een nieuw executie-image
  (`docker run --pull always` op tag `main`); dat gebeurt alleen na een image-update.
- De agent bewaart API-antwoorden in bestanden in zijn container en filtert met jq. Alleen wat
  hij print komt in de modelcontext. De container is per onderzoek; er is geen cache.

## Wat we over de PDF's weten

- De AI ziet nu alleen de metadata (omschrijving van 150 tot 550 tekens). De PDF wordt in de
  backend alleen gebruikt voor thumbnails en de ingebedde viewer.
- De code is al voorbereid op documenttekst (`CollectionCatalog.documentFields`, snippet
  "Gevonden in documenttekst", `documentTextAvailable`), maar in productie heeft geen item zo'n
  veld. ZCBS gebruikt de OCR-tekst intern voor zoeken en toont hem niet op de recordpagina.
- De PDF's hebben wél een tekstlaag. Zes steekproeven: 1.700 tot 13.100 tekens per document,
  krantenknipsels goed, een getypte akte uit 1949 met OCR-fouten. Extractie met PDFBox (zit al
  in het project) volstaat; er is geen OCR-project nodig.
- Steekproef PDF-beschikbaarheid: archief ~95%, artikelen 100%, overige collecties geen.
  Ruim 2.200 bestanden van 1,5 tot 4 MB.
- Een rescrape overschrijft `fields` en `search_text` volledig; de documenttekst mag daar dus
  niet in, maar hoort in een eigen kolom.
- Alleen de FULL-scrape kent de PDF-link; FAST leest alleen lijstpagina's.
- Scrapes worden handmatig vanuit het beheerscherm gestart; er is geen nachtelijke planning en
  die is ook niet gewenst.

## Besluiten

- Geen feitenkaarten of pijplijn. De agent blijft één runtime-job die zelf via de REST-API zoekt.
- Documenttekst wordt bij het FULL-scrapen direct uit de PDF gehaald en opgeslagen in een eigen
  kolom, met een eenmalige backfill vanuit het beheerscherm voor de bestaande collectie.
- De tekst doet mee in gewoon zoeken (zoekvector), levert het bestaande snippet in de
  zoekresultaten en is op de detailpagina zichtbaar als inklapbaar blok, gemarkeerd als
  automatisch herkende tekst.
- De detail-API geeft de tekst mee; de AI-prompt vraagt de agent om in de tekstbestanden naar
  relevante passages te zoeken in plaats van hele documenten te printen.
- Snelheid komt uit de prompt: lengtedoel, één keer schrijven, minimale onderzoeksdiepte.
- Lokaal model is geparkeerd tot de prompt-story is gemeten. Een lokaal model schrijft naar
  verwachting 30 tot 60 tokens/s, dus lange antwoorden blijven daar traag.

## Stand van zaken

Stories A, B, C en F zijn op 30 september 2026 gebouwd en naar `main` gepusht. De dieptekeuze
is uitgevoerd als stappenbalk met uitleg en duur in de knop (ontwerpvariant B). Nog te doen:

1. In het beheerscherm **Documenttekst ophalen** starten voor de bestaande collectie (eenmalig,
   ruim 2.200 PDF's in het scrape-tempo).
2. Story A meten: de Commandeurs- en Hertaing-vragen in alle drie de dieptes draaien en in de
   runtime-transcripten doorlooptijd, rondes, antwoordlengte en bronnen vergelijken met de
   Opus-referenties. Zo nodig het plafond van Uitgebreid of de lengtedoelen bijstellen.

## Stories

### Story A: onderzoeksdiepte kiezen en één keer schrijven (eerst, klein, direct meetbaar)

De lange runs waren niet traag door het volgen van sporen (drie minuten onderzoek) maar door
het twee keer schrijven van het antwoord (zeven minuten). Sporen volgen blijft dus mogelijk;
de gebruiker kiest hoeveel rondes de agent daarvoor krijgt.

Een ronde is: zoektermen bepalen, alle resultaatpagina's ophalen, details van de inhoudelijk
relevante treffers lezen. Ronde 1 gebruikt termen uit de vraag; elke volgende ronde gebruikt
aanknopingspunten (personen, adressen, gebouwen, bedrijven) uit de vorige ronde. De agent
stopt eerder als een ronde geen nieuwe relevante bronnen oplevert; het maximum is een plafond.

Keuze naast het vraagveld in de frontend:

| Optie | Rondes | Antwoord |
| --- | --- | --- |
| Snel (standaard) | 1 | compact maar volledig |
| Doorzoeken | 3 tot 5 | verbanden één niveau diep |
| Uitgebreid | 6 tot 15 | lang verhaal met alles eromheen |

Meting op 1 oktober 2026 (Oostrum-vraag, Uitgebreid): Sonnet 5.5 stopte na 2 rondes (2:17,
26 bronnen), Opus 5.5 na 5 (5:32, 54 bronnen), Opus 5 na 13 (14:44, 58 bronnen), Haiku 4.5 na
3 (5:28, 18 bronnen, zwak). Daarom zijn gemelde sporen bindend gemaakt en geldt per diepte een
minimum aantal rondes. Opus 5.5 is de beste balans; het model is in het beheerscherm te kiezen.

1. API: `depth` (FAST, EXTENDED, THOROUGH) bij het starten van een zoekopdracht en bij een
   vervolgvraag; opslaan op `ai_search_turn`, zodat de prompt en de weergave het kennen.
2. `AiSearchService.buildPrompt`: de rondedefinitie, het maximum voor de gekozen diepte, een
   lengtedoel per diepte, de regel "print bij elk nieuw spoor één regel `Spoor: ...`" voor de
   voortgangsmelding, en de regel: schrijf het antwoord één keer, direct als eindresultaat,
   niet eerst naar een bestand. Sporen die door het plafond niet meer gevolgd zijn komen in
   `suggestedFollowUps`.
3. `AgentRuntimeClient.classifyActivity`: de `Spoor:`-regels doorgeven als voortgangstekst.
4. Frontend: keuze bij het vraagveld (standaard Snel) en bij vervolgvragen; de gekozen diepte
   tonen bij het antwoord.
5. Executietimeout per diepte (nu vast 900 s), ruim boven het verwachte maximum, zodat een
   job niet faalt maar de agent zelf stopt.
6. Meten op preview met Sonnet 5.5: dezelfde vragen als de Opus-referenties (Commandeurs,
   Hertaing) in alle drie de dieptes; doorlooptijd, rondes, tool-calls, antwoordlengte en
   aantal bronnen uit de runtime-transcripten. Doel: Snel binnen 2 minuten, Uitgebreid
   Opus-rijk binnen 5 minuten.

### Story B: documenttekst uit PDF's (grootste story)

1. Migratie: kolommen `document_text`, `document_pdf_hash`, `document_text_extracted_at`,
   `document_text_error` op `collection_item`; `search_vector` opnieuw genereren uit
   `search_text` plus `document_text`; GIN-index opnieuw aanmaken.
2. `PdfTextExtractor` met PDFBox `PDFTextStripper`: witruimte normaliseren, bovengrens op
   lengte, fouten vastleggen in plaats van de scrape te laten falen.
3. FULL-scrape: na het opslaan van een record met `pdf_url` de PDF ophalen via `ZcbsClient`
   (met dezelfde wachttijd), tekst extraheren en opslaan; overslaan als de hash gelijk is.
   Voortgang in `scrape_run` (teller voor documenten).
4. Backfill-service met hetzelfde single-thread- en hervatbaarheidspatroon als de scraper:
   alle items met `pdf_url` en zonder tekst. Beheer-endpoint voor starten en status, knop in
   `frontend-admin` naast de scrape-knoppen, met voortgang en foutentelling.
5. Repository: de `documentText`-expressie op `fields` vervangen door de kolom; snippet en
   `documentTextAvailable` uit de kolom; upsert laat de kolom ongemoeid.
6. API: detail-response krijgt `documentText`; zoekresultaten houden alleen het snippet.
7. Publieke frontend: op `collection_detail_page.dart` een inklapbaar blok "Documenttekst
   (automatisch herkend)" tussen metadata en PDF-viewer.
8. AI-prompt: regel 3a uitbreiden: documenttekst in bestanden bewaren en met grep of jq alleen
   relevante passages printen.
9. Bestaande integratietest voor het OCR-veld ombouwen naar de kolom; test voor scrape met PDF
   en voor de backfill.
10. Uitrollen, backfill starten vanuit het beheerscherm, zoekkwaliteit controleren.

### Story C: bronnen als aparte pagina (klein, frontend)

1. In de publieke frontend onder het AI-antwoord de bronnenlijst vervangen door
   "Alle bronnen (N)" die een aparte pagina of dialoog opent met de volledige lijst.
2. De `sources`-lijst in het resultaat is al gescheiden van de tekst; backend ongewijzigd.

### Story F: onderzoekslogboek en bijsturen (gebouwd)

De agent kan al naar buiten praten (logregels) en de HKH-API aanroepen; daar bouwt dit op.

1. De agent meldt na iedere afgeronde ronde zijn stand met een POST op een per-vraag geheime
   URL (token alleen in de prompt): rondenummer, aantal relevante bronnen, twee zinnen over wat
   hij weet en de sporen die hij hierna wil volgen. HKH bewaart dat als `research_log` bij de
   vraag en zet de voortgangsmelding op de laatste ronde.
2. In het antwoord op die POST krijgt hij de bijsturing van de gebruiker: `stop` (schrijf nu het
   antwoord met wat je hebt) en/of `hint` (aanwijzing voor de volgende ronde). Bijsturing wordt
   één keer afgeleverd en daarna als "opgepakt" getoond.
3. Frontend: onderzoekslogboek in de voortgangskaart, veld voor een aanwijzing en de knop
   "Genoeg gevonden, schrijf het antwoord"; alleen bij Doorzoeken en Uitgebreid.
4. Kanttekening: bijsturen landt op rondegrenzen (tot een minuut vertraging) en vereist dat het
   model de meldregel uit de prompt trouw uitvoert; het logboek werkt ook zonder bijsturen.

### Geparkeerd

- Zoekwerk door de backend laten voorbereiden (kandidaten kant-en-klaar in de prompt).
- Antwoord streamend tonen in de UI (de runtime ontvangt de deelberichten al).
- Lokaal model via een worker op de MacBook (`ExecutionMode.LOCAL` uitbreiden naar
  structured generation).
- Executie-image vooraf pullen op de worker na een image-update.
