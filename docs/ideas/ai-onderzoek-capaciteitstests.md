# Voorstel voor capaciteitstests van HKH zoekopdrachten

Status: ontwerp, 25 oktober 2026. De kern is geïmplementeerd; zie [gebruik, herstel en afbakening](../ai-capaciteitstests.md). Er is bij implementatie geen echte duurtest gestart.

## Doel en plaats in de applicatie

Voeg in HKH-admin een pagina **Capaciteitstests** toe. Daarmee kan Robbert per provider en
model meten hoeveel volledige HKH-zoekopdrachten slagen voordat een korte limiet of een
week- of maandgrens wordt bereikt. Campagnes voor verschillende providers kunnen tegelijk
draaien, ieder met eigen parallelisme, voortgang en bediening.

HKH beheert de vragen, zoekstappen en campagnes. Agent Runtime verzorgt de afzonderlijke
AI-jobs, uitvoeringscapaciteit, usage en limietmeldingen. De volledige HKH-pijplijn uitvoeren
maakt gevarieerde vragen mogelijk zonder vooraf iedere prompt en bronselectie te exporteren.

De twee bestaande Mistral-naspels in `agent-runtime/mistral-test` bevatten alleen een
schrijf- of uitwerkingsfase. Ze blijven bruikbaar als kleine technische proef, maar tellen
niet als volledige zoekopdrachten.

## Bestaande code en benodigde uitbreiding

De bestaande [AiBenchmarkService](../../backend/src/main/kotlin/nl/vdzon/hkh/aisearch/AiBenchmark.kt)
voert een opgeslagen vragenlijst één voor één uit. Hij gebruikt één proceslokale vlag en de
actuele globale modelinstellingen. Dat is onvoldoende voor onafhankelijke campagnes en herstel
na een herstart.

De [ResearchPipelineService](../../backend/src/main/kotlin/nl/vdzon/hkh/research/ResearchPipelineService.kt)
voert normaal twee AI-jobs uit: `direct` (richten) en `write` (schrijven). Bij geen eerste
treffers kan daar `plan` aan voorafgaan. Zonder kandidaten wordt `direct` overgeslagen.
De code doet de SQL-zoekstappen en het ophalen van bronnen. `expand` is één aparte job bij
**Volledig uitwerken**. De alternatieve agentmethode gebruikt één runtimejob voor het onderzoek.

Campagnes gebruiken dezelfde zoekroute en ingestelde onderzoeksmethode als een gewone gebruiker:
agent of pijplijn. Een scenario is een volledige eerste
zoekvraag, eventueel gevolgd door een vooraf vastgelegde uitwerking of vervolgvraag. Zo'n
vervolg krijgt de nieuw geproduceerde context; we plakken geen historische antwoorden in een
nieuwe uitvoering. De methode beïnvloedt het aantal AI-jobs en het verbruik; vergelijk campagnes
met dezelfde methode en leg die methode bij iedere uitvoering vast.

Voeg intern een optionele uitvoeringskeuze per zoekbeurt toe. Zonder override worden de gewone
modelinstellingen gebruikt. De publieke HKH-interface krijgt geen modelkeuze en de publieke API
accepteert geen testoverride. Alleen de geauthenticeerde beheertest kan provider, model en
uitvoeringswijze kiezen. Deze keuze gaat mee naar alle AI-jobs van de beurt: de AGENT-rol bij
de agentmethode en zowel ONDERZOEK als SCHRIJVEN bij de pijplijn. Ook een eventuele planjob
gebruikt deze keuze. Een vervolg of uitwerking binnen het testscenario behoudt de campagnekeuze.
Valideer de override tegen de runtimecatalogus en toegestane capabilities; een niet ondersteunde
keuze levert een expliciete fout op.

## Vragenlijst en representativiteit

Maak eenmalig een versie van een vragenlijst met bijvoorbeeld 1.000 verschillende vragen.
Generatie is een afzonderlijke beheeractie, met een eigen begrensde job en geregistreerd
verbruik. De duurtest genereert niet tussendoor nieuwe vragen. De beheerder kan vragen
importeren, aanpassen, verwijderen en als nieuwe versie vastzetten.

