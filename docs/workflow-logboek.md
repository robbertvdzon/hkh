# Workflow-logboek

De Windows-app `hkh-workflow` (de wrapper rond ZCBS die Carla gebruikt) meldt aan de backend wat er gebeurt, zodat de beheerder
het in het beheerscherm kan terugkijken: elke inlogpoging, elke doorloop "nieuwe bestanden in ZCBS zetten" en elke doorloop
"records aanpassen", met alle instellingen, gekozen bestanden, stappen en de uitvoer van de programma's. Daarnaast stuurt de app
zijn eigen logregels (INFO en hoger) op, het **app-log** (zie hieronder).

Backend: module `workflowlog`. Beheerscherm: `frontend-admin/lib/workflow/admin_workflow_log.dart`, pagina `/workflow-logboek`
(tabbladen Aangemaakt, Aangepast, Inloggen en App-log) en `/workflow-logboek/{uuid}` voor de volledige log van één doorloop.

## Meldpunt (zonder inlog)

De endpoints vragen geen inlog, maar wel de kop `X-HKH-Workflow-Key` met een vaste sleutel. Die staat bewust in de broncode
(`WorkflowLogIngestController.INGEST_KEY`): de gegevens zijn niet gevoelig en de sleutel houdt alleen toevallig verkeer tegen.

| Verzoek | Doel |
|---|---|
| `POST /api/workflow-log/logins` | Een inlogpoging: `{user, success, method: PASSWORD\|COOKIE, detail?, appVersion?, computer?, source?}` |
| `PUT /api/workflow-log/sessions/{uuid}` | Maakt de sessie aan of vervangt haar momentopname |
| `POST /api/workflow-log/app-logs` | Een pakketje logregels van de app (zie "App-log") |

Een sessiebericht: `{kind: NEW_FILES\|EDIT, secret, user, collection, appVersion, computer, phase, phaseCount, phaseLabel,
status: RUNNING\|FINISHED\|FAILED, fileCount, event?, snapshot, source?}`.

- `snapshot` is een vrij JSON-object met alles wat de app weet; elk bericht **vervangt** de vorige (de app stuurt dus telkens
  alles opnieuw, een gemist bericht herstelt zich vanzelf). Het beheerscherm toont elke sleutel van het object als uitklapbaar blok.
- `secret` is een willekeurig geheim (minimaal 16 tekens) dat de app bij de start van de sessie verzint. Alleen een bericht met
  hetzelfde geheim mag een bestaande sessie bijwerken; de backend bewaart alleen de hash.
- `source` is de bron die de beheerder in de workflow-app heeft ingesteld (bijvoorbeeld `macbook`, `windows-laptop` of `hkh`); het
  beheerscherm toont hem als kolom en kan erop filteren (`?source=` op de lijsten, `GET /api/admin/workflow-log/sources` voor de keuzelijst).
- `event` is een korte regel voor de tijdlijn. Zonder `event` komt er alleen een regel bij als fase of status verandert.
- Een sessie die `RUNNING` is en 30 minuten niets meer meldt, toont het beheerscherm als **verlaten**.

Antwoorden: `204` bij succes, `400` ongeldig bericht (of groter dan 1 MB), `401` sleutel ontbreekt of klopt niet, `403`
sessiegeheim klopt niet, `429` met `Retry-After: 60` bij te veel meldingen, `507` als het logboek vol zit (20.000 sessies).

## Bescherming tegen misbruik

- Limieten in het geheugen (`IngestRateLimiter`, token-bucket), per adres 60 verzoeken per minuut, 30 nieuwe sessies per uur en
  20 inlogmeldingen per minuut; per sessie 20 per minuut; voor alles samen 600 verzoeken per minuut en 200 nieuwe sessies per uur.
  De backend draait met één pod; bij meer pods geldt de limiet per pod.
- Het adres voor de limieten is het adres dat onze eigen router aan `X-Forwarded-For` toevoegde, geteld vanaf het eind
  (`hkh.workflow-log.forwarded-hops`, standaard 1 omdat de nginx van het beheerscherm er nog één bijzet). Wat links daarvan staat
  en `CF-Connecting-IP` kan een afzender zelf verzinnen.
- Maximaal 1 MB per bericht; de lengte van alle tekstvelden wordt afgekapt.
- Uitzondering, tijdelijk: het veld `ftpPassword` blijft leesbaar (`hkh.workflow-log.keep-ftp-password`, standaard aan), zodat de
  beheerder in het begin kan controleren wat er in de workflow-app is ingesteld. Zet `HKH_WORKFLOW_LOG_KEEP_FTP_PASSWORD=false` op de
  backend (of het vinkje uit in de instellingen van de app) zodra dat niet meer nodig is; reeds bewaarde sessies houden dan nog wel het
  wachtwoord in hun momentopname.
- Velden die op een geheim lijken (`password`, `wachtwoord`, `secret`, `token`, `...key`) worden vóór het bewaren vervangen. De
  app filtert ze ook zelf.
