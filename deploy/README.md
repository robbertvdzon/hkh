# OpenShift deployment

De fase-1-baseline wordt via ArgoCD uit `deploy/overlays/openshift` naar namespace `hkh`
gesynchroniseerd. De set bevat de Kotlin-backend, beide Flutter-webapps en een efemere
PostgreSQL 16-database. OpenShift maakt voor de drie HTTP-services automatisch TLS-routes aan.
Voordat echte historische gegevens worden opgeslagen, moet de database naar managed PostgreSQL
of geschikte persistente OpenShift-opslag worden omgezet; zie `docs/deployment.md`.

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