Genereer de lijst vanuit onderwerpen die werkelijk in de HKH-collecties voorkomen. Verdeel
vragen over personen, families, straten, gebouwen, verenigingen, gebeurtenissen en perioden.
Neem eenvoudige en brede vragen op, combinaties van bronnen, spellingvarianten en een beperkt
aandeel vragen zonder treffers. Dedupliqueer zowel identieke vragen als bijna gelijke
herformuleringen. Controleer een steekproef op plausibiliteit en onderwerpvariatie.

Unieke vraagtekst betekent niet automatisch unieke broninhoud. Bewaar daarom per uitvoering
ook het aantal en de identiteit van geselecteerde bronnen, zodat sterke overlap zichtbaar is.
Een gelijke verdeling over categorieën is een testprofiel; noem die pas representatief voor
productie wanneer de verdeling met werkelijk HKH-gebruik is vergeleken.

Iedere campagne krijgt dezelfde vastgezette lijst, volgorde en scenarioverdeling. Leg ook
de codeversie, promptversie, tekstbudgetten en collectiesnapshot of datasetversie vast. Gebruik
bij voorkeur een stabiele kopie van de collecties. Wijzigingen in de collectie tijdens een
campagne worden vermeld als beperking van de vergelijkbaarheid.

## Caching en betekenis van de uitkomsten

Iedere nieuwe eerste vraag start in een nieuwe sessie met een schone agentwerkmap. Context
wordt alleen gedeeld binnen een scenario dat expliciet een vervolg of uitwerking bevat.
Providercaching blijft werken zoals bij normale HKH-opdrachten. Kunstmatige willekeurige
tekens toevoegen om caching te breken past niet bij deze meting.

Doorloop de vragenlijst eerst zonder herhaling. Als de lijst op is, pauzeert de campagne
standaard met **Vragenlijst uitgeput**. De beheerder kan vooraf herhaling toestaan; de resultaten
tonen dan de eerste doorgang en herhalingen afzonderlijk. Duizend vragen zijn geen garantie
dat een abonnementsgrens bereikt wordt.

Registreer per AI-attempt gewone input-, cache-read-, cache-write- en outputtokens voor zover
de provider die afzonderlijk levert. Ontbrekende metingen zijn onbekend, geen nul. Bewaar de
oorspronkelijke teldefinitie; tel cached tokens niet nogmaals op als ze al in input zitten.
Toon de cacheverhouding alleen wanneer teller en noemer betrouwbaar zijn.

Ook binnen één agentjob ontstaat caching door herhaalde gespreksgeschiedenis tussen toolrondes.
Een hoog cachepercentage bewijst daarom geen hergebruik tussen verschillende zoekopdrachten.
Nieuwe vragen kunnen bovendien vaste instructies en bronnen delen.

Het effect van cached tokens op abonnementsgrenzen is per provider nog te bepalen. API-prijzen
bewijzen niet hoe abonnementsquota worden afgeschreven. Vergelijk gemeten cacheverhoudingen
met echte HKH-opdrachten voordat we uitkomsten naar normaal gebruik vertalen. Een eventuele
vergelijking tussen eerste doorgang en herhaling vereist vergelijkbare beginquota en
venstercondities; achtereenvolgens draaien op hetzelfde account is geen gecontroleerd bewijs.

## Campagnes en parallelisme

Een campagne legt bij aanmaak vast: vragenlijstversie, scenario, provider, model,
uitvoeringswijze, accountalias zonder credentials, parallelisme, maximum aantal scenario's,
eindtijd, eventuele token- of kostenbegroting en gedrag bij limieten. Neem methode en overige
zoekinstellingen bij de start over uit de gewone settings en bewaar ze als onveranderlijke
momentopname, zodat een settingswijziging een lopende vergelijking niet verandert. Zonder
modeloverride blijven de ingestelde modellen per rol behouden. Met een override gebruikt iedere
AI-job van de testbeurt het gekozen model. De effectieve instellingen worden per job vastgelegd. De campagne
wijzigt geen globale HKH-modelinstellingen.

