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

## AI-zoekopdrachten

De publieke frontend behandelt iedere vrije archiefvraag als een duurzame zoekopdracht. De backend
slaat de vraag, voortgang, antwoorden, bronnen, vervolgvragen en looptijden op in PostgreSQL. Een
HttpOnly-cookie met een anonieme bezoeker-ID koppelt een browser maximaal één jaar aan zijn eigen
zoekopdrachten; de cookie bevat geen antwoorden of persoonsgegevens. Daardoor zijn lopende en
afgeronde opdrachten ook in een andere tab terug te vinden. Wie browsercookies wist, verliest de
koppeling met de opgeslagen opdrachten.

De publieke API ondersteunt het overzicht en beheer via `GET /api/ai-search/sessions`,
`GET /api/ai-search/sessions/{id}` en `DELETE /api/ai-search/sessions/{id}`. De backend controleert
bij iedere detail-, vervolg-, annuleer- en verwijderactie of de opdracht bij de cookie hoort.

Echte secrets, lokale overrides, buildoutput en IDE-bestanden worden niet gecommit.
