# Deployment

De OpenShift-baseline is volledig declaratief en staat onder `deploy`. ArgoCD volgt de
`deploy/overlays/openshift`-overlay op `main` en synchroniseert die naar namespace `hkh`.

Er zijn twee ArgoCD Applications, met dezelfde automatische `syncPolicy` (`prune` en `selfHeal`):
`deploy/argocd/application.yaml` voor productie (overlay `deploy/overlays/openshift`, namespace
`hkh`) en `deploy/argocd/application-acceptance.yaml` voor de standing acceptatieomgeving (overlay
`deploy/overlays/acceptance`, namespace `hkh-acceptance`). Beide manifesten moeten eenmalig met
`oc apply` op het cluster worden gezet; zolang dat voor een omgeving niet is gebeurd, blijft die
omgeving op een oude commit hangen. Zie `deploy/README.md` voor de installatiecommando's.

De backend, gebruikersfrontend, adminfrontend en PostgreSQL hebben eigen workloads, services,
probes en resourcegrenzen. Alleen de drie HTTP-services krijgen een OpenShift Route. De database
blijft intern. De database gebruikt de SCL-org PostgreSQL 16-image die voor OpenShift en
willekeurige niet-root-UID's is ingericht; er is geen verruimde SCC nodig.

De fase-1-database gebruikt bewust een efemeer `emptyDir`: de applicatie is nog leeg en Flyway
bouwt het technische schema bij iedere nieuwe pod herhaalbaar op. Voordat echte historische data
wordt ingevoerd moet de runtime naar een managed PostgreSQL of een persistente StorageClass met
correcte OpenShift SELinux-labeling worden omgezet. De lokale `local-path` hostPath-StorageClass
voldoet daar niet aan.

Runtimewaarden komen uit de SealedSecret `hkh-runtime`. Alleen de gitignored bronfile
`deploy/secrets-cluster.env` bevat plaintext; zie `deploy/README.md` voor generatie en installatie.

Image-tags beginnen op `main`. Na iedere componentbuild vervangt GitHub Actions uitsluitend de
bijbehorende tag door `sha-<commit>` in zowel de OpenShift- als de acceptance-overlay, commit die
manifestwijziging en laat ArgoCD de rollout doen. Productie en acceptatie gebruiken exact dezelfde image-tags. Hun openbare webconfiguratie
staat in `deploy/overlays/<omgeving>/web-config.json`, door Kustomize als een ConfigMap met
inhoudshash gemount op `/usr/share/nginx/html/runtime-config`. Daardoor worden pods ook bij
een configuratiewijziging opnieuw uitgerold. Productie houdt Google-login aan; acceptatie en
previews gebruiken hun bestaande previewmodus en dezelfde-origin API-proxy.

## Snellere builds

De imageworkflow kiest componenten sinds de laatste geslaagde imagebuild. Daardoor worden
wijzigingen uit mislukte of afgebroken builds alsnog meegenomen. Backend, gebruikersfrontend
en adminfrontend bouwen parallel. Ook de verificatie draait per component parallel; de
bestaande checknaam `Repository verification` verzamelt de resultaten.

Flutter 3.44.7 wordt direct op de runner gebruikt, met SDK- en lockfile-afhankelijke pub-cache.
De CI gebruikt `Dockerfile.runtime` om alleen de gebouwde statische bestanden in nginx te
verpakken. De grote Flutter-buildimage hoeft daardoor niet meer als Dockerlaag of cache te
worden overgedragen. Elke frontend wordt één keer gecompileerd met `RUNTIME_CONFIG=true`,
voor alle omgevingen. De configuratie wordt vóór het starten van Flutter geladen en krijgt
`Cache-Control: no-store`. Ontbrekende of ongeldige configuratie stopt het opstarten; er is
geen automatische terugval naar previewmodus.

De backend bewaart Maven-dependencies in een gewone Dockerlaag. Een BuildKit cache mount
wordt niet vanzelf geëxporteerd naar de GitHub Actions-laagcache; daarom gebruikt deze build
geen afzonderlijke `.m2`-cachemount meer. De dependencylaag wordt hergebruikt zolang `pom.xml`
gelijk blijft. Elke component heeft een eigen Docker-cachescope; frontendcaches bevatten alleen
het kleine nginx-runtimegedeelte. PR's lezen de releasecache maar overschrijven hem niet.

De volledige `Dockerfile` blijft beschikbaar voor lokale frontendbuilds. Mount daarbij een
`config.json`-bestand onder `/usr/share/nginx/html/runtime-config/`. `flutter run` en APK-builds
blijven de bestaande `API_BASE_URL`, `GOOGLE_CLIENT_ID` en `PREVIEW_MODE` dart-defines gebruiken;
alleen webbuilds met `RUNTIME_CONFIG=true` laden de JSON-configuratie. De Google-client-ID in
de JSON is openbaar; het backend-client-ID in de SealedSecret moet hiermee overeenkomen.

De eerste CI-run vult nieuwe caches. Vergelijk daarna de Actions job- en steptijden, met
wachtrijtijd apart. Er is geen betaalde grotere runner ingesteld. Een oude run mag een
nieuwere bronwijziging niet overschrijven; nieuwere documentatie- of deploywijzigingen
blokkeren het pinnen van een verder identieke build niet.
