# hkh-236 — ArgoCD Application-manifest voor acceptatie toevoegen en deploy/README.md uitbreiden

## Plan

- [x] Repository-instructies, `docs/factory/development.md` en
  `docs/factory/agents/developer.md` lezen.
- [x] Voormeting: `kubectl kustomize deploy/overlays/acceptance` en
  `... deploy/overlays/openshift` vastleggen als vergelijkingsbasis.
- [x] Productiemanifest `deploy/argocd/application.yaml` volledig lezen; dit is de
  bron van waarheid voor structuur en veldwaarden.
- [x] `deploy/argocd/application-acceptance.yaml` toevoegen als structurele kopie
  met alleen een andere naam, overlaypad en namespace.
- [x] `deploy/README.md` uitbreiden met de eenmalige `oc apply`-regel en de
  toelichting op effect en grenzen.
- [x] Nameting: beide kustomize-builds opnieuw draaien en met de voormeting
  vergelijken; YAML-geldigheid en gewijzigde-bestandenlijst controleren.

## Gerealiseerd

- `deploy/argocd/application-acceptance.yaml` is nieuw: één YAML-document met een
  ArgoCD `Application` `hkh-acceptance` in namespace `argocd`, bron
  `https://github.com/robbertvdzon/hkh.git` op `main`, pad
  `deploy/overlays/acceptance`, doel `https://kubernetes.default.svc` /
  `hkh-acceptance`, `syncPolicy.automated` met `prune: true` en `selfHeal: true`,
  `syncOptions` `CreateNamespace=true` en `RespectIgnoreDifferences=true`, en
  `revisionHistoryLimit: 5`.
- `diff deploy/argocd/application.yaml deploy/argocd/application-acceptance.yaml`
  toont exact drie verschillen: `metadata.name`, `spec.source.path` en
  `spec.destination.namespace`. Het productiemanifest is ongewijzigd gebleven.
- `deploy/README.md` heeft een sectie `## Acceptatieomgeving` gekregen, in dezelfde
  codeblokstijl als `## Controleren en installeren`, met
  `oc apply -f deploy/argocd/application-acceptance.yaml`. De toelichting maakt
  expliciet dat dit een eenmalige stap is, dat de acceptatieomgeving daarna
  automatisch meesynchroniseert bij elke wijziging in
  `deploy/overlays/acceptance/kustomization.yaml` (net als productie in namespace
  `hkh`), en dat het uitsluitend de bestaande, al goedgekeurde OpenShift/GitOps-
  deployroute toepast zonder nieuwe opslag, externe koppeling, service of
  gewijzigde toegangsgrens. Het `prune`/`selfHeal`-aandachtspunt bij de eerste
  sync staat er als waarschuwing bij.

## Verificatie

- `kubectl kustomize deploy/overlays/acceptance` en
  `kubectl kustomize deploy/overlays/openshift`: beide exitcode 0 en uitvoer
  byte-identiek aan de voormeting (`diff` leeg). `deploy/overlays/preview` bouwt
  eveneens zonder fouten.
- Het nieuwe manifest is geldige YAML: het parseert zonder fouten via een
  tijdelijke kustomize-build buiten de repository.
- Geen enkele `kustomization.yaml` in de repository refereert
  `application-acceptance.yaml`; het bestand valt buiten alle overlays.
- `git status` toont alleen `deploy/README.md` (gewijzigd),
  `deploy/argocd/application-acceptance.yaml` (nieuw) en deze worklog.
  `git diff` op `deploy/argocd/application.yaml`, `deploy/overlays/`, `backend/`,
  `frontend/`, `frontend-admin/` en `.github/` is leeg.
- Het vangnet uit `.factory/verification.yaml` selecteert voor deze wijziging geen
  commando's: geen van de `pathPrefixes` (`backend/`, `frontend/`,
  `frontend-admin/`, `tools/flutter-verify.sh`, `.factory/verification.yaml`)
  raakt `deploy/` of `docs/`. Er is geen applicatiecode gewijzigd en er is geen
  `pubspec.lock`-churn ontstaan.

## Niet gedaan / aangepast

- Geen `oc apply` of enige andere clusteractie uitgevoerd. Het toepassen van het
  nieuwe manifest is een eenmalige operationele stap buiten deze codewijziging;
  acceptatie begint pas ná die stap mee te synchroniseren.
- Afwijking t.o.v. de acceptatiecriteria: het productiemanifest bevat ook
  `revisionHistoryLimit: 5`, dat in criterium 1 niet genoemd wordt. Conform
  criterium 2 (productiemanifest is bron van waarheid) is dat veld overgenomen.
  Er zijn geen `finalizers`, `labels`/`annotations`, `ignoreDifferences`,
  `source.kustomize` of `retry`-secties in het productiemanifest, dus die
  ontbreken ook hier.
- Afwijking t.o.v. criterium 11 (gewijzigde-bestandenlijst): naast de twee
  genoemde bestanden staat ook deze worklog in de worktree. Dat is verplicht
  volgens `docs/factory/agents/developer.md` en volgt het patroon van eerdere
  stories; er is geen andere wijziging toegevoegd.
- Er is geen `kustomization.yaml` of app-of-apps-constructie in `deploy/argocd/`
  geïntroduceerd, en de inhoud van alle overlays is ongemoeid gelaten.
- Aanname: `hkh-acceptance` is nog niet als ArgoCD Application-naam in namespace
  `argocd` in gebruik; de nieuwe Application staat los van de bestaande `hkh`.
