# Voorstel: pijplijn v2 in twee AI-runs

Status: gebouwd op 20-10-2026 (zie functional-spec, "AI-onderzoek: methode agent of pijplijn").
Aanvulling later die dag: het eerste antwoord is altijd begrensd (tien alinea's) en de gebruiker
kan het via **Volledig uitwerken** met dezelfde bronnen laten uitbreiden (eigen beurt).
Afwijkingen van het voorstel: de planjob bestaat nog als terugval bij nul termen of nul
treffers; "Ook gevonden" telt hoogstens 60 regels. Bouwt voort op
[ai-onderzoek-pijplijn-trefwoorden.md](ai-onderzoek-pijplijn-trefwoorden.md) en de uitslagen in
[ai-onderzoek-testset.md](ai-onderzoek-testset.md).

## Waarom

Reeks E (pijplijn, Haiku 5.5) liet drie zwaktes zien:

- "Snel" stuurt de 25 best scorende kaarten blind naar de schrijver; het ene artikel dat ertoe
  doet verdrinkt tussen foto's (Nielen, Bekker) en "de oudste" wordt niet op jaar gesorteerd.
- De beoordelaar ziet maar 40 van soms 170 treffers.
- "Uitgebreid" heeft geen plafond: 12 rondes, 226 gekozen records, 43 minuten (Bachstraat).

Doel: "snel" in 1 tot 2 minuten met precies twee AI-runs, alles wat de schrijver noemt ook echt
gelezen, en harde grenzen voor doorzoeken en uitgebreid.

## Eén variant: altijd twee AI-runs

De diepteknop (snel/doorzoeken/uitgebreid) vervalt. Verdieping doet de gebruiker zelf via de
voorgestelde vervolgvragen; de sessiecontext gaat mee.

```
vraag ─(code)─► zoektermen ─(SQL 1)─► alle kaarten (max 300, met tekstfragmenten)
     ─(AI 1: richten)─► tussenconclusie + query
     ─(SQL 2)─► alle passende records; korte altijd volledig, lange op prioriteit tot het tekstbudget
     ─(AI 2: schrijven)─► antwoord met foto's, genummerde bronnen, "ook gevonden", vervolgvragen
```

### Stap 0: zoektermen uit de vraag (code, geen AI)

- Tekst tussen aanhalingstekens; woorden met hoofdletter en namen met tussenvoegsel
  ("Van Oosten", "Maerten van Heemskerckstraat"); jaartallen en perioden ("jaren vijftig",
  "1950-1960"); straat- en adrespatronen; overige woorden van vier letters of meer minus
  stopwoorden. Bestaat al deels als terugvaloptie in de planstap.
- Signaalwoorden sturen de sortering: "oudste/eerste/vroegste" = jaar oplopend,
  "nieuwste/laatste" = jaar aflopend.
- De planstap met AI vervalt. Terugval: bij nul treffers alsnog één planjob.

### Stap 1: SQL 1, tolerant en breed

Bestaande KeywordSearchService (pg_trgm op trefwoorden, ILIKE, full-text), met drie wijzigingen:

- Niet 40 maar alle treffers, tot een plafond van 300 kaarten. Boven het plafond gaan de 300
  best gerangschikte mee en ziet AI 1 per term hoeveel er afvielen, zodat hij kan verfijnen.
- Rangschikking: titeltreffer > trefwoordtreffer > teksttreffer; records met documenttekst
  (artikelen, transcripties) krijgen een vaste bonus zodat ze niet onder foto's zakken; bij een
  jaarsignaal wordt binnen de treffers op jaar gesorteerd.
- Bij een treffer in `document_text` gaat het fragment rond de treffer mee via `ts_headline`
  (twee fragmenten van hoogstens 35 woorden, alleen voor de max 60 teksttreffers per term,
  tekst begrensd op 50.000 tekens), zodat AI 1 ziet wat een artikel over de term zegt, ook als
  de samenvatting dat niet noemt. Terugval zonder stamvorm: ILIKE met `position()`/`substring()`.

Kosten: minder dan een seconde.

### Stap 2: AI 1, richten (rol ONDERZOEK)

Invoer: vraag, context, per term het aantal treffers (en hoeveel buiten het plafond vielen),
en alle kaarten (samenvatting tot 1.500 tekens, trefwoorden, jaar, foto ja/nee, fragment bij
teksttreffer). 170 kaarten is ongeveer 150.000 tekens; dat gaat als bestand mee (bestaande
JobPrompts.assemble), kleinere sets inline.

Uitvoer (JSON-schema), bewust klein:

- `conclusionSoFar`: twee zinnen; wordt aan de gebruiker getoond en gaat mee naar de schrijver.
- `query`: de criteria voor SQL 2: `terms` (met goedgekeurde varianten), `yearFrom`/`yearTo`,
  `collections`, `sortByYear` (asc/desc/none) en `includeRecords`: idents die hoe dan ook
  vooraan meegaan, voor records die AI 1 in de kaarten zag maar die geen zoekterm dekt (biografie
  Nielen in Heemskring 64; foto "Rendorpplein 1955" bij Bekker). Geen recordlimiet; promptregel:
  verfijn tot de treffers over de vraag gaan, anders wordt het antwoord een opsomming.

Geen keuzelijst met redenen, geen "ook gevonden" door AI; dat doet de code (zie stap 4).

Model: Sonnet 5.5 (10 tot 50 s per ronde in de metingen met Sonnet, kiest zuinig). Haiku 5.5
was hier 90 tot 430 s en te gul.

### Stap 3: SQL 2, met tekstbudget in plaats van recordlimiet

Voert `query` uit (zelfde rangschikking als SQL 1, of op jaar als `sortByYear` staat), zet
`includeRecords` vooraan. Geen beoordeling meer: de selectie is de query. Daarna bepaalt de
omvang wat volledig meegaat, niet het aantal:

1. Korte records (geen documenttekst, of korter dan 3.000 tekens: foto's, bidprentjes,
   objecten, library, de meeste transcripties en archiefstukken) gaan altijd volledig mee.
2. Lange records (artikelen, lange archiefstukken) gaan in rangvolgorde volledig mee tot het
   tekstbudget op is; per document een plafond van 60.000 tekens (raakt 9 artikelen en 1
   transcriptie).
3. Wat buiten het budget valt, gaat mee als kaart plus fragment, gemarkeerd "niet volledig
   gelezen"; de schrijver mag ernaar verwijzen, niet eruit citeren.

Tekstbudget per schrijfmodel, instelbaar in beheer: Sonnet 450.000 tekens (ongeveer 140.000
tokens; ruim 40 gemiddelde artikelen of 600 foto's), Haiku 5.5 250.000 (schrijft traag bij
grote invoer: Bachstraat met 118 bronnen kostte 10 minuten).

Omvang van de collectie (productie, 20-10-2026):

| collectie | records | record zonder tekst | documenttekst mediaan | p90 | max |
|---|---|---|---|---|---|
| beeldbank | 12.044 | 700 tekens | geen | | |
| bidprent, objecten, library | 3.717 | 200 tot 360 | geen | | |
| transcripties | 5.187 | 490 | 1.900 | 3.200 | 300.000 (één) |
| archief | 1.763 | 910 | 2.600 | 5.900 | 69.000 |
| artikelen | 523 | 1.080 | 10.700 | 28.000 | 81.000 |

### Stap 4: AI 2, schrijven (rol SCHRIJVEN)

Ongewijzigd in opzet: volledige teksten van de geselecteerde records als genummerde bronnen
(bestanden via uploads, tekstbudget per model, 60.000 per document), schrijver gebruikt
uitsluitend die bronnen, foto's tussen de tekst, bronnummers in de HTML. Nieuw:

- "Ook gevonden, niet gebruikt": door de code samengesteld uit de treffers van SQL 1 die niet in
  SQL 2 zitten (titel, jaar, foto ja/nee; max 50 regels). De schrijver mag ernaar verwijzen,
  niet eruit citeren.
- Vervolgvragen: 3 tot 5, gebaseerd op namen, adressen en gebeurtenissen die in de gelezen
  teksten staan maar in het antwoord niet zijn uitgewerkt, plus de "ook gevonden"-lijst. Dit
  vervangt de verdiepingsrondes; bestaande `suggestedFollowUps` wordt daarvoor aangescherpt.

Model: Sonnet 5.5 voor snelheid (46 s met Opus gemeten; Sonnet vergelijkbaar), Haiku 5.5 als
goedkoop alternatief (40 tot 136 s, rijke tekst). Beide meten.

### Verwachting

| onderdeel | tijd |
|---|---|
| termen + SQL 1 (met fragmenten) | < 1 s |
| richten (Sonnet) | 15 tot 45 s |
| SQL 2 | < 1 s |
| schrijven (Sonnet) | 30 tot 60 s |
| wachten op slots | 5 tot 10 s |
| totaal | 1 tot 2 min |

Kosten ongeveer $0,05 tot $0,10 per vraag met Sonnet op beide rollen; met Haiku 5.5 als
schrijver rond $0,03. Ter vergelijking agent-Opus $0,21 tot $0,27, agent-Sonnet $0,04 tot $0,06.

### Wat vervalt in de code

Rondelus, beoordelingsprompt, stopregels, rondeplafonds per diepte, voortgang per ronde, de
diepteknop in de publieke site en de dieptekolom als instelling (in de testset blijft hij als
label). De stopknop blijft (annuleert de lopende job).

## Wat niet verandert

- Alle AI via de agent-runtime in abonnementsmodus; geen API-tokens in HKH.
- Kaarten blijven zoals ze zijn (card-v1); geen nieuwe extractie nodig.
- Geen databasemigratie; `research_stats` en de vergelijktabel blijven werken (planjob en
  beoordelingsjobs vallen weg, er blijven twee jobs per vraag).
- De agent-methode blijft beschikbaar als alternatief in beheer.

## Bouwvolgorde en inschatting

1. KeywordSearchService: plafond 300, rangschikking met tekst- en titelbonus, jaarsortering,
   fragmenten via `ts_headline`, en een `select(query)` voor SQL 2 met `includeRecords` en
   het tekstbudget met prioriteit (kort altijd, lang op rang). Tests op de bestaande
   testdatabase. (halve dag)
2. Termextractie uit de vraag in code; planjob alleen als terugval bij nul treffers. (uur)
3. Richtstap: nieuw schema (`conclusionSoFar`, `query`), prompt; rondelus en beoordeling
   verwijderen; diepte uit de site en de API (met behoud van de kolom in de database). (halve dag)
4. Schrijfstap: "ook gevonden"-regels uit code, vervolgvragen aangescherpt. (uur)
5. Meten met de testset: reeks F (richten Sonnet, schrijven Haiku 5.5) en reeks G (Sonnet op
   beide), vergelijken met reeks A tot E. (een uur runtime per reeks)

Totaal ongeveer anderhalve dag bouwen, geen nachtelijke kaartenrun.

## Risico's

- Termextractie zonder AI mist soms een synoniem ("kapper" tegenover "barbier"). Vangnet: AI 1
  ziet de treffertelling per term en kan in `query` andere termen opgeven.
- 300 kaarten inline of als bestand is voor Sonnet geen probleem (ongeveer 70.000 tokens), maar
  de richtstap wordt dan 30 tot 60 s. Bij veelvoorkomende termen ("kerk") moet de rangschikking
  het werk doen; daarom de titel- en tekstbonus.
- SQL 2 selecteert op criteria, niet per record. Bij vragen waar de relevante records geen
  gemeenschappelijke term hebben, moet AI 1 ze via `includeRecords` noemen; de prompt moet dat
  uitdrukkelijk vragen.
- Een te brede query ("kerk") geeft de schrijver honderden records en een opsomming als
  antwoord. AI 1 ziet de treffertelling per term en moet verfijnen; het tekstbudget begrenst de
  schade.
- Zonder verdiepingsrondes hangt een netwerkvraag (Oostrum) af van doorvragen door de gebruiker.
  De vervolgvragen moeten daarom concreet zijn (namen, adressen), niet algemeen.
