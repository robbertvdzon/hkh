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

| # | Datum | Model | Diepte | Duur | Opmerking |
| --- | --- | --- | --- | --- | --- |
| 1 | 16-10-2026 08:54 | Opus 5.5 | snel | 1 min 15 s | "Henk Nielen (1912-1977), ruim dertig jaar burgemeester van Heemskerk" |
| 2 | 16-10-2026 11:47 | Opus 5.5 | snel | 1 min 56 s | "Kapper Bekker in Heemskerk: honderd jaar familiebedrijf aan de Deutzstraat" |
| 3 | 16-10-2026 18:45 | Opus 5.5 | snel | | "De Zeelaan in Heemskerk: van tuinderslaantje tot straat in Kerkbeek" |
| 4 | 17-10-2026 08:13 | Opus 5.5 | snel | 1 min 37 s | "De oudste luchtfoto van Heemskerk in de HKH-collectie: Fort Veldhuis, 1922" |
| 5 | 03-10-2026 22:35 | Opus 5 | doorzoeken | | "Touwslagerij Van Oosten: van de Oosterweg naar de Maerten van Heemskerckstraat" |
| 6 | 03-10-2026 21:24 | Opus 5 | uitgebreid | | "De Bachstraat in Heemskerk: van het Hoge Werfje tot de Heemsuite, en de mensen die er woonden" |
| 7 | 01-10-2026 10:34 (Opus 5, 8:01, 61 bronnen) en 17-10-2026 (Opus 5.5, 5:32, 54 bronnen) | | uitgebreid | | pijplijn op 18-10: 4:00 (26 bronnen, afgekapte invoer) en 9:35 (45 bronnen, met wachttijd) |
| 8 | 18-10-2026 20:04 (pijplijn) | Sonnet 5.5 / Opus 5.5 | uitgebreid | | "Los Tamaros: niets gevonden in de collectie"; nog geen agent-referentie |

De duur en tokens per beurt staan in de vergelijkingstabel in het beheerscherm; die zijn
automatisch. Kwaliteit is een leesoordeel: volledigheid (staan de kernfeiten uit de referentie
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

| # | Datum | Methode | Modellen | Duur | Rondes | Bronnen | Tokens in/uit | Oordeel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | |
