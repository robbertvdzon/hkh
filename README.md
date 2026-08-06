# Historische Kring Heemskerk App (HKH)

Dit is de handmatig productgestuurde variant van de HKH-app. De repository begint met dezelfde
technische baseline als `hkh-autopilot`; na baseline-tag `comparison-baseline-v1` mogen de
productfeatures uiteen gaan lopen.

## Componenten

- `backend` — Kotlin, Spring Boot en Spring Modulith;
- `frontend` — Flutter-gebruikersapp voor web en Android;
- `frontend-admin` — afzonderlijke Flutter-webapp voor beheerders;
- `deploy` — OpenShift/Kustomize/ArgoCD-configuratie;
- `.factory` — revisiongebonden verificatie voor Software Factory.

De backendbasis volgt de architectuurconventies van Personal News Feed. De exacte referentie en
bewuste afwijkingen staan in [docs/architecture/reference-baseline.md](docs/architecture/reference-baseline.md).

## Backend lokaal starten

Vereisten: JDK 21 en Maven 3.9 of nieuwer.

```bash
cp secrets.env.example secrets.env
docker compose -f docker-compose.dev.yml up -d
mvn -f backend/pom.xml spring-boot:run
```

De applicatie leest `secrets.env` uit de repositoryroot. Proces-environmentvariabelen hebben
voorrang. Controleer na het starten:

```text
GET http://localhost:8080/actuator/health
GET http://localhost:8080/api/version
GET http://localhost:8080/swagger-ui.html
```

## Verificatie

```bash
mvn -B --no-transfer-progress -f backend/pom.xml clean verify
```

Echte secrets, lokale overrides, buildoutput en IDE-bestanden worden niet gecommit.
