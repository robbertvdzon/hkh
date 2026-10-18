# AI-onderzoek als pijplijn: nachtelijke kaarten, zoeken in code, schrijven door een model

Ontwerp uit de brainstorm van 18 oktober 2026. Vervangt op termijn de huidige opzet waarin één
agent in een container zelf met curl en jq zoekt (zie `brainstorm-ai-onderzoek-pipeline.md`).
Nog niet gebouwd.

## Waarom

- De agent-opzet werkt, maar vereist een CLI-harnas (Claude Code of Codex) en een groot model
  dat tientallen stappen volhoudt. Kleinere en goedkopere modellen (Mistral, lokaal) haken daar
  af; op agentische benchmarks scoren ze een klasse lager.
- "Van een lijst documenten een goed onderbouwd antwoord schrijven" is juist de taak waar
  taalmodellen het sterkst in zijn, ook de kleinere. Als HKH het zoeken zelf doet, kan elk model
  schrijven en is de invoer per model identiek, dus eerlijk te vergelijken.
- Zoeken in code is deterministisch: paginering, dedup, plafonds en stopcriteria gaan altijd
  goed, en het model kan geen bronnen verzinnen die het niet aangereikt kreeg.

## Hoofdlijn

1. **'s Nachts**: voor elk nieuw of gewijzigd record maakt een klein model een *kaart*: korte
   feitensamenvatting plus getypeerde trefwoorden (personen, adressen, jaren, instellingen).
2. **Bij een vraag**: het model schrijft een zoekopdracht, de code voert die tolerant uit op de
   trefwoorden en geeft kaarten terug; het model trekt een tussenconclusie en bepaalt de volgende
   zoekopdracht. Eén ronde bij Snel, meer bij Doorzoeken en Uitgebreid.
3. **Schrijven**: de volledige teksten van de geselecteerde documenten gaan naar een groot
   model, dat het antwoord schrijft met genummerde bronnen.

## 1. Nachtelijke extractie: de kaart

Per record in `collection_item` één kaart, gemaakt uit titel, beschrijving, velden en (indien
aanwezig) `document_text`. Beeldbankrecords hebben geen documenttekst; hun kaart komt uit de
beschrijving en velden en krijgt `hasImage`. Foto's hebben vaak rijke metadata: een beschrijving
die straten, panden en personen benoemt, en velden als Thema, Straatnaam, Wijk, Fotograaf, Datum
opname en Bijzonderheden.

- **Gestructureerde velden worden rechtstreeks trefwoord**, zonder model: Straatnaam → STREET,
  Wijk en Thema → OTHER, Fotograaf en Auteur(s) → PERSON, Uitgever → ORGANISATION. Het model vult
  alleen aan uit de vrije tekst (beschrijving, documenttekst). Dat maakt de extractie voor de
  12.000 foto's betrouwbaarder en goedkoper.
- **Periodes zonder jaarveld**: veel foto's hebben geen jaartal in het veld maar wel "ca. 1930"
  of "jaren vijftig" in de tekst. De extractie levert dat als YEAR-trefwoord met een bereik
  (`year_from`, `year_to`), zodat zulke records bij een periodezoekopdracht meedoen.

### Datamodel

```
document_card
  collection, ident            PK, FK naar collection_item
  summary            TEXT      feitensamenvatting, 2 tot 8 zinnen, alle namen en jaren behouden
  has_image          BOOLEAN
  extraction_version VARCHAR   prompt+schema-versie, bijv. "card-v1"
  model              VARCHAR   bijv. "mistral/mistral-small-4"
  source_hash        VARCHAR   hash van de invoer (search_text + document_text), voor hergebruik
  created_at         TIMESTAMPTZ
  error              VARCHAR   laatste fout, null bij succes

keyword
  id                 BIGINT PK
  normalized         TEXT      standaardvorm, bijv. "Grada Oostrum", "Kerklaan 13a", "1949"
  type               VARCHAR   PERSON | ADDRESS | STREET | YEAR | ORGANISATION | EVENT | OTHER
  UNIQUE (normalized, type)

keyword_mention
  keyword_id, collection, ident   PK
  literal            TEXT      vorm zoals in het document, bijv. "Grad Oostrom"
  year_from, year_to INTEGER   alleen bij type YEAR; een exact jaar heeft from = to,
                               "jaren vijftig" 1950-1959, "ca. 1930" 1925-1935
  source             VARCHAR   FIELD (uit een metadataveld) of MODEL (uit de vrije tekst)

Indexen: GIN trigram op keyword.normalized en keyword_mention.literal (pg_trgm),
         B-tree op keyword_mention.year_from/year_to, B-tree op (collection, ident).
```

### Extractieprompt (schema)

Invoer: titel, jaar, beschrijving, velden, documenttekst (afgekapt op N tekens; lange
transcripties in delen, kaarten samengevoegd). Uitvoer (JSON-schema, strikt):