Per provider mag maximaal één campagne tegelijk actief zijn, ook wanneer die op limietherstel
wacht. Verschillende modellen van dezelfde provider worden na elkaar getest. De backend dwingt
dit ook bij gelijktijdige startverzoeken en meerdere replica's atomair af. Een gepauzeerde campagne
geeft de provider pas vrij wanneer haar lopende jobs zijn afgerond; hervatten vereist opnieuw
een vrije provider. Campagnes voor verschillende providers mogen tegelijk draaien, ieder met
eigen instellingen en parallelisme. Deelquota over accountaliassen moeten herkenbaar zijn;
een andere alias is geen bewijs van een onafhankelijk abonnement. Leg ander gebruik van
hetzelfde account vast als mogelijke beïnvloeding van de meting.

Parallelisme telt volledige scenario's. Bij vier parallelle zoekopdrachten draaien hoogstens
vier scenario's tegelijk; de AI-stappen binnen ieder scenario blijven opeenvolgend. Een
wachtende of nog lopende job blijft bij hetzelfde scenario horen en veroorzaakt geen nieuw
scenario. De backend plant slechts begrensd vooruit, zodat er geen duizenden jobs in de
runtimewachtrij komen.

Meet eerst met 1, 2, 4, 8 en 16 scenario's tegelijk, en daarna eventueel 32 en 50. Meet op ieder
niveau doorvoer, looptijden, wachttijden, fouten en workerresources. Vijftig parallel is een
te onderzoeken capaciteit, geen garantie dat iedere opdracht even snel blijft. Bied zowel
een vast parallelisme voor reproduceerbare duurtests als een afzonderlijke capaciteitsproef
met opeenvolgende niveaus. Wijzigingen tijdens een campagne krijgen een tijdstip in het log.

## Limieten en herstel

Bewaar een limietwaarneming direct bij de betrokken attempt, vóór automatisch retrygedrag
de oorspronkelijke fout kan verbergen. Onderscheid korte rate- of vensterlimieten,
weekquota, maandquota en onbekende limieten. Bewaar providerreden, HTTP-status indien
beschikbaar, resetmoment, retryadvies, waarnemingstijd en de bron van de classificatie.
Een HTTP 429 alleen is onvoldoende om een week- of maandgrens vast te stellen.

Bij een korte limiet stopt de campagne tijdelijk met nieuwe dispatches. Bestaande jobs worden
apart gevolgd. Respecteer het resetmoment of retryadvies; zonder advies volgen begrensde
probes met oplopende wachttijd en spreiding. Hervat daarna dezelfde onvoltooide scenario's.
Retries tellen als extra attempts en verbruik, niet als extra zoekopdrachten. Een herstart
van een complete AI-fase wordt eveneens expliciet zichtbaar.

Bij een bevestigde week- of maandgrens stopt de campagne standaard met dispatchen en bewaart
ze de eindmeting. Schemafouten, sessietokenlimieten, timeouts, storingen en onvoldoende
workercapaciteit krijgen eigen categorieën. Bij onvoldoende informatie blijft het limiettype
onbekend. Geen stilzwijgende fallback naar API-betaling, een ander model of een andere provider.

Een campagne eindigt ook bij de ingestelde looptijd, begroting, aantallimiet, uitgeputte
vragenlijst of handmatig stoppen. Dat betekent **limiet niet bereikt**, geen geschatte harde
abonnementsgrens. De begintijd, beschikbare beginquota en gedeeld accountgebruik bepalen
of een uitkomst een volledig abonnement of alleen de resterende ruimte beschrijft.

## Adminscherm en rapportage

Voeg naast het bestaande vergelijkingsoverzicht een pagina Capaciteitstests toe met:

