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

Google-login blijft bewust uitgeschakeld zolang zowel `HKH_GOOGLE_CLIENT_ID` als
`HKH_ADMIN_ALLOWED_EMAILS` leeg zijn. Voor echte login moeten dezelfde Google web-client-ID in
het clustersecret en in de GitHub Actions-variable `GOOGLE_CLIENT_ID` staan.

## Controleren en installeren

```bash
kubectl kustomize deploy/overlays/openshift
oc apply -f deploy/argocd/application.yaml
oc get application hkh -n argocd
oc get pods,routes -n hkh
```

Een push op `main` bouwt alleen de gewijzigde componentimages. Daarna zet de workflow de SHA-tags
in de OpenShift-overlay; ArgoCD rolt alleen die gewijzigde deployments uit.