```json
{
  "summary": "string, 2-8 zinnen, feitelijk, alle namen/adressen/jaartallen uit de bron behouden",
  "keywords": [
    {"type": "PERSON|ADDRESS|STREET|YEAR|ORGANISATION|EVENT|OTHER",
     "literal": "zoals in de tekst", "normalized": "standaardvorm",
     "yearFrom": 1925, "yearTo": 1935}
  ]
}
```

Regels in de prompt: niets toevoegen wat niet in de bron staat; namen voluit; bij een persoon
zonder voornaam de achternaam als standaardvorm; adressen als "Straat huisnummer"; jaren als
viercijferig getal; onzekere lezingen (OCR-fouten) toch opnemen met de letterlijke vorm.

### Run

- Een scrape-modus `CARDS` naast FAST, FULL en TEXT: records zonder kaart, met een andere
  `extraction_version` of een andere `source_hash` dan de huidige invoer. Hervatbaar, met tellers
  in `scrape_run`, startbaar vanuit het beheerscherm; de volledige scrape maakt voor nieuwe
  records direct een kaart, net als nu de documenttekst.
- Backfill van de bestaande collectie: ~23.000 records; met een klein model goedkoop. Nachtelijk
  daarna alleen nieuwe of gewijzigde records.
- Het model voor extractie is instelbaar (zie 5).

## 2. Onderzoek bij een vraag

De code bestuurt de rondes; het model levert per ronde één gestructureerd antwoord.

### Ronde-lus

```
ronde = 1, gezien = {}, gekozen = {}
herhaal tot stop:
  zoekspec   = model.zoek(vraag, tussenconclusie, kaarten_tot_nu_toe)      # stap A
  kandidaten = code.zoek(zoekspec) minus gezien, gerangschikt, plafond N  # stap B
  oordeel    = model.beoordeel(vraag, kandidaten)                           # stap C
  gekozen   += oordeel.relevant; gezien += kandidaten
  tussenconclusie = oordeel.conclusie
  meld ronde (logboek + voortgang); lees bijsturing (stop)
  stop als: oordeel.genoeg, of geen nieuwe relevante kaarten, of ronde == maxRounds, of stop-knop
antwoord = model.schrijf(vraag, volledige documenten van gekozen)           # stap D
```

Diepte (bestaande keuze in de UI): Snel maxRounds 1, Doorzoeken 5, Uitgebreid 15. Het model
beslist per ronde of het genoeg heeft; de code bewaakt de plafonds.

### Stap A: zoekopdracht schrijven

Invoer: de vraag, dossiercontext, de tussenconclusie en de kaarten tot nu toe (compact).
Uitvoer:

```json
{
  "queries": [
    {"terms": ["Toos Oostrum", "Ciska Oostrum", "Oostrum"],
     "yearFrom": 1900, "yearTo": 2020,
     "collections": ["beeldbank", "artikelen", "archief"],
     "withImage": false,
     "reason": "hoofdpersonen"}
  ],
  "conclusionSoFar": "string of null in ronde 1"
}
```

Meerdere zoekopdrachten per ronde zijn toegestaan (bijv. per spoor één).

### Stap B: tolerant zoeken in code

Per term:

1. Trigram-overeenkomst op `keyword.normalized` en `keyword_mention.literal`
   (`term % keyword`, gesorteerd op `similarity`), zodat Oostrom, Van Oostrum en Grard Oostrum bij
   "Oostrum" opkomen; de twintig beste varianten gaan als *kandidaat-trefwoorden* mee terug.
2. Jaren als bereik (`yearFrom`/`yearTo`, standaard ±5 rond een genoemd jaar).
3. Vangnet: de bestaande volledige-tekstzoekmachine (`search_vector`) op dezelfde termen, voor
   wat de extractie heeft gemist.

Rangschikking van records: aantal gematchte termen, trigram-score, periode-match, en een bonus
voor records die in eerdere rondes al relevant waren. Plafond per ronde (bijv. 40 kaarten),
met per term het totaal aantal treffers erbij ("Kerklaan: 617, 40 getoond") zodat het model kan
verfijnen.

### Stap C: beoordelen

Invoer: de vraag, de kandidaat-kaarten (titel, jaar, collectie, hasImage, samenvatting,
trefwoorden) en de kandidaat-trefwoordvarianten. Uitvoer:

```json
{
  "relevant": [{"collection": "beeldbank", "ident": "11258", "why": "..."}],
  "acceptedVariants": ["Oostrom", "Van Oostrum"],
  "rejectedVariants": ["Oosterman"],
  "conclusionSoFar": "twee korte zinnen",
  "nextLeads": ["pastoor Van den Nouweland", "Kerklaan 13a"],
  "enough": false
}
```

De code bewaart `relevant` en `acceptedVariants`; `nextLeads` voedt stap A van de volgende
ronde. `conclusionSoFar` en `nextLeads` gaan naar het onderzoekslogboek in de UI (Story F), de
knop "Genoeg gevonden, schrijf het antwoord" zet `stop`.

### Stap D: schrijven