- Vragenlijsten met versie, categorieën, aantallen en generatie/import.
- Campagne aanmaken met provider/model, instellingen en een samenvatting vóór starten.
- Een kaart per campagne met status, actieve scenario's, wachttijd en laatste limietmelding.
- Pauzeren (geen nieuwe scenario's, lopende afmaken), hervatten en stoppen. Stoppen annuleert
  ook nog actieve runtimejobs; voltooiingsraces worden verwerkt zonder dubbel tellen.
- Detail met tijdlijn, limietwaarnemingen, scenario's en links naar hun runtimejobs.
- Export van campagneconfiguratie, resultaten en metingen als JSON/CSV, zonder credentials.

Toon afzonderlijk gestarte, volledig geslaagde, mislukte, onderbroken en nog actieve scenario's,
het aantal AI-jobs en attempts, tokens en bekende API-equivalente abonnementswaarde. Die
waarde is geen rekening en geen resterend quotum. Toon eerste doorgang en herhalingen apart.

Bij de eerste limiet staan de tellerstand en het aantal nog actieve scenario's op dat moment.
Rapporteer daarnaast de uiteindelijke resultaten van die actieve scenario's. Zo wordt een
parallelle meting niet ten onrechte een exact maximum van geslaagde zoekopdrachten genoemd.
Maak hetzelfde onderscheid voor iedere latere limiet en voor week- of maandquota.

Meet totale looptijd per scenario, runtimewachttijd, uitvoertijd per fase, limietwachttijd,
geslaagde scenario's per uur en mediaan/p95 van de doorlooptijd. Een campagneteller naast
providerquota maakt beïnvloeding door ander accountgebruik zichtbaar wanneer de provider
quotametingen aanbiedt. Een prognose krijgt altijd het label schatting.

## Opslag en uitvoering

Gebruik blijvende opslag voor vragenlijstversies, scenario's, campagnes, uitvoeringen,
fasekoppelingen en limietwaarnemingen. Campagne- en scenario-ID's verbinden HKH met runtimejobs.
Bewaar voldoende metadata direct tijdens uitvoering; `research_stats` pas na succesvolle
afronding opslaan is onvoldoende voor afgebroken campagnes.

Een scheduler claimt werk met een lease, ook bij meerdere backendreplica's. Een unieke
idempotency-key per campagne, scenario-uitvoering en fase voorkomt dubbele jobcreatie na
een crash. Lees na een herstart eerst de bestaande runtimejobstatus voordat werk opnieuw
wordt aangeboden. Voltooide fasen en hun outputs worden bewaard om de volgende fase te
kunnen hervatten. Wachten op een reset mag geen workercontainer bezet houden.

De huidige pijplijn kan na een backendherstart een lopende beurt niet hervatten. Alleen
een campagnetabel toevoegen lost dit niet op: de faseovergangen moeten eveneens hervatbaar
worden. Hergebruik de zoek- en promptlogica en voeg duurzame orkestratie voor campagnes toe.

Testonderzoeken worden herkenbaar opgeslagen en blijven buiten bezoekersstatistieken,
persoonlijke dossiers, notificaties en de publieke zoekgeschiedenis. De nieuwe beheerroutes
gebruiken de bestaande adminauthenticatie en servervalidatie voor aantallen en grenzen.

## Benodigde wijzigingen in Agent Runtime

De bekeken workerbron heeft al slots per jobcategorie, standaard 6 application-, 2 repository-
en 1 transcriptieslot. De configuratie begrenst een categorie momenteel op 32. Agentcontainers
hebben maxima van 8 GB en 4 CPU's; dat zijn geen reserveringen. Hogere aantallen vragen meting
van werkelijk geheugen, CPU, processen, schijf en netwerk, plus voldoende Dockercapaciteit.

Benodigde uitbreidingen zijn:

- Gestructureerde limietevents en attemptuitkomsten, inclusief reset- en retryinformatie,
  beschikbaar voor HKH vóór retries en ook bij mislukte jobs.
- Volledige usage bij geslaagde én mislukte attempts, inclusief beschikbare cachemetingen.
- Begrenzing en capaciteit per provider/account naast het totale workeraantal. Eén provider
  mag niet alle slots innemen terwijl een andere campagne werk klaar heeft.
- Zichtbare wachttijd door workergebrek, los van wachten op providerherstel.
- Instelbare hogere slotcapaciteit wanneer de resourceproef dat rechtvaardigt, of verdeling
  over meerdere workers. Het optellen van slots over workers vervangt geen accountlimiet.
- Bevestigen dat provider/model per fase worden ondersteund en correct gerapporteerd,
  inclusief de Mistral/Vibe-integratie. De actuele integratiestatus bij implementatie controleren.

## Testomgeving en toegang

Automatische functionele tests draaien op preview/test/acceptatie. Een duurtest met echte
providers gebruikt een afgeschermde testomgeving met een afgesproken collectiekopie en
bestaande runtimeproviderconfiguratie. De beheersessie start de campagne; agentjobs krijgen
geen productie-logincredentials of speciale AI/debug-tokens.

De pijplijn krijgt bronbestanden vanuit HKH en hoeft niet op productie in te loggen. Gebruiken
van productiedata of starten van betaalde runs vraagt een concrete uitvoeringsopdracht en
staat los van het implementeren van dit voorstel. Productieonderzoek of sessietoegang wordt
niet als omweg gebruikt om automatische testers productietoegang te geven.

## Bouwvolgorde en acceptatie

1. Maak een kleine, gevarieerde lijst en implementeer campagnes met vaste instellingen,
   duurzame fasevoortgang en parallelisme 1. Gebruik mocks voor limiet- en herstelgevallen.
2. Voeg gelijktijdige campagnes voor verschillende providers en instelbaar parallelisme toe.
   Dwing maximaal één actieve campagne per provider af. Controleer dat
   globale modellen en bezoekersverkeer niet worden gewijzigd door testinstellingen.
3. Lever runtime-events voor limieten en usage, herstelgedrag en de adminrapportage.
4. Voeg generatie/import en versiebeheer voor de grote vragenlijst toe. Voer een resourceproef
   uit en kies daarna de concurrency voor de eerste echte duurtest.

De eerste versie is gereed wanneer campagnes voor verschillende providers tegelijk kunnen draaien,
dezelfde vragenlijst gebruiken en na een backendherstart zonder dubbele jobs verdergaan.
Tests moeten korte limiet met herstel, bevestigde lange limiet, onbekende limiet, schemafout,
workergebrek, pauzeren, annuleren en uitgeputte vragenlijst onderscheiden. Controleer dat
één scenario met twee of drie AI-jobs precies één keer telt en retries geen extra geslaagde
zoekopdrachten opleveren. Controleer beide methoden, de normale settings zonder override en
de doorgifte van een testoverride naar alle fasen, inclusief planjobs, vervolgen en uitwerkingen.
Controleer dat publieke requests geen override kunnen afdwingen en campagnes elkaars instellingen
niet overschrijven. Test dat een tweede campagne voor dezelfde provider wordt geweigerd,
ook bij verschillende modellen, accountaliassen, gelijktijdige startverzoeken en wachten op
limietherstel. Beproef concurrency en herstel met begrensde mocks; voer de
standaard backend- en frontendchecks uit bij implementatie.

De eerste echte meting rapporteert beschikbare beginquota, dataset- en vragenlijstversie,
cachemetingen, parallelisme en ander accountgebruik. Alleen een waargenomen en voldoende
geclassificeerde grens mag als bereikte abonnementsgrens worden gepresenteerd.

## Gerelateerde documentatie

- [Pijplijn met twee AI-runs](ai-onderzoek-pijplijn-v2-twee-runs.md)
- [Bestaande onderzoekstestset](ai-onderzoek-testset.md)
- [Beheercontroller voor testset en vergelijking](../../backend/src/main/kotlin/nl/vdzon/hkh/aisearch/api/AdminAiResearchController.kt)
- [HKH orkestratie en koppeling van beurten](../../backend/src/main/kotlin/nl/vdzon/hkh/aisearch/AiSearchService.kt)