- Alles wat binnenkomt is ongecontroleerd: het beheerscherm toont het als platte tekst en zegt dat het indicatief is.

De sessies en inlogpogingen worden niet opgeruimd; alles blijft bewaard (besluit van Robbert). Alleen het app-log (hieronder) heeft een
bewaartermijn.

## App-log

De app schrijft zijn logregels van INFO en hoger weg en stuurt ze in pakketjes op, hooguit eens per kwartier en alleen als er iets nieuws
is. Wat er gebeurt:

`POST /api/workflow-log/app-logs`, zelfde kop `X-HKH-Workflow-Key` als hierboven:

```
{ "source": "hkh", "computer": "FILESERVER", "appVersion": "0.0.1-SNAPSHOT+20261031.1405",
  "chunkId": "…",
  "lines": [ {"time": "2026-10-31T14:05:11.123Z", "level": "INFO|WARN|ERROR", "logger": "nl.vdzon…", "message": "…"} ] }
```

- `source`, `computer` en `chunkId` zijn verplicht. `chunkId` is uniek per bron en computer: een pakketje met een chunkId dat al eerder
  kwam (de app herhaalt het na een time-out) geeft opnieuw `204` maar wordt niet nog eens bewaard.
- Maximaal 5000 regels per pakketje en 1 MB per bericht. Een `message` kan meerdere regels bevatten (een stacktrace), maximaal 8000
  tekens. `level` moet `INFO`, `WARN` of `ERROR` zijn; `time` een ISO-8601-tijdstip (UTC).
- Een pakketje zonder regels geeft `204` en wordt niet bewaard. Regels met een tijd van meer dan 2 dagen in de toekomst of van ouder dan de
  bewaartermijn worden weggegooid (niet geweigerd).
- Geheimen in `message` en `logger` worden vóór het bewaren vervangen door `***` (`AppLogMasker`): `password=…`, `wachtwoord: …`,
  `"ftpPassword":"…"`, `secret`, `token`, `api-key`, `Authorization: Bearer …` en `gebruiker:wachtwoord@` in een adres. De app maskeert zelf
  ook al; dit is de tweede controle.
- Antwoorden: `204`, `400` (geen geldig bericht, onbekend niveau, ongeldige tijd, te veel regels, ontbrekend veld), `401` (sleutel) en `429`
  met `Retry-After: 60`.
- Limieten (`IngestLimits`, bovenop de gewone limieten per adres en voor alles samen): per adres 10 pakketjes achter elkaar en daarna 30 per
  uur, voor alle adressen samen 100 achter elkaar en daarna 200 per uur. De app stuurt er normaal maar vier per uur; een inhaalslag na een
  storing mag in één keer.

Opslag: tabellen `workflow_app_log` (de regels, met bron, computer en appversie erbij) en `workflow_app_log_chunk` (welke pakketjes al zijn
ontvangen, voor de herhaling).

**Bewaartermijn: 30 dagen** (`hkh.workflow-log.app-log-retention-days`, environment `HKH_WORKFLOW_LOG_APP_LOG_RETENTION_DAYS`). Elke nacht om
03:45 (Amsterdam) verwijdert `WorkflowAppLogRetention` de regels op hun logtijd en de pakketnamen op hun ontvangsttijd.

### Beheer-API

Zelfde authenticatie als de rest van `/api/admin/workflow-log`:

| Verzoek | Doel |
|---|---|
| `GET /app-logs?source=&computer=&level=&version=&q=&before=&limit=` | `{items: [{id, time, level, logger, message, source, computer, appVersion}], next}`, nieuwste eerst. `level` is een minimumniveau (`WARN` geeft ook `ERROR`); `q` zoekt zonder hoofdletters in bericht en logger (`%` en `_` zijn gewone tekens); `before` is de `next` van de vorige pagina; `limit` standaard 200, maximaal 1000 |
| `GET /app-logs/overview` | Per bron en computer: `{source, computer, appVersion (van de nieuwste regel), lastSeen (laatste ontvangen pakketje), lines24h, warnings24h, errors24h}`, nieuwste eerst |
| `GET /app-logs/versions` | De appversies waarvan er regels zijn, nieuwste eerst, voor het filter |
| `GET /sources` | Bevat ook de bronnen uit het app-log |

### Het tabblad App-log

Bovenaan een overzicht per computer (bron, computer, versie, laatst gezien, regels, waarschuwingen en fouten in de laatste 24 uur; een
computer zonder pakketje in 24 uur is grijs, een klik op een rij filtert op die computer). Daaronder de filters (bron, computer, niveau,
versie en zoektekst) en de regels in een monospace-lijst met tijd, niveau, versie, ingekorte logger en bericht; een stacktrace is
uitklapbaar. "Meer laden" haalt de volgende, oudere pagina. Alles is platte tekst en selecteerbaar. Omdat de app alleen stuurt als er
nieuwe regels zijn, betekent een grijze regel niet per se dat de app uit staat.
