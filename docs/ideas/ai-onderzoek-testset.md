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

### Volgende reeksen

| # | Datum | Methode | Modellen | Duur | Rondes | Bronnen | Tokens in/uit | Kosten | Oordeel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | |
