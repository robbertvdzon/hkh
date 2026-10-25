# Capaciteitstests in HKH-admin

HKH-admin heeft **Capaciteitstests** op `/ai-capaciteit`. De routes onder
`/api/admin/ai-search/capacity` gebruiken dezelfde adminauthenticatie als de andere beheerschermen.
De publieke zoek-API krijgt geen modelkeuze.

## Gebruik

1. Importeer **1.000 HKH-vragen** of een eigen lijst. Importeren start geen AI-jobs.
   Iedere import is een onveranderlijke versie met SHA-256. Een eigen import accepteert één vraag
   per regel of JSON-objecten met `question`, `depth` en `category`. De bestaande
   [vragen.json](testvragen/vragen.json) wordt rechtstreeks ondersteund, inclusief Nederlandse diepten.
2. Kies **Nieuwe campagne**, de vragenlijst en provider/model/uitvoering uit de runtimecatalogus.
   Offline modellen kunnen wachten op een worker. De actuele onderzoeksmethode en het
   schrijfbudget worden vastgezet; alle AI-fasen gebruiken het campagnemodel.
3. Kies 1–50 gelijktijdige **scenario's**, maximumaantal, eindtijd, accountalias en collectieversie.
   Optioneel: volledig uitwerken wanneer de pijplijn dat aanbiedt, en één vaste vervolgvraag.
   De vervolgbeurt gebruikt het nieuwe antwoord en dezelfde modelkeuze. Een scenario telt pas
   als geslaagd wanneer alle gevraagde beurten geslaagd zijn.
4. Controleer de samenvatting en start bewust. De campagne verandert geen globale modelinstellingen.
   Begin bijvoorbeeld bij één parallel scenario; hogere aantallen garanderen geen gelijke snelheid.
5. Open een campagne voor scenario's, fasen, runtimejob-ID's, attempts, bronselecties, verbruik,
   limietwaarnemingen en tijdlijn. JSON/CSV-export is beschikbaar als kopieerbare tekst.

Per provider kan één campagne actief zijn, ook bij verschillende modellen/accountaliassen en
wachten op een providerreset. PostgreSQL dwingt dit af met een unieke partiële index.
Verschillende providers kunnen tegelijk testen. Pauzeren laat reeds gestarte scenario's aflopen;
bij een providerblokkade blijft onvoltooid werk bewaard. Pas na het aflopen van jobs komt de provider
vrij. Hervatten verwerft die provider opnieuw en respecteert een nog toekomstige reset.
Stoppen annuleert actieve runtimejobs; de provider blijft bezet totdat hun status terminaal is.

Vragen herhalen staat standaard uit. Iedere eerste vraag heeft een nieuw gesprek en een unieke
runtime-idempotentiesleutel. Als de lijst op is, eindigt de campagne met **Vragenlijst uitgeput;
limiet niet bereikt**. Bij expliciete herhaling toont het rapport de eerste doorgang afzonderlijk.
Providercaching blijft actief zoals bij normaal gebruik; er worden geen willekeurige cachebrekers
of historische antwoorden toegevoegd.

## Limieten en tellingen

De scheduler leest gestructureerde runtime-events, ook als een runtimejob zelf retries uitvoert.
Het bewaart de oorspronkelijke waarneming, attempt-ID, tellerstand en latere scenario-uitkomsten.
Een onbekende grens blijft **UNKNOWN**. Een timeout of schemafout wordt niet als abonnementsgrens
geclassificeerd; runtimefoutcodes en workerwachttijd blijven zichtbaar bij de fase.

- **SHORT_WINDOW / UNKNOWN:** geen nieuwe fasen/scenario's tot reset/retryadvies. Zonder advies:
  begrensde exponentiële probe-intervallen met spreiding. Mislukte fasen krijgen een expliciete
  nieuwe jobgeneratie; geslaagde fasen worden hergebruikt. Attempts en jobs tellen afzonderlijk.
- **WEEK / MONTH:** dispatch stopt, actieve jobs worden beëindigd en de eindmeting blijft bewaard.
- **Aantallimiet, eindtijd of vragenlijst:** geen aangetoonde abonnementsgrens.

De optionele USD-begroting gebruikt bekende runtimekosten, met dezelfde API-equivalente betekenis
als de runtime. Ontbrekende prijzen zijn onbekend; gelijktijdige jobs kunnen een begroting
overschrijden voordat nieuw verbruik is gemeld. Dit is geen harde betalings- of quotabegrenzing.
De ruwe metrieken en verbruiksdefinities blijven behouden, ook van mislukte jobs en attempts.
Ontbrekende cachecijfers worden niet als nul gepresenteerd. Er wordt geen cachepercentage
berekend op een veronderstelde tokennoemer.

Beginquota, ander accountgebruik en een onveranderde collectiesnapshot zijn niet automatisch
bewezen. De accountalias en collectieversie zijn administratieve metadata. Een meting laat zien
hoeveel werk onder deze omstandigheden lukte; geen gegarandeerde capaciteit van een vol abonnement.
Het rapport toont doorvoer en mediaan/p95 van geslaagde scenario's; exports bevatten tijdstippen
en de oorspronkelijke runtime-attempts voor verdere analyse.

## Herstel en opslag

Flyway V30 voegt datasets, campagnes, scenario's, fasegeneraties, checkpoints, limietwaarnemingen
en de tijdlijn toe. De campagnescheduler claimt iedere campagne met een databaselease van
90 seconden, onafhankelijk van de langlopende HTTP-polls. `hkh.capacity.poll-ms` is standaard 2000.
Alleen scenario's binnen het ingestelde parallelisme worden vooruit gepland.

Vóór dispatch worden de fase-instructie, het schema, bijlagen en de exacte runtime-requestbody
opgeslagen. Daardoor gebruikt herstel na een verloren create-response ook dezelfde geüploade
object-ID's. De runtime-idempotentiesleutel voorkomt dubbele jobcreatie. Bronnen, zoekresultaten,
selectie en faseoutputs worden eveneens bewaard; een voltooide fase wordt niet nogmaals uitgevoerd.
Een backendherstart hervat bestaande campagnebeurten. Gewone bezoekersbeurten behouden hun
bestaande gedrag. Testgesprekken hebben een afzonderlijke eigenaar, geen dossier en geen
requestlogregels voor bezoekersstatistieken. Er worden geen notificaties gepubliceerd.

De beheermogelijkheid bestaat los van het starten van een duurtest. Gebruik een afgeschermde
preview/test/acceptatie met een afgesproken collectiekopie en eigen providerconfiguratie.
Agentjobs krijgen geen productie-logincredentials. Het instellen van de publieke origin bepaalt
ook de collectie-API die de agentmethode gebruikt.

## Verificatie

`AiCapacityIntegrationTest` gebruikt echte PostgreSQL-opslag en een lokale HTTP-nepruntime.
Het controleert volledige agent-/pijplijnscenario's, modeldoorgifte, vervolgen/uitwerken,
providervergrendeling bij gelijktijdig starten, onafhankelijke providers, limietherstel,
week-/maandgrenzen, onbekende limieten, schemafouten, workerwachtrijen, pauzeren, annuleren,
idempotente heraanbieding, opgeslagen checkpoints en import van de 1.000 vragen.
De frontendtests controleren de route, dat laden/importeren geen campagne start en dat een
bezette provider wordt geblokkeerd terwijl een andere provider wel kan worden gestart.

Een automatische traptest die zelf 1/2/4/8/16/32/50 parallel doorloopt en workerresources meet,
is nog geen onderdeel van dit scherm. Maak voor zulke vergelijkingen afzonderlijke campagnes
met een vaste instelling. Nieuwe vragen genereren is evenmin een verborgen onderdeel van een
campagne: gebruik de meegeleverde lijst of importeer een nieuwe versie.
