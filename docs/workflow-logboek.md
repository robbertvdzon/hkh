# Workflow-logboek

De Windows-app `hkh-workflow` (de wrapper rond ZCBS die Carla gebruikt) meldt aan de backend wat er gebeurt, zodat de beheerder
het in het beheerscherm kan terugkijken: elke inlogpoging, elke doorloop "nieuwe bestanden in ZCBS zetten" en elke doorloop
"records aanpassen", met alle instellingen, gekozen bestanden, stappen en de uitvoer van de programma's.

Backend: module `workflowlog`. Beheerscherm: `frontend-admin/lib/workflow/admin_workflow_log.dart`, pagina `/workflow-logboek`
(tabbladen Aangemaakt, Aangepast, Inloggen) en `/workflow-logboek/{uuid}` voor de volledige log van één doorloop.

## Meldpunt (zonder inlog)

Beide endpoints vragen geen inlog, maar wel de kop `X-HKH-Workflow-Key` met een vaste sleutel. Die staat bewust in de broncode
(`WorkflowLogIngestController.INGEST_KEY`): de gegevens zijn niet gevoelig en de sleutel houdt alleen toevallig verkeer tegen.

| Verzoek | Doel |
|---|---|
| `POST /api/workflow-log/logins` | Een inlogpoging: `{user, success, method: PASSWORD\|COOKIE, detail?, appVersion?, computer?, source?}` |
| `PUT /api/workflow-log/sessions/{uuid}` | Maakt de sessie aan of vervangt haar momentopname |

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

Het logboek wordt niet opgeruimd; alles blijft bewaard (besluit van Robbert).
