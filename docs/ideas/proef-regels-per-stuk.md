# Proef: regels per stuk als basis voor korte antwoorden en artikelen

27 november 2026. Proef bij het idee om per record met lange tekst één lijst "regels" te maken
(elke regel een bewering uit de tekst, met soort en periode), waarop je over alle stukken heen kunt
zoeken (kort antwoord) en die achter elkaar gelezen de verkorte versie van het stuk vormen
(artikel).

## Uitkomst in het kort

1. **Regels zijn nauwelijks korter dan de tekst.** Gemiddeld 81% van de lengte. De tokenwinst bij
   het schrijven van een artikel is er dus niet.
2. **Korter maken kost gegevens.** Een compacte variant kwam op 54% (doel was een derde) en liet
   details vallen. Haiku kwam op 67% en liet dezelfde details vallen.
3. **Een artikel uit de regels is bijna even goed** als een uit de volledige tekst, maar niet
   goedkoper. Voor het artikel blijft de volledige tekst de bron.
4. **Het korte antwoord werkt.** Uit de gevonden regels komt een bruikbaar antwoord met 15 tot 23%
   van de invoer die de volledige tekst vraagt.
5. **Fragmenten van de ruwe tekst geven ook een bruikbaar kort antwoord, zonder dat er iets voor
   gemaakt hoeft te worden**, maar slechter op jaartallen en namen dan de regels.
6. **Het zoeken bepaalt meer dan de vorm.** Twee van de drie zoekpogingen misten eerst het
   belangrijkste stuk of de juiste regel, door de rangschikking en niet door de regels.

## Opzet

- **Stukken:** 38 records met lange tekst, samen 518.060 tekens: 17 artikelen van de kring, 11
  krantenartikelen (archief) en 10 transcripties van aktes (16e tot 18e eeuw). Gekozen via de
  publieke zoek-API rond Nielen, Kapper Bekker, de touwslagerij en de Zeelaan.
- **Regels:** gemaakt door Sonnet in zes groepen; één groep van zes stukken ook door Haiku en in
  een compacte variant (telegramstijl, doel een derde van de lengte).
- **Vragen:** "wie was burgemeester nielen?" en "Wat kun je vertellen over Kapper Bekker?" (testset
  1 en 2) en een detailvraag over de heropening van paviljoen 3 van het St. Jozefziekenhuis, een
  gegeven dat op teken 24.700 van een artikel van 28.000 tekens staat.
- **Beantwoord door** Sonnet, elke variant in een eigen aanroep zonder de andere te zien.

### Wat de proef niet meet

- **Geen tijd en kosten.** De aanroepen liepen als subagents in een Claude-sessie, niet via de
  agent-runtime. Alleen de invoergrootte in tekens is hard.
- **Niet de echte zoekfunctie.** Er is gezocht met een eenvoudig script (termen uit de vraag,
  tolerant op woorden), niet met `KeywordSearchService`.
- **Geen vergelijking met de huidige pijplijn.** Die is niet opnieuw gedraaid; de controle is het
  antwoord uit de volledige tekst van dezelfde stukken.
- **Drie vragen, elk één keer**, beoordeeld door Claude. Het is een aanwijzing, geen meting.

## 1. Lengte van de regels

| Soort stuk | Stukken | Tekst (tekens) | Regels | Tekst van de regels | Verhouding |
| --- | --- | --- | --- | --- | --- |
| artikelen | 17 | 409.405 | 2.032 | 329.050 | 0,80 |
| archief (krant) | 11 | 78.160 | 398 | 64.831 | 0,83 |
| transcripties | 10 | 30.495 | 173 | 25.467 | 0,84 |
| **alle** | **38** | **518.060** | **2.603** | **419.348** | **0,81** |

Een regel is gemiddeld 161 tekens. Per stuk loopt de verhouding van 0,66 tot 1,14; lange stukken
zijn niet beter samen te drukken dan korte. De opdracht "elke bewering een regel, namen voluit"
levert in de praktijk de tekst op in andere zinnen.

