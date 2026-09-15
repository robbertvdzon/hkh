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

## Zoeken en objectlinks

De homepage en zoekpagina tonen de vertrouwde ingangen Archief, Beeldbank, Bibliotheek,
Bidprentjes, Artikelen en Objecten. Een lege zoekterm laat bezoekers bladeren; een zoekterm
kan over alle collecties of binnen één collectie worden gebruikt. Dit start geen AI-opdracht.

Compacte filters bieden de oorspronkelijke collectievelden, zoals Type publicatie, Thema,
Straatnaam, Genre, Geboren te en Materiaal. Filterwaarden worden op verzoek uit de database
gehaald; zoeken in een lange keuzelijst werkt ook voorbij de eerste 100 waarden. Alternatieven
binnen hetzelfde filter gelden als OF, verschillende filters samen als EN. Uitgebreid zoeken
biedt alle woorden, één van de woorden, exacte tekst, woorddelen en afzonderlijke zoekvelden.
Bestaande zoeklinks zonder deze nieuwe opties behouden hun eerdere zoeksyntax.

Resultaten tonen collectie-eigen metadata en kunnen als lijst of galerij worden bekeken en
worden gesorteerd. Details tonen eerst de relevante velden, met daarnaast alle bronvelden,
beschikbare afbeeldingen en PDF’s. Vorige/volgende resultaten en terugnavigatie behouden de
zoekcontext. Ook na verversen bewaart de URL zoekterm, collectie, veldfilters, periode,
zoekwijze, sortering, weergave en paginanummer (`/#/zoeken?...`).

Periodefilters voor bidprentjes gebruiken **Geboren op**, niet het overlijdensjaar. ‘Recent
toegevoegd’ gebruikt de eerste importdatum; een herimport maakt een oud stuk niet nieuw.
Voor bestaande records zonder betrouwbare eerste importdatum wordt geen datum verzonnen.
Documenttekst (OCR) is beschikbaar zodra die als bronveld is geïmporteerd; de optie is
uitgeschakeld zolang de database geen documenttekst bevat. Deze functie voert geen OCR uit
op afbeeldingen of PDF’s.

Objecten hebben een eigen route (`/#/objecten/{collectie}/{ident}`). Bij openen vanuit de
resultaten blijft de zoekcontext in de object-URL staan. Dossiers, artikelen en AI-vragen
hebben eveneens eigen routes. De importserver blijft een backend-databron: publieke bronlinks
openen onze objecten en afbeeldingen/pdf’s worden via `/api/collection-media/{token}` gestreamd.
Bestaande opgeslagen antwoorden worden bij uitlezen ook omgezet naar interne verwijzingen.

## AI-zoekopdrachten

De afzonderlijke actie ‘Vraag stellen’ behandelt een vrije archiefvraag als een duurzame zoekopdracht. De backend
slaat de vraag, voortgang, antwoorden, bronnen, vervolgvragen en looptijden op in PostgreSQL. Een
HttpOnly-cookie met een anonieme bezoeker-ID koppelt een browser maximaal één jaar aan zijn eigen
zoekopdrachten; de cookie bevat geen antwoorden of persoonsgegevens. Daardoor zijn lopende en
afgeronde opdrachten ook in een andere tab terug te vinden. Wie browsercookies wist, verliest de
koppeling met de opgeslagen opdrachten.

De publieke API ondersteunt het overzicht en beheer via `GET /api/ai-search/sessions`,
`GET /api/ai-search/sessions/{id}` en `DELETE /api/ai-search/sessions/{id}`. De backend controleert
bij iedere detail-, vervolg-, annuleer- en verwijderactie of de opdracht bij de cookie hoort.

Een geladen antwoord is als PDF mee te nemen via `GET /api/ai-search/{answerId}/export/pdf`. Die
route gebruikt dezelfde bezoekerscookie, vraagt dus geen account, en levert bij succes status 200
met `Content-Type: application/pdf` en `Content-Disposition: attachment`
(`antwoord-<id>.pdf`). De PDF bevat de titel, de al gesaniteerde antwoord-HTML van het scherm en de
bronnenlijst als tekst; er worden geen externe bronnen opgehaald. Onbekende antwoorden of antwoorden
van een andere bezoeker geven `404`, een renderfout geeft `500` zonder lichaam. PDF's worden
on-demand gemaakt en nergens bewaard of gecachet.

## Accounts en dossiers

Inloggen met Google is optioneel en staat aan zodra `HKH_GOOGLE_CLIENT_ID` is gezet. Het Google
ID-token wordt één keer ingewisseld voor een eigen sessietoken (`POST /api/auth/google`) dat een jaar
geldig is en bij gebruik verlengt; alleen de hash staat in de database. Beheerroutes accepteren
uitsluitend dat sessietoken van een account op `HKH_ADMIN_ALLOWED_EMAILS`.

Ingelogde gebruikers bouwen onderzoeksdossiers (`/api/dossiers`): vragen aan het archief met
dossiercontext, een door AI bijgehouden feitenlijst, en artikelen in Markdown met versiegeschiedenis
en AI-voorstellen (`/api/articles`). Dossiers zijn per e-mailadres deelbaar met de rollen lezer,
onderzoeker en bewerker. Het volledige ontwerp staat in
[docs/architecture/accounts-en-dossiers.md](docs/architecture/accounts-en-dossiers.md).

Echte secrets, lokale overrides, buildoutput en IDE-bestanden worden niet gecommit.
