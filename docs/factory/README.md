# Factory Docs

Deze repository bevat de app van de Historische Kring Heemskerk (HKH): een
Spring Boot/Kotlin-backend met twee Flutter-frontends. Bezoekers ontdekken via de
app de geschiedenis van Heemskerk; beheerders onderhouden de inhoud via een
aparte adminapp.

## Repo-onderdelen

- `backend/` — Kotlin/Spring Boot (Spring Modulith) API met PostgreSQL en Flyway.
  Levert onder meer `/api/news`, `/api/version` en `/actuator/health`.
- `frontend/` — Flutter-gebruikersapp (web en Android) met de homepage,
  productvisiepagina en de sectie "Laatste nieuws".
- `frontend-admin/` — afzonderlijke Flutter-webapp voor beheerders.
- `deploy/` — OpenShift/Kustomize/ArgoCD-configuratie, overlays en sealed secrets.
- `tools/` — hulpscripts, waaronder de baseline-contract- en pariteitschecks
  (`baseline-contract-test.sh`, `verify-baseline-parity.py`).
- `.factory/` — revisiongebonden verificatieconfig voor Software Factory.

## Leesvolgorde voor agents

1. `development.md`: lokaal bouwen, testen, het verplichte vangnet en conventies.
2. `technical-spec.md`: technische keuzes, frameworks en codeconventies.
3. `functional-spec.md`: functionele afspraken en gebruikersgedrag.
4. `deployment.md`: deploy-flow en machine-leesbare factory-config.
5. `secrets-local.md`: lokale secrets en waar die vandaan komen.
6. `agents/`: rol-specifieke instructies voor factory-agents.
