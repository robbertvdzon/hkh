# OpenShift deployment

De fase-1-baseline wordt via ArgoCD uit `deploy/overlays/openshift` naar namespace `hkh`
gesynchroniseerd. De set bevat de Kotlin-backend, beide Flutter-webapps en PostgreSQL 16.
OpenShift maakt voor de drie HTTP-services automatisch TLS-routes aan.

De productiedatabase gebruikt een 5Gi `local-path`-PVC op de SSD. Om 02:15 (Europe/Amsterdam)
maakt `postgres-backup` een gecontroleerde custom-format dump plus SHA-256-checksum op de externe
HDD onder `/var/mnt/external-hdd/postgres-backups/hkh`; bestanden ouder dan dertig dagen worden
opgeruimd. Een PR-preview gebruikt een eigen disposable 1Gi-PVC. Bij verwijdering van de
previewnamespace worden PVC en PV door de bestaande preview-lifecycle opgeruimd.

Alleen in een door de backend geverifieerde PR-preview worden na Flyway automatisch de
deterministische datasets uit `PreviewDataSeeder` toegepast. `preview_seed_history` houdt per
versie bij wat al is uitgevoerd, waardoor een restart en het beveiligde endpoint
`POST /api/admin/preview/test-data/ensure` idempotent zijn. Productie kan de seeder niet starten.

## Secrets

Platte clustersecrets komen nooit in Git:

```bash
cp deploy/secrets-cluster.env.example deploy/secrets-cluster.env
# vul de lokale, gitignored file in
./deploy/seal-secrets.sh
```

Het script schrijft alleen de versleutelde `deploy/base/sealed-secret-runtime.yaml`. Het gebruikt
het publieke certificaat uit de sibling-repository `robberts-infrastructure`, of haalt het
certificaat van de huidige cluster als die repository niet beschikbaar is.

`HKH_AGENT_RUNTIME_TOKEN` is het consumer-token waarmee alleen de HKH-backend AI-jobs aanmaakt.
Het token wordt nooit aan de Flutter-app of de browser doorgegeven.

Google-login (publieke app én beheerscherm) staat aan zodra `HKH_GOOGLE_CLIENT_ID` is gezet;
zolang die leeg is, is inloggen uitgeschakeld. `HKH_ADMIN_ALLOWED_EMAILS` bepaalt alleen wie
beheerder is. Dezelfde Google web-client-ID moet in het clustersecret en in de GitHub
Actions-variable `GOOGLE_CLIENT_ID` staan (die wordt in beide frontends ingebakken). In Google
Cloud moet het domein van de publieke frontend (naast dat van het beheerscherm en
`http://localhost:*` voor lokaal ontwikkelen) als "Authorized JavaScript origin" op diezelfde
OAuth-client staan. Voor de Android-app is daarnaast een aparte Android OAuth-client nodig in
hetzelfde Google Cloud-project, met de package-naam en de SHA-1 van de release-keystore; de app
zelf blijft de web-client-ID als `serverClientId` gebruiken.

## Controleren en installeren

```bash
kubectl kustomize deploy/overlays/openshift
oc apply -f deploy/argocd/application.yaml
oc get application hkh -n argocd
oc get pods,routes -n hkh
```

Een push op `main` bouwt alleen de gewijzigde componentimages. Daarna zet de workflow de SHA-tags
in de OpenShift-overlay; ArgoCD rolt alleen die gewijzigde deployments uit.

## Acceptatieomgeving

De standing acceptatieomgeving draait in namespace `hkh-acceptance` uit
`deploy/overlays/acceptance` en heeft een eigen ArgoCD-Application:

```bash
kubectl kustomize deploy/overlays/acceptance
oc apply -f deploy/argocd/application-acceptance.yaml
oc get application hkh-acceptance -n argocd
oc get pods,routes -n hkh-acceptance
```

`oc apply -f deploy/argocd/application-acceptance.yaml` is een **eenmalige** stap, net als bij
`deploy/argocd/application.yaml`. Daarna synchroniseert de acceptatieomgeving automatisch mee bij
elke wijziging in `deploy/overlays/acceptance/kustomization.yaml` op `main` — inclusief de
image-pins die de build-workflow zelf commit — precies zoals dat al voor productie (namespace
`hkh`) gebeurt. Zolang die stap niet is uitgevoerd, blijft acceptatie op een oude commit hangen.

Het manifest is een kopie van het productiemanifest; alleen naam, overlaypad en namespace
verschillen. Het past dus uitsluitend de bestaande, al goedgekeurde OpenShift/GitOps-deployroute
toe op de al bestaande acceptatieoverlay, **zonder** nieuwe opslag, externe koppeling, service of
gewijzigde toegangsgrens. Omdat `prune` en `selfHeal` aanstaan, trekt ArgoCD bij de eerste sync de
live toestand van `hkh-acceptance` gelijk met de overlay: handmatig aangebrachte, niet in Git
vastgelegde resources in die namespace kunnen daarbij worden opgeruimd of teruggezet.