### Drie varianten op dezelfde zes stukken

| Variant | Verhouding | Gem. regel | Nielen-biografie: 12 controlepunten |
| --- | --- | --- | --- |
| Sonnet, volledig | 0,89 | 168 tekens | alle 12 aanwezig |
| Haiku, volledig | 0,67 | 118 tekens | 10; dr. Vidra en Baardemans ontbreken |
| Sonnet, compact | 0,54 | 313 tekens | 10; dr. Vidra en Baardemans ontbreken |

De controlepunten zijn gegevens verspreid over de tekst (geboorteplaats, sterfplaats, inwonertal
1960, de heropening van paviljoen 3). Wat bij inkorten als eerste verdwijnt is een fotobijschrift
diep in de tekst: precies het soort detail waarvoor de regels bedoeld waren.

## 2. Kort antwoord

Invoer in tekens per variant:

| Vraag | Gevonden regels | Ruwe fragmenten | Volledige tekst (controle) |
| --- | --- | --- | --- |
| Nielen | 19.179 | 17.215 | 85.176 |
| Kapper Bekker | 12.547 | 8.376 | 81.869 |
| Paviljoen 3 | 5.776 | 1.201 | (28.000 voor het ene artikel) |

Oordeel per antwoord:

| Vraag | Uit gevonden regels | Uit ruwe fragmenten | Uit volledige tekst |
| --- | --- | --- | --- |
| Nielen | Ambtsperiode 1945-1977, sterfdatum en -plaats, vier momenten uit zijn ambt. **Mist** geboortedatum en -plaats en de benoeming. | Benoeming op 21 december 1945 en voorganger Scholtens. **Mist** het eindjaar en het sterfjaar ("overleed op 25 augustus", zonder jaar). | Volledig: geboorte, Castricum, benoeming, ambtsperiode, begrafenis. |
| Kapper Bekker | Begin 1911, Henk Bekker, Nic Kater, bibliotheek 1942-1951, 1968, 1998. **Mist** inschrijving 1916, aankoop 1920, staatsloten. | Begin 1911, aankoop 1920, Kater, honderd jaar. **Mist** 1942 en de verhuizing van 1968; schrijft "Henk (1987) en Chris (1992)" over, wat als geboortejaar leest. | Volledig, inclusief 1916, 1920, 1982, 2000. |
| Paviljoen 3 | Het antwoord staat in de eerste regel, met jaar (1973) en de drie aanwezigen. | Het antwoord staat in het fragment, met jaar en namen. | n.v.t. |

Wat dit laat zien:

- **De regels zijn beter dan ruwe fragmenten op tijd en namen.** Het jaar staat in de regel zelf
  ("overleed op 25 augustus 1977"), omdat het bij het maken is opgezocht in de rest van het stuk.
  In een los fragment ontbreekt het.
- **Een vraag naar een onderwerp is geen vraag naar een regel.** Bij "wie was Nielen" raakt 280
  van de 2.603 regels de zoekterm. Uit de biografie gingen 15 van de 150 regels mee, gelijk
  verspreid, en de geboorteregel zat daar niet bij. Als een stuk in zijn titel over het onderwerp
  gaat, moet het in zijn geheel mee.
- **De detailvraag is het sterkste geval.** Het gegeven staat voorbij de 7.000 tekens die de
  huidige kaarten lezen. Zoeken op regels of fragmenten vindt het met een paar duizend tekens
  invoer.

## 3. Artikel over Kapper Bekker

Beide uit dezelfde vier stukken: 73.281 tekens aan regels tegenover 81.869 tekens volledige tekst.

- **Uit de regels (839 woorden):** leest als een gewoon artikel, met citaten, jaartallen en
  bronverwijzingen. De omzetting van relatieve tijd werkt: "twee jaar geleden" in het artikel van
  2011 is "2009" geworden.
