# Testset AI-onderzoek: agent tegen pijplijn

Acht vragen uit de geschiedenis van de HKH-site, gekozen op spreiding van soort en diepte.
Alle vragen zijn eerder met de agent-methode gesteld, zodat er per vraag een oud antwoord naast
het nieuwe kan. De vragen staan letterlijk (inclusief spelling) in de testset van het beheerscherm
(blok **AI-onderzoek: vergelijken**); "Testset draaien" stelt ze één voor één opnieuw met de dan
ingestelde methode en modellen.

## De tests

| # | Vraag (letterlijk) | Diepte | Soort | Waar op letten |
| --- | --- | --- | --- | --- |
| 1 | wie was burgemeester nielen? | snel | persoon, feitelijk | jaartallen ambtsperiode (1912-1977, burgemeester ruim dertig jaar), geen verzonnen feiten, kort en volledig |
| 2 | Wat kun je vertellen over Kapper Bekker? | snel | bedrijf/familie | honderd jaar familiebedrijf (1911-2011), Deutzstraat, generaties, foto's van de zaak |
| 3 | zeelaan | snel | straat, één woord | begrijpt de losse term; van tuinderslaantje tot straat in Kerkbeek; straatbeelden door de jaren heen |
| 4 | Zoek de oudste luchtfoto van Heemskerk | snel | foto's, selectie op jaar | vindt de oudste (agent: Fort Veldhuis, 1922), toont de foto, beargumenteert waarom dit de oudste is |
| 5 | wat kun je vertellen over touwslagerij van oosten. | doorzoeken | bedrijf met verhuizing | Oosterweg naar Maerten van Heemskerckstraat, personen, periode; aantal rondes en of de verhuizing gevonden wordt |
| 6 | kun je wat vertellen over de bachstraat en de mensen die daar woonden | uitgebreid | straat plus bewoners | van het Hoge Werfje tot de Heemsuite; bewoners met huisnummers; foto's tussen de tekst |
| 7 | Ik wil dat je alles opzoekt dat je kunt vinden over Toos Oostrum en Ciska Oostrum. Maar niet alleen van hun, ook van hun familie of andere relates. En van die familie en relaties ook kijkt wat hier over te vinden is. En als weer meer intrassante relaties over te vinden is, dan daar ook over. Dus van Toos Oostrum en Ciska Oostrum en tot een paar relaties diep. Dat geld ook voor de gebouwen en plaatsen die van toepassing zijn. Maak er daarna een mooi verhaal van om die geschiedenis weer te geven. Met daarbij gevonden plaatjes er tussen, en bij alle feiten wil ik een footnoot hebben (bv (1) en dat onderin dan 1: met een naar een onderdeel uit het archief | uitgebreid | persoonsnetwerk | zus Grad, pastoor Van den Nouweland, Kerklaan 13a/15, scholen; spellingvarianten Oostrum/Oostrom; aantal bronnen en of ze echt gebruikt zijn |
| 8 | wat weet je van Los Tamaros | uitgebreid | niets in de collectie | zegt netjes "niets gevonden" zonder te verzinnen; hoeveel rondes en tijd dat kost |

## Referentie-antwoorden (agent-methode)

| # | Datum | Model | Diepte | Duur | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 16-10-2026 08:54 | Opus 5.5 | snel | 1 min 15 s | zie beheerscherm | zie beheerscherm | "Henk Nielen (1912-1977), ruim dertig jaar burgemeester van Heemskerk" |
| 2 | 16-10-2026 11:47 | Opus 5.5 | snel | 1 min 56 s | | | "Kapper Bekker in Heemskerk: honderd jaar familiebedrijf aan de Deutzstraat" |
| 3 | 16-10-2026 18:45 | Opus 5.5 | snel | | | | "De Zeelaan in Heemskerk: van tuinderslaantje tot straat in Kerkbeek" |
| 4 | 17-10-2026 08:13 | Opus 5.5 | snel | 1 min 37 s | | $0,26 | "De oudste luchtfoto van Heemskerk in de HKH-collectie: Fort Veldhuis, 1922" |
| 5 | 03-10-2026 22:35 | Opus 5 | doorzoeken | | | | "Touwslagerij Van Oosten: van de Oosterweg naar de Maerten van Heemskerckstraat" |
| 6 | 03-10-2026 21:24 | Opus 5 | uitgebreid | | | | "De Bachstraat in Heemskerk: van het Hoge Werfje tot de Heemsuite, en de mensen die er woonden" |
| 7 | 17-10-2026 (Opus 5.5, agent) | Opus 5.5 | uitgebreid | 5 min 32 s | | $1,21 | 54 bronnen; eerder Opus 5 (agent): 14:44, 58 bronnen, $4,43 |
| 7 | 18-10-2026 12:23 (pijplijn) | Sonnet 5.5 + Opus 5.5 | uitgebreid | 9 min 35 s (waarvan 3:40 wachten) | 1,1M / 35k | $0,85 | 6 rondes, 45 van 59 bronnen gebruikt |
| 8 | 18-10-2026 20:04 (pijplijn) | Sonnet 5.5 + Opus 5.5 | uitgebreid | | | | "Los Tamaros: niets gevonden in de collectie"; nog geen agent-referentie |

Lege cellen vult het beheerscherm (de tabel "Recente onderzoeken") zodra het de cijfers bij de
runtime heeft opgehaald; ze zijn hier niet overgetypt.

De duur, tokens en kosten per beurt staan in de vergelijkingstabel in het beheerscherm; die zijn
automatisch. Kosten zijn de API-equivalente schatting van de runtime in USD (per job opgeteld);
via het abonnement is dat geen factuur, maar wel de maat om modellen tegen elkaar te zetten. Voor
oudere beurten haalt het beheerscherm tokens en kosten alsnog op bij de runtime, zolang die de job
nog bewaart. Kwaliteit is een leesoordeel: volledigheid (staan de kernfeiten uit de referentie
erin), juistheid (niets verzonnen, bronnen kloppen), bronnen (aantal gebruikt, relevant), vorm
(foto's op hun plaats, leesbaar verhaal).

## Uitvoering

1. Methode en modellen instellen in het beheerscherm (bijvoorbeeld pijplijn met onderzoek
   Sonnet 5.5 en schrijven Opus 5.5).
2. **Testset draaien**; de acht vragen lopen achter elkaar. Reken op ca. 20 tot 25 minuten en een
   flink deel van het 5-uursvenster van het Claude-abonnement (vooral Opus bij de uitgebreide
   vragen). Kies een moment waarop niemand anders Claude nodig heeft.
3. Per vraag het nieuwe antwoord naast de referentie leggen en het oordeel noteren in de tabel
   hieronder.
4. Herhalen met een andere instelling (bijvoorbeeld schrijven met Sonnet 5.5, of methode agent) en
   de tabellen vergelijken.

## Uitslagen

### Reeks A: agent, Opus 5.5 (20-10-2026 08:33 tot 09:00)

| # | Vraag | Diepte | Duur | Bronnen | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | burgemeester Nielen | snel | 1:24 | 12 | 242k / 6,0k | $0,21 | ambtsperiode 1945-1977, geboren 1912 Wormerveer; twee afwijkende inwonertallen uit bronnen benoemd |
| 2 | Kapper Bekker | snel | 1:14 | 16 | 262k / 6,7k | $0,23 | 1911 Frans Bekker, Rendorpplein, eeuwfeest 2011 |
| 3 | zeelaan | snel | 1:21 | 29 | 339k / 7,7k | $0,27 | oude en nieuwe Zeelaan, brand 1972; losse term goed opgepakt |
| 4 | oudste luchtfoto | snel | 1:21 | 14 | 261k / 6,0k | $0,21 | kiest Rijksstraatweg 1928 (vrijdag koos dezelfde methode Fort Veldhuis 1922): herhaalbaarheid |
| 5 | touwslagerij Van Oosten | doorzoeken | 2:17 | 22 | 638k / 11,7k | $0,47 | verhuizing Oosterweg naar Maerten van Heemskerckstraat gevonden |
| 6 | Bachstraat | uitgebreid | 4:23 | 79 | 1,46M / 24,2k | $1,03 | Componistenbuurt, Hoge Werfje, EGKS-flats, 13 foto's |
| 7 | Oostrum | uitgebreid | 6:03 | 58 | 2,42M / 33,6k | $1,58 | familie, pastorie, scholen, 20 foto's, voetnoten per feit |
| 8 | Los Tamaros | uitgebreid | 0:51 | 0 | 191k / 3,9k | $0,15 | "niets gevonden", zoekvarianten verantwoord, niets verzonnen |
| | **totaal** | | **18:54** | | **5,8M / 100k** | **$4,15** | alles geslaagd, geen limietpauzes |

### Reeks B: agent, Sonnet 5.5 (20-10-2026 09:02 tot 09:12)

| # | Vraag | Diepte | Duur | Bronnen | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | burgemeester Nielen | snel | 0:50 | 13 | 127k / 3,8k | $0,06 | korter dan Opus, maar met het overlijden in Canada (1977) dat Opus miste |
| 2 | Kapper Bekker | snel | 0:42 | 12 | 75k / 3,5k | $0,05 | "vanuit Zuid-Holland" i.p.v. Zuid-Scharwoude: kleine onnauwkeurigheid |
| 3 | zeelaan | snel | 0:51 | 14 | 117k / 4,2k | $0,06 | beoordeelde 100 van 170 treffers; brand 1972 uitgebreid, bewoners oude laantje dunner |
| 4 | oudste luchtfoto | snel | 0:55 | 5 | 111k / 2,2k | $0,04 | zwak: alleen objectencollectie (1977), beeldbankfoto's 1922/1928/1930 gemist |
| 5 | touwslagerij Van Oosten | doorzoeken | 0:46 | 12 | 125k / 4,0k | $0,06 | verhuizing gevonden; feitelijk één ronde |
| 6 | Bachstraat | uitgebreid | 1:36 | 21 | 230k / 7,8k | $0,12 | winkeliers en Marquettelaan; veel minder bewoners dan Opus |
| 7 | Oostrum | uitgebreid | 2:59 | 23 | 559k / 16,5k | $0,26 | familie en Kerklaan, voetnoten; 9 foto's |
| 8 | Los Tamaros | uitgebreid | 0:44 | 0 | 129k / 2,4k | $0,05 | "niets gevonden", varianten verantwoord |
| | **totaal** | | **9:23** | | **1,47M / 44k** | **$0,70** | alles geslaagd; half zo snel en een zesde van de kosten van Opus, maar minder bronnen en bij vraag 4 een misser |

### Reeks C: agent, Haiku 4.5 (20-10-2026 09:19 tot 09:43)

| # | Vraag | Diepte | Duur | Bronnen | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | burgemeester Nielen | snel | 1:07 | 1 | 199k / 3,8k | $0,04 | feiten kloppen, maar alles op één bron en zonder foto; typefouten |
| 2 | Kapper Bekker | snel | 1:41 | 4 | 531k / 5,9k | $0,08 | feitelijk rijk (1920 panden van Barend Nijman), weinig bronnen |
| 3 | zeelaan | snel | 1:36 | 7 | 457k / 6,7k | $0,08 | alleen de straat in 1961; oude Zeelaan en brand 1972 ontbreken |
| 4 | oudste luchtfoto | snel | 2:22 | 5 | 982k / 9,6k | $0,14 | Fort Veldhuis 1922, zoals de referentie; bijna 1M invoertokens |
| 5 | touwslagerij Van Oosten | doorzoeken | 1:47 | 8 | 269k / 8,4k | $0,07 | verhuizing gevonden; opent met algemene zin over touw |
| 6 | Bachstraat | uitgebreid | 4:32 | 12 | 2,03M / 13,7k | $0,27 | vlot verhaal, weinig bronnen, interpretaties niet uit bronnen |
| 7 | Oostrum | uitgebreid | 9:16 | 22 | 1,55M / 25,7k | $0,28 | langzaamste van alle modellen; spelfouten |
| 8 | Los Tamaros | uitgebreid | 5:17 | 0 | 2,02M / 21,1k | $0,30 | "niets gevonden" na 5 minuten en 2M tokens zoeken |
| | **totaal** | | **27:38** | | **8,0M / 95k** | **$1,26** | alles geslaagd; langzaamst van de drie, meeste tokens, minste bronnen |

### Reeks D: agent, Haiku 5.5 (20-10-2026 10:03 tot 10:22)

Haiku 5.5 is op 20-10-2026 aan de worker toegevoegd (`claude-haiku-5-5`); prijzen in de runtime
op het tarief tot 100K tokens per prompt ($0,10 in, $0,50 uit, $0,01 cache-lezen, $0,125
cache-schrijven), dus de kosten zijn een ondergrens. De nieuwe tokenizer telt ca. 30% meer tokens
dan Haiku 4.5 voor dezelfde tekst.

| # | Vraag | Diepte | Duur | Bronnen | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | burgemeester Nielen | snel | 1:40 | 8 | 326k / 14,3k | $0,01 | klopt met de referentie; bron Heemskring 64 (Diemont) |
| 2 | Kapper Bekker | snel | 1:40 | 15 | 389k / 12,5k | $0,01 | benoemt OCR-fout "Zuid-voude" i.p.v. te raden; bronnen op Opus-niveau |
| 3 | zeelaan | snel | 1:58 | 17 | 613k / 17,3k | $0,02 | brand 1972 en oude straatje; alle 170 treffers nagelopen |
| 4 | oudste luchtfoto | snel | 1:03 | 7 | 236k / 8,8k | $0,01 | zelfde misser als Sonnet (object 1977); stelt zelf de juiste rubriek als vervolg voor |
| 5 | touwslagerij Van Oosten | doorzoeken | 2:49 | 16 | 898k / 21,4k | $0,02 | verhuizing gevonden; meerdere rondes |
| 6 | Bachstraat | uitgebreid | 4:29 | 34 | 1,42M / 43,2k | $0,05 | samenvatting vooraf, winkeliers en Hoge Werfje; tussen Sonnet en Opus |
| 7 | Oostrum | uitgebreid | 4:56 | 42 | 1,76M / 38,3k | $0,05 | vier rondes, voetnoten, 11 foto's; dicht bij Opus (58) |
| 8 | Los Tamaros | uitgebreid | 1:01 | 0 | 291k / 6,2k | $0,01 | "niets gevonden" na drie rondes, varianten verantwoord |
| | **totaal** | | **19:36** | | **5,9M / 162k** | **$0,18** | alles geslaagd; bronnen tussen Sonnet en Opus, kosten een twintigste van Opus (ondergrens) |

### Vergelijking baselines (agent)

| | Opus 5.5 | Sonnet 5.5 | Haiku 4.5 | Haiku 5.5 |
| --- | --- | --- | --- | --- |
| Totale duur | 18:54 | 9:23 | 27:38 | 19:36 |
| Bronnen (som) | 230 | 100 | 59 | 139 |
| Tokens in / uit | 5,8M / 100k | 1,5M / 44k | 8,0M / 95k | 5,9M / 162k |
| Kosten | $4,15 | $0,70 | $1,26 | $0,18 (ondergrens) |
| Missers | luchtfoto wisselt per run | luchtfoto (1977) | Zeelaan dun, weinig bronnen | luchtfoto (1977) |

### Reeks E: pijplijn, Haiku 5.5 voor onderzoek en schrijven (20-10-2026 10:30 tot 11:38)

| # | Vraag | Diepte | Duur | Rondes | Bronnen gebruikt | Tokens in/uit | Kosten | Opmerking |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | burgemeester Nielen | snel | 1:55 | 0 | 24 van 25 | 184k / 16,4k | $0,02 | zwak: biografie (Heemskring 64) niet bij de 25 kaarten; rangschikking "snel" |
| 2 | Kapper Bekker | snel | 1:31 | 0 | 20 van 25 | 189k / 10,0k | $0,01 | zelfde: familieartikel (Heemskring 45) niet bij de kaarten |
| 3 | zeelaan | snel | 2:35 | 0 | 25 van 25 | 135k / 27,7k | $0,02 | goed: oude en nieuwe Zeelaan, brand 1972 |
| 4 | oudste luchtfoto | snel | 0:59 | 0 | 6 | 68k / 8,1k | $0,01 | misser: 1955; "snel" sorteert niet op jaar |
| 5 | touwslagerij Van Oosten | doorzoeken | 4:01 | 2 | 19 | 213k / 34,1k | $0,03 | goed, dicht bij Opus-agent (22) |
| 6 | Bachstraat | uitgebreid | 42:49 | 12 | 118 van 226 | 3,03M / 422k | $0,34 | runaway: beoordelaar keurt bijna alles goed, zegt nooit "genoeg"; 37.600 tekens |
| 7 | Oostrum | uitgebreid | 13:58 | 4 | 59 van 78 | 761k / 134k | $0,11 | rijkste Oostrum-antwoord (59 bronnen), maar te traag: 2 min per ronde, 6,7 min schrijven |
| 8 | Los Tamaros | uitgebreid | 0:32 | 0 | 0 | 119k / 2,2k | $0,004 | "niets gevonden"; geen kandidaten, dus direct schrijven |
| | **totaal** | | **68:20** | | | **4,5M / 655k** | **$0,54** | goedkoop en bij rondes inhoudelijk sterk; onbruikbaar traag bij uitgebreid, zwak bij snel |

Bevindingen voor de pijplijn (los van het model):
- **Snel** stuurt de 25 best scorende kaarten zonder beoordeling naar de schrijver; foto's verdringen het ene artikel dat ertoe doet (Nielen, Bekker) en "de oudste" vraagt om sorteren op jaar (luchtfoto). Artikelen met documenttekst en titeltreffers moeten zwaarder wegen, of snel krijgt één lichte beoordelingsstap.
- **Uitgebreid** heeft een plafond op gekozen bronnen nodig (ca. 60) en een stopregel op afnemende opbrengst (bijvoorbeeld twee rondes samen minder dan vijf nieuwe); de beoordelingsprompt moet strenger kiezen. Haiku 5.5 markeerde 226 van 480 kandidaten als relevant.
- **Haiku 5.5** is per stap traag (ca. 2 min per beoordelingsronde van 40 kaarten, Sonnet 10 tot 47 s), maar schrijft rijk en goedkoop.

### Volgende reeksen

| # | Datum | Methode | Modellen | Duur | Rondes | Bronnen | Tokens in/uit | Kosten | Oordeel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | |
