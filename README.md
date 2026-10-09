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

## Publieke site (fase 1: vaste inhoud)

De frontend is de nieuwe publieke website van de HKH, ingedeeld naar wat een bezoeker komt doen:
Agenda, Nieuws, Ontdek Heemskerk, Geheugen van Heemskerk, Collecties, Educatie en Vereniging, plus
de knop Lid worden. Onderdelen met meerdere ingangen tonen een submenubalk onder het hoofdmenu
(`subMenus` in `site_structure.dart`).
Het onderzoek naar de oude site en het structuurvoorstel staan in
[docs/website-vernieuwing](docs/website-vernieuwing/README.md).

In deze fase staat alle inhoud als vaste gegevens in de app, overgenomen van de oude site:

- `frontend/lib/content/content_models.dart`: de modellen (pagina, activiteit, bericht,
  nieuwsbrief, uitgave, bestuurslid, lesaanbod);
- `frontend/lib/content/generated_content.dart` en `generated_memory.dart` (de 174 verhalen van
  het Geheugen van Heemskerk): gegenereerd uit de oude site met de scripts in
  `docs/website-vernieuwing/scripts/` (niet met de hand bewerken);
- `frontend/lib/content/site_structure.dart`: de indeling (menu, rubrieken, onderdelen van
  Vereniging), het lesaanbod, de nieuwsbrieven, partnerlinks en praktische gegevens.

Foto's worden in deze fase nog van de oude site geladen. De formulieren voor inschrijven (met
wachtlijst), lesaanbod aanvragen, contact en lid worden tonen een voorbeeldbevestiging en bewaren
nog niets; dat komt in fase 2 samen met de database en het beheer. De routes zijn `/#/agenda`,
`/#/agenda/{slug}`, `/#/nieuws`, `/#/ontdek`, `/#/ontdek/{slug}`, `/#/geheugen`,
`/#/geheugen/verhaal/{slug}`, `/#/collecties`, `/#/educatie`, `/#/vereniging/{onderdeel}` en
`/#/lid-worden`; `/#/zoeken`, `/#/vragen` (Onderzoek) en `/#/luchtfoto` blijven bestaan.

## Zoeken en objectlinks

De pagina Collecties verwijst naar de zoekpagina. Daar staan de vertrouwde ingangen Archief,
Beeldbank, Bibliotheek, Bidprentjes, Artikelen en Objecten. Zonder zoekterm of ingevuld filter
blijven de resultaten leeg. Een nieuwe zoekopdracht doorzoekt alle collecties; de collectieknoppen
tonen het aantal treffers voor die opdracht, inclusief nul. Een klik beperkt de resultaten tot die
collectie. Actieve filters blijven gelden bij het wisselen van collectie, zodat het getoonde aantal
overeenkomt met de resultaten. Dit start geen AI-opdracht.

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
resultaten blijft de zoekcontext in de object-URL staan. AI-vragen hebben eveneens een eigen
route. De importserver blijft een backend-databron: publieke bronlinks
openen onze objecten en afbeeldingen/pdf’s worden via `/api/collection-media/{token}` gestreamd.
Bestaande opgeslagen antwoorden worden bij uitlezen ook omgezet naar interne verwijzingen.

## AI-zoekopdrachten

De afzonderlijke actie ‘Vraag stellen’ behandelt een vrije archiefvraag als een duurzame zoekopdracht. De backend
slaat de vraag, voortgang, antwoorden, bronnen, vervolgvragen en looptijden op in PostgreSQL. Een
HttpOnly-cookie met een anonieme bezoeker-ID koppelt een browser maximaal één jaar aan zijn eigen
zoekopdrachten; de cookie bevat geen antwoorden of persoonsgegevens. Daardoor zijn lopende en
afgeronde opdrachten ook in een andere tab terug te vinden. Wie browsercookies wist, verliest de
koppeling met de opgeslagen anonieme opdrachten.

Na inloggen horen persoonlijke vragen bij het HKH-account achter de Google-login. De app koppelt
bestaande browservragen automatisch via `POST /api/ai-search/sessions/claim`; ingelogde AI-aanvragen
herhalen dit idempotent. Dezelfde gebruiker ziet op elke pc dezelfde vragen. Gekoppelde sessies
verliezen hun bezoekers-ID en zijn na uitloggen niet meer via die cookie toegankelijk. Openbare
deellinks blijven geldig.

De publieke API ondersteunt het overzicht en beheer via `GET /api/ai-search/sessions`,
`GET /api/ai-search/sessions/{id}` en `DELETE /api/ai-search/sessions/{id}`. De backend controleert
bij iedere detail-, vervolg-, annuleer- en verwijderactie of de opdracht bij het account of, zonder login, bij de cookie hoort. Ongeldige sessietokens geven 401.

AI-antwoorden kunnen collectiefoto’s tussen de tekst plaatsen met
`<figure data-hkh-source="collection/ident"><figcaption>Bijschrift</figcaption></figure>`.
De server haalt de afbeelding uitsluitend uit een geverifieerde bron in `sources`; losse `img`-tags
of door de AI opgegeven afbeeldings-URL’s worden verwijderd. Elk ingevoegd beeld heeft een
bijschrift en bronlink en wordt niet nogmaals onderaan afgebeeld. De bronnenlijst blijft compleet.
Dit geldt voor nieuw gegenereerde antwoorden; opgeslagen antwoorden worden niet herschreven.

Een geladen antwoord is als PDF mee te nemen via `GET /api/ai-search/{answerId}/export/pdf`. Die
route gebruikt hetzelfde account of dezelfde bezoekerscookie, vraagt dus geen verplichte login, en levert bij succes status 200
met `Content-Type: application/pdf` en `Content-Disposition: attachment`
(`antwoord-<id>.pdf`). De PDF bevat de titel, de al gesaniteerde antwoord-HTML van het scherm en de
bronnenlijst als tekst; er worden geen externe bronnen opgehaald. Onbekende antwoorden of antwoorden
van een andere bezoeker geven `404`, een renderfout geeft `500` zonder lichaam. PDF's worden
on-demand gemaakt en nergens bewaard of gecachet.

## Accounts

Inloggen met Google is optioneel en staat aan zodra `HKH_GOOGLE_CLIENT_ID` is gezet. Het Google
ID-token wordt één keer ingewisseld voor een eigen sessietoken (`POST /api/auth/google`) dat een jaar
geldig is en bij gebruik verlengt; alleen de hash staat in de database. Beheerroutes accepteren
uitsluitend dat sessietoken van een account op `HKH_ADMIN_ALLOWED_EMAILS`. In de publieke app dient
de login alleen om AI-vragen aan een account te koppelen.

De onderzoeksdossiers zijn uit de publieke app verwijderd (oktober 2026); de backendmodule
`dossier` en de routes `/api/dossiers` en `/api/articles` bestaan nog maar worden door de app niet
meer gebruikt. Het oude ontwerp staat in
[docs/architecture/accounts-en-dossiers.md](docs/architecture/accounts-en-dossiers.md).

Echte secrets, lokale overrides, buildoutput en IDE-bestanden worden niet gecommit.

De publieke app gebruikt overal dezelfde groene HKH-header en directe paginaovergangen.
Tekst in AI-antwoorden kan worden geselecteerd en gekopieerd. PDF-voorvertoningen worden
begrensd tot 800 pixels en één gelijktijdige verwerking om geheugen beschikbaar te houden
voor zoekvragen en PDF-downloads.