- **Uit de volledige tekst (811 woorden):** iets rijker (overlijden Marie van Lieshout in 1964,
  slijterij De Berkelaer, 75-jarig bestaan in 1986) en met de clou van een anekdote die in de
  regels is weggevallen: de "knecht" die Bekker al had, was zijn pasgeboren zoon.
- **Beide** merken dezelfde tegenstrijdigheid in de bron op (1911 tot 1968 op de hoek van de
  Kerklaan, terwijl de panden daar pas in 1920 zijn gekocht).

Het artikel uit de regels is dus goed genoeg, maar de invoer is maar 10% kleiner. Er is geen reden
om het artikel uit de regels te schrijven.

## 4. De zes soorten en de periode

| Soort | Regels | Aandeel |
| --- | --- | --- |
| toestand | 1.108 | 43% |
| gebeurtenis | 825 | 32% |
| uitspraak | 386 | 15% |
| citaat | 114 | 4% |
| duiding | 111 | 4% |
| verwachting of plan | 59 | 2% |

- **De soorten passen op alle drie de soorten stukken**, ook op aktes: partijen, percelen en
  bedragen werden toestand of gebeurtenis.
- **"Toestand" is de vergaarbak.** De modellen meldden dat ze het kozen voor eigenschappen zonder
  duidelijk moment.
- **Uitspraak en duiding lopen door elkaar** in artikelen die zelf uit oudere stukken citeren.
- **De periode is vaak geschat.** Bij interviews en levensverhalen zonder jaartallen gaven de
  modellen een ruime spreiding of 0.
- **40 regels kregen `[onzeker]`**, vooral bij slechte OCR van krantenkolommen. Haiku zette die
  markering bijna nooit (1 keer op 488 regels).

## 5. Wat het zou kosten

De zes Sonnet-groepen gebruikten samen ongeveer 930.000 tokens (invoer en uitvoer, inclusief het
werk van de agent eromheen) voor 518.060 tekens tekst, en elk ongeveer vijf minuten.

De collectie heeft 523 artikelen, 1.763 archiefstukken en 5.187 transcripties. Hoeveel tekst dat
samen is, is niet geteld. Met de medianen uit oktober (artikel 10.700, archief 2.600, transcriptie
1.900 tekens) is het in de orde van 20 miljoen tekens, dus ruwweg veertig keer deze proef. Dat is
een schatting op medianen; lange uitschieters (één transcriptie is 300.000 tekens) maken het meer.

## Advies

1. **Bouw het korte antwoord als standaard**, met het artikel als bewuste vervolgstap. De proef
   bevestigt dat een antwoord uit een paar duizend tot twintigduizend tekens bruikbaar is.
2. **Schrijf het artikel uit de volledige tekst**, zoals nu. De regels besparen daar niets.
3. **Begin het korte antwoord op wat er al is:** de kaarten plus fragmenten van de ruwe tekst rond
   de treffers, zonder nieuwe run over de collectie. Twee regels erbij:
   - gaat een stuk in zijn titel over het onderwerp, dan gaat het in zijn geheel mee;
   - het model krijgt de datum van het stuk bij elk fragment en moet zeggen wanneer een jaar
     ontbreekt.
4. **Maak regels eerst alleen voor de 523 artikelen van de kring.** Daar zitten de lange teksten,
   de door elkaar lopende kolommen en de bijschriften, en daar hielpen de regels het meest. Meet
   dan op de testset of het korte antwoord er beter van wordt dan met fragmenten.
5. **Los het afkappen van de kaarten op 7.000 tekens apart op.** Dat raakt het vinden van stukken,
   los van deze keuze.
6. **Gebruik Sonnet voor de regels, niet Haiku**, als ze gemaakt worden: Haiku is korter doordat
   het gegevens weglaat.

## Materiaal

De stukken, regels, zoekresultaten en antwoorden van de proef staan in de scratchmap van de sessie
en zijn niet in de repository gezet. De scripts (`fetch.py`, `zoek.py`, `pak.py`, `passages.py`,
`lengte.py`) en de opdrachtteksten staan daar ook.