Invoer: de vraag, dossiercontext, en de gekozen documenten met *genummerde* bronnen:
`[1] beeldbank 11258 "Straten Kerklaan" (foto) — volledige tekst/beschrijving`. Tokenbudget
(bijv. 200.000): de hoogst gerangschikte documenten volledig, de rest alleen als kaart.
Uitvoer: hetzelfde resultaatschema als nu (`title`, `answerHtml`, `sources`,
`suggestedFollowUps`), maar met bronverwijzingen als nummers (`data-hkh-source="3"`); de code
vertaalt nummers naar collection/ident. Een nummer buiten de lijst wordt verwijderd. De renderer,
de bronnenpagina en de PDF-export blijven ongewijzigd. Niet-gevolgde `nextLeads` worden
`suggestedFollowUps`.

Regels in de schrijfprompt blijven: alleen feiten uit de aangeleverde documenten, onzekerheid
benoemen, foto's als `<figure>` alleen bij bronnen met `hasImage`, lengtedoel per diepte.

## 3. Vervolgvragen en dossiers

- Een vervolgvraag start met de gekozen documenten van de vorige beurt als `gezien` én als
  startset voor stap A; de tussenconclusie van de vorige beurt is de startconclusie.
- Dossiercontext (doel, feitenlijst) gaat mee in stap A, C en D zoals nu in de prompt.

## 4. Voortgang en bijsturen

- Elke ronde levert een logboekregel (ronde, aantal gekozen documenten, conclusie, volgende
  sporen); dat is het bestaande `research_log`, nu gevuld door de code in plaats van via de
  meld-URL van de agent.
- De stop-knop werkt op de rondegrens; de meld-URL en het controltoken vervallen.
- Voortgangspercentage: ronde / maxRounds tot 70%, schrijven 70 tot 100%.

## 5. Modellen en instellingen

Drie rollen, elk apart instelbaar in het beheerscherm (uitbreiding van de huidige modelkeuze):

| Rol | Stappen | Verwachte keuze |
| --- | --- | --- |
| extractie | nachtelijke kaarten | klein: Mistral Small, Haiku, of lokaal via Ollama |
| onderzoek | A en C | klein tot middel: Mistral Small/Medium, Sonnet |
| schrijven | D | groot: Mistral Large 4, Sonnet 5.5, Opus 5.5 |

Uitvoering via de agent-runtime in `API`-modus met `STRUCTURED_GENERATION` en een JSON-schema;
geen container en geen harnas. Daarvoor is in de runtime een Mistral-vendor nodig
(OpenAI-compatibel endpoint, eigen sleutel) en later een lokale vendor. Kosten en tokens worden
per stap geregistreerd, zodat per vraag zichtbaar is wat extractie, onderzoek en schrijven kosten.

## 6. Overgang

- Instelling "onderzoeksmethode": `AGENT` (huidig) of `PIJPLIJN`. Beide blijven werken tot de
  pijplijn op de testvragen (Oostrum, Commandeurs, Hertaing) minstens gelijkwaardig is.
- Vergelijkingsmaat per vraag: doorlooptijd, aantal rondes, aantal bronnen, overlap met de
  referentie-antwoorden, kosten, en een leesoordeel van Robbert.

## 7. Bouwvolgorde

1. Datamodel (`document_card`, `keyword`, `keyword_mention`, `pg_trgm`) en de `CARDS`-scrape-modus
   met extractie via de runtime; beheerschermknop; backfill draaien.
2. Tolerant zoeken in code (stap B) als interne service, met tests op spellingvarianten en
   jaarbereiken, nog zonder model.
3. Ronde-lus met stap A en C, logboek en stop-knop; eerst met Claude als model.
4. Stap D met genummerde bronnen; resultaat door de bestaande renderer.
5. Instelling onderzoeksmethode en de drie modelrollen in het beheerscherm.
6. Mistral-vendor in de runtime (API-modus); vergelijking Claude tegen Mistral op dezelfde
   invoer.
7. Agent-pad verwijderen als de pijplijn wint.

## 8. Risico's en open punten

- **Extractiekwaliteit bepaalt alles.** Een naam die de kaart mist is alleen nog via het
  volledige-tekstvangnet vindbaar. Steekproefsgewijs kaarten nakijken na de backfill.
- **Lange documenten** (transcripties tot 18.000 tekens): samenvatten in delen en samenvoegen,
  zonder namen en jaren te verliezen.
- **Te brede termen** ("Kerklaan", "Heemskerk") leunen op de rangschikking en het plafond per
  ronde; het model moet leren verfijnen met periode en collectie.
- **Jaartallen in OCR** zijn soms verminkt ("194Y"); de extractie neemt de letterlijke vorm op,
  het jaarbereik zoekt alleen op geldige getallen.
- **Wat de agent nog had**: tijdens het lezen van een document meteen doorzoeken op een detail.
  In de pijplijn gebeurt dat op rondegrenzen via `nextLeads`. Inschatting: verwaarloosbaar
  verlies tegen grote winst in snelheid, kosten en voorspelbaarheid.
- **Rate limits** bij Mistral zijn ongepubliceerd; per stap een terugval naar een ander model uit
  de catalogus is wenselijk zodra de runtime dat ondersteunt.
