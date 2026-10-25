# HKH AI-zoekvragen — versie 1

Deze set bevat **1.000 vragen** om AI-zoeken met uiteenlopende collectieonderwerpen te testen. Samengesteld op 25 oktober 2026, op basis van een alleen-lezen selectie uit `hkh_prod` en de stijl van 77 verschillende bewaarde AI-vraagteksten. Er zijn geen zoekonderzoeken of betaalde AI-runs gestart bij het maken van deze bestanden.

## Bestanden

- [vragen.md](vragen.md): genummerde lijst om door te lezen.
- [vragen.txt](vragen.txt): één vraag per regel, zonder nummering of metadata.
- [vragen.json](vragen.json): dezelfde vragen en volgorde, met vaste ID's, categorie, geadviseerde diepte, onderwerp en één bronobject als vertrekpunt.
- [controle.json](controle.json): aantallen, controles en SHA-256 van de vragenbestanden.

De JSON kan rechtstreeks in HKH-admin bij **Capaciteitstests** worden geïmporteerd. De import ondersteunt de leesbare diepten `snel`, `doorzoeken` en `uitgebreid`. Met **1.000 HKH-vragen importeren** wordt dezelfde vastgezette versie geladen; dit start geen AI-jobs.

## Samenstelling

De onderwerpen komen uit daadwerkelijk aanwezige objecten met een niet-lege feitensamenvatting zonder geregistreerde extractiefout. Personen, straten, adressen, organisaties en gebeurtenissen zijn geselecteerd uit trefwoorden die ook in de bijbehorende samenvatting voorkomen. Daarnaast zijn collectiestukken en historische artikelen als ingang gebruikt. De onderwerpen zijn verwerkt in vraagvormen die aansluiten op de eerdere vragen: een losse naam, een korte informatievraag, onderzoek naar bewoners of relaties, foto's zoeken en een uitgebreider verhaal met bronnen.

Elke vraag heeft een ander bronobject als vertrekpunt. De selectie verwijdert gelijke onderwerpen, veel gelijkende namen en spellingvarianten, veelgebruikte onderwerpen uit eerdere vragen en samenvattingen met sterke woordoverlap. Het is een automatische selectie met een handmatig bekeken steekproef; geen volledige controle van alle historische feiten of alle mogelijke naamvarianten.

De bronverwijzing in `seed_source` is **geen verwacht volledig zoekresultaat of gecontroleerd antwoord**. Zij maakt de aanleiding van de vraag controleerbaar. Geef alleen `question` aan de zoekfunctie; bron-ID's en onderwerpmetadata zouden het onderzoek sturen. Vragen naar foto's, familieverbanden, jaartallen of aanvullende bronnen kunnen terecht weinig opleveren, ook als het onderwerp zelf voorkomt. De AI-samenvattingen zijn geen onafhankelijk geverifieerde feiten.

Deze set kiest bewust voor vragen met een vindbaar brononderwerp. Er zijn geen kunstmatig verzonnen onderwerpen zonder treffers toegevoegd: die kunnen juist minder AI-werk veroorzaken en passen minder goed bij deze capaciteitsproef. De verdeling is een testprofiel en geen gemeten verdeling van bezoekersgebruik.

## Verdeling

| Categorie | Vragen |
|---|---:|
| adressen | 70 |
| gebeurtenissen | 20 |
| historische themas | 200 |
| organisaties en gebouwen | 200 |
| personen | 310 |
| straten | 100 |
| voorwerpen | 100 |

Diepte: 477 doorzoeken, 332 snel, 191 uitgebreid.

## Gebruik en caching

Start iedere vraag als een **nieuw onderzoek in een nieuwe sessie**. Laat geen eerder antwoord of gespreksgeschiedenis meegaan. Gebruik voor vergelijkingen dezelfde volgorde en vaste instellingen. De lijst is deterministisch gemengd, zodat categorieën door elkaar staan. Loop hem eerst één keer door, zonder herhaling.

Verschillende vraagteksten en bronobjecten beperken inhoudelijke herhaling, maar garanderen geen lage cachehitratio. De zoekfunctie kan voor twee vragen dezelfde aanvullende bronnen ophalen. Ook vaste instructies, tooldefinities en de herhaalde geschiedenis binnen één onderzoek kunnen uit cache komen. Deze lijst gebruikt geen willekeurige toevoegingen om caching kunstmatig te verstoren.

Meet daarom de werkelijk geselecteerde bron-ID's en de beschikbare cache-read-, cache-write-, input- en outputtokens per uitvoering. Vergelijk de eerste doorgang afzonderlijk van eventuele herhalingen. Stuur de metadata en deze README niet mee als onderdeel van iedere vraag.

De bestanden verlenen geen productie-login of opdracht om een campagne te starten. De afgesproken uitvoering van automatische tests en duurtests staat in het [voorstel voor capaciteitstests](../ideas/ai-onderzoek-capaciteitstests.md).

## Herkomst en reproduceerbaarheid

De inhoud is gebaseerd op de collectietoestand op de samensteldatum, zonder volledige database-snapshot. Bronobjecten kunnen later veranderen. Versie 1 is de vastgelegde lijst in deze map; wijzig bij een volgende campagne de lijst niet tussendoor. Een nieuwe lijst krijgt een nieuwe versie en eigen checksums.

Er zijn geen bezoekersidentiteiten, IP-adressen, e-mailadressen, antwoorden uit persoonlijke zoeksessies of databasecredentials opgenomen. Namen in vragen zijn collectieonderwerpen, geen identificatie van de vragenstellers.
