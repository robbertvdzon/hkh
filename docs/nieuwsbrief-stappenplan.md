# Nieuwsbrief naar de leden

Stappenplan om vanaf de ledenadministratie een nieuwsbrief naar circa 1.600 leden te versturen
zonder dat het domein op een zwarte lijst belandt. Opgesteld op 12 september 2026, na een
DNS-nulmeting op `historischekringheemskerk.nl`.

Een afvinkbare versie van dit document staat als artifact op
<https://claude.ai/code/artifact/8ab7e226-b71e-482f-9cc6-de60e3a0f9c7>.

## Besluiten

| Onderwerp | Besluit |
| --- | --- |
| Verzendplatform | Laposta, gratis account (tot 2.000 relaties, 12.000 mailings per maand). |
| Mailchimp | Afgevallen: gratis tot 250 contacten, en het abonnement loopt door in maanden zonder verzending. |
| Grondslag | Bestaande relatie (lidmaatschap), Telecommunicatiewet art. 11.7. |
| Verzenddomein | Subdomein `nieuws.historischekringheemskerk.nl`, niet het hoofddomein. |
| Tempo | 100 per dag, met controle op bounces tussen de batches door. |
| Mailcredits | Pas overwegen ná de eerste nieuwsbrief; het gratis account vervalt bij aankoop. |

## 1. Keuze van het platform: Laposta, niet Mailchimp

Mailchimp is in de bespreking geopperd. Dat is een begrijpelijk voorstel — het is de bekendste
nieuwsbriefdienst ter wereld, jarenlang de standaardkeuze voor kleine verenigingen. Het is hier
toch niet gekozen, en dat heeft drie concrete redenen.

**Het gratis account is te klein geworden.** Mailchimp was ooit gratis tot 2.000 contacten, wat
het juist voor verenigingen aantrekkelijk maakte. Die grens is stapsgewijs teruggebracht: 2.000 in
2022, 500 in 2023, en sinds februari 2026 nog 250 contacten en 500 mails per maand. Met circa
1.600 leden valt de kring daar ruim buiten en is een betaald abonnement verplicht.

**Het prijsmodel past niet bij hoe de kring mailt.** Mailchimp rekent per contact per maand,
ongeacht of er iets verstuurd wordt. Bij een nieuwsbrief die twee keer per jaar uitgaat, betaalt de
kring twaalf maanden voor twee zendingen. Laposta's mailcredits werken omgekeerd: je betaalt per
verzonden bericht en ongebruikt tegoed verloopt nooit.

**Amerikaanse dienst, extra AVG-werk.** Mailchimp is sinds 2021 eigendom van Intuit, is
Engelstalig en slaat gegevens buiten de EU op. Dat is juridisch werkbaar onder het EU-VS Data
Privacy Framework, maar de verwerkersovereenkomst moet zelf worden opgevraagd en de doorgifte naar
de Verenigde Staten moet in de privacyverklaring worden verantwoord. Bij Laposta staan de gegevens
in Nederland en zit de verwerkersovereenkomst standaard in het account.

| | Laposta | Mailchimp |
| --- | --- | --- |
| Gratis tot | 2.000 relaties | 250 contacten |
| Rekenwijze | Per verzonden bericht, tegoed verloopt niet | Per contact per maand, ook zonder verzending |
| Kosten bij 1.600 leden, 2x per jaar | €0, of ~€60 per jaar aan credits | Abonnement het hele jaar door |
| Gegevens | Nederland | Buiten de EU |
| Verwerkersovereenkomst | Standaard inbegrepen | Zelf opvragen |
| Taal | Nederlands, met Nederlandse support | Engels |

Functioneel doen de twee hetzelfde: lijstbeheer, een opmaakeditor, afmeldlinks, bounceverwerking
en statistieken. Mailchimp heeft daarbovenop veel dat de kring niet gebruikt — automatiseringen,
webshopkoppelingen, advertentiebeheer. Het is geen slecht product, maar een verkeerde match: voor
deze omvang en dit verzendritme is het duurder, ingewikkelder en juridisch omslachtiger zonder dat
er iets tegenover staat.

## 2. Stap 1 — DNS op orde brengen

Drie DNS-records bepalen of Gmail en Outlook post van dit domein vertrouwen. Ontbreekt er één,
dan belandt bulkmail van een tot dan toe onbekende afzender vrijwel zeker in de spammap. Doe dit
daarom eerst, vóór er ook maar iets in Laposta wordt ingericht.

| Record | Wat het doet |
| --- | --- |
| SPF | Vertelt de ontvanger welke servers namens het domein mogen verzenden. |
| DKIM | Zet een digitale handtekening onder elke mail, zodat knoeien onderweg opvalt. |
| DMARC | Zegt wat de ontvanger moet doen als SPF of DKIM niet klopt, en waar het rapport heen gaat. |

### Hoe het er nu voor staat

Gemeten op het DNS van `historischekringheemskerk.nl` op 12 september 2026. Twee van de drie staan
goed; één is stuk.

| Controle | Status | Bevinding |
| --- | --- | --- |
| SPF | Goed | Geldig record, 4 van maximaal 10 DNS-lookups gebruikt. Ruimte voor Laposta. |
| DKIM | Goed | Selector `x`, RSA 2048-bit, ingericht door ZXCS. |
| DMARC | Stuk | Er staan twee DMARC-records. |
| Subdomein | Nog niet | `nieuws.historischekringheemskerk.nl` bestaat nog niet. |

Hosting loopt via ZXCS (`web0141.zxcs.nl`), mail via `spamrelay.zxcs.nl`, DNS bij b-smarthosting.
Alle wijzigingen hieronder gaan via het DNS-beheer daar.

### Waarom het dubbele DMARC-record een echt probleem is

Op `_dmarc.historischekringheemskerk.nl` staan nu twee TXT-records:

```
"v=DMARC1; p=none; sp=none; rua=mailto:hkhadmin@historischekringheemskerk.nl"
"v=DMARC1; p=none; sp=none;"
```

RFC 7489 schrijft voor dat een ontvanger die méér dan één DMARC-record vindt, het domein
behandelt alsof er helemaal geen DMARC is. Op papier is het domein dus beschermd, maar Gmail en
Outlook zien niets — en dat is precies de controle die grote providers bij bulkmail uitvoeren.

### Wat er moet veranderen

Er moet één DMARC-record overblijven, met deze inhoud:

```
v=DMARC1; p=none; sp=none; fo=1; rua=mailto:hkhadmin@historischekringheemskerk.nl
```

- [ ] Het lege tweede record (zonder `rua=`) verwijderen
- [ ] Het overgebleven record aanvullen met `fo=1`
- [ ] Na een uur controleren dat er nog één record staat (`dig TXT _dmarc.historischekringheemskerk.nl`)
- [ ] Controleren dat iemand de rapportmails op `hkhadmin@` daadwerkelijk leest

`p=none` blijft voorlopig staan: eerst meten, nog niet blokkeren. Pas als de rapporten laten zien
dat alle legitieme post goed doorkomt, gaat het beleid naar `p=quarantine`. Andersom blokkeren we
onze eigen ledenadministratie.

Aan SPF en DKIM hoeft nu niets te gebeuren. Er volgt later een tweede ronde DNS-werk: bij het
inrichten van Laposta komen daar een DKIM-record van Laposta, een aanvulling op SPF en het
subdomein `nieuws.historischekringheemskerk.nl` bij. Dat staat in stap 2.

## 3. Stap 2 — Laposta inrichten

Laposta regelt de afmeldlink, de `List-Unsubscribe`-header die Gmail bovenaan de mail toont, en
de bounceverwerking. Dat hoeft niet zelf gebouwd te worden.

- [ ] Gratis account aanmaken op naam van de vereniging, niet op een privéadres van een vrijwilliger
- [ ] Verwerkersovereenkomst accepteren en opslaan in het bestuursarchief
- [ ] Afzender instellen op een bestaand, gelezen adres — geen `noreply@`
- [ ] Verzenddomein koppelen: het DKIM-record en de SPF-aanvulling van Laposta toevoegen
- [ ] Subdomein `nieuws.historischekringheemskerk.nl` aanmaken en als verzenddomein gebruiken
- [ ] Een tweede bestuurslid toegang geven

Het subdomein beschermt de gewone post: gaat er ooit iets mis met de verzendreputatie, dan raakt
dat niet de mail op `@historischekringheemskerk.nl` zelf.

Op het gratis account staat onderaan elke nieuwsbrief de regel "Deze e-mail is verzonden met het
nieuwsbriefprogramma Laposta". Wil het bestuur die weg, dan zijn mailcredits nodig — maar
daarmee vervalt het gratis account. Zie paragraaf 8.

## 4. Stap 3 — de ledenlijst opschonen

Dit is de belangrijkste maatregel tegen een blacklist. Een bouncepercentage boven ongeveer 3% bij
de eerste zending is precies waar Spamhaus en Microsoft op reageren. Werk van gratis naar betaald.

- [ ] Beginnen bij de ledenadministratie, niet bij de maillijst: wie heeft contributie 2026 betaald?
- [ ] Oud-leden verwijderen — opgezegd betekent geen relatie meer, en is ook AVG-dataminimalisatie
- [ ] Ontdubbelen
- [ ] Zichtbare typefouten eruit halen (`gmail.con`, `hotmai.com`, `@live.n`, spaties)
- [ ] Rol-adressen eruit (`info@`, `secretariaat@`, `webmaster@`) — dat zijn geen leden
- [ ] Lijst door een validatiedienst halen (Bouncer of ZeroBounce, circa €15 voor 1.600 adressen)
- [ ] `invalid` en `spamtrap` definitief weggooien
- [ ] `catch-all`-adressen apart zetten voor de laatste batch

Een validatiedienst doet een MX-check en een SMTP-handshake zonder een mail te versturen. Reken
erop dat van de 1.600 adressen er 1.300 tot 1.450 bruikbaar overblijven; dat is normaal.

## 5. Stap 4 — de nieuwsbrief bouwen

- [ ] Afmeldlink die met één klik werkt, zonder inloggen (Laposta zet deze standaard in)
- [ ] Volledige verenigingsnaam én fysiek postadres in de voettekst
- [ ] Onderwerpregel zonder hoofdletters en uitroeptekens
- [ ] Niet één grote afbeelding als hele nieuwsbrief; echte tekst, fatsoenlijke tekst-beeldverhouding
- [ ] Geen linkverkorters zoals bit.ly; direct naar `historischekringheemskerk.nl` linken
- [ ] Platte-tekstversie meesturen en nalezen
- [ ] Privacyverklaring op de website bijwerken

Klik- en openingsregistratie is verwerking van persoonsgegevens en moet in de privacyverklaring
benoemd staan. Wie zich niet kan afmelden drukt op "spam", en dat beschadigt de reputatie het
snelst.

## 6. Stap 5 — testen

- [ ] Testmail naar mail-tester.com; streven naar een 9 of hoger
- [ ] Testmail naar een Gmail-, een Outlook- én een Ziggo- of KPN-adres
- [ ] Controleren of Gmail bovenin een "Afmelden"-knop toont (dat is de `List-Unsubscribe`-header)
- [ ] Op een telefoon openen
- [ ] Alle links één voor één aanklikken
- [ ] Zelf een keer afmelden via de link, daarna in Laposta weer terugzetten
- [ ] Google Postmaster Tools activeren voor het domein

Staat die afmeldknop niet bovenin Gmail, dan is de domeinkoppeling uit stap 2 niet af.

## 7. Stap 6 en 7 — verzenden en nazorg

Een domein dat nog nooit nieuwsbrieven verstuurde en ineens 1.600 berichten uitspuugt, is per
definitie verdacht. Met 100 per dag wordt rustig reputatie opgebouwd en is er elke dag een moment
om te stoppen.

| Batch | Aantal | Bijzonderheid |
| --- | --- | --- |
| Dag 1 | 100 | Meest recente en actiefste leden |
| Dag 2 | 100 | Eerst de bounces van dag 1 bekijken |
| Dag 3 e.v. | 100 | Doorlopend, bounces blijven controleren |
| Laatste | rest | De apart gezette `catch-all`-adressen |

- [ ] Batch 1 samenstellen uit de meest recente en actiefste leden
- [ ] Na elke batch de bounces bekijken voordat de volgende de deur uit gaat
- [ ] Bij meer dan 3% bounces of enige spamklacht stoppen en uitzoeken
- [ ] Hard bounces direct verwijderen (Laposta doet dit automatisch — controleren dat het aanstaat)
- [ ] Soft bounces na drie keer verwijderen
- [ ] Afmeldingen doorgeven aan de ledenadministratie
- [ ] Na 2 à 3 nieuwsbrieven naar kliks kijken, niet naar opens
- [ ] Wie na een half jaar nooit klikte één re-engagement mail sturen, daarna op non-actief
- [ ] Na een paar schone DMARC-rapporten `p=none` naar `p=quarantine` zetten

Gmail hanteert een grens van 0,3% spamklachten. Bij 1.600 adressen zijn dat ongeveer vijf klachten.

Openingspercentages zijn onbruikbaar geworden door Apple Mail Privacy Protection: Apple opent elke
mail preventief, dus de statistiek toont fantoom-opens. Kliks zijn wel een echt signaal.

## 8. Juridische grondslag en kosten

De Telecommunicatiewet (art. 11.7) staat e-mail toe bij toestemming óf bij een bestaande relatie.
Leden vallen onder dat tweede: er is een lidmaatschapsrelatie, en een nieuwsbrief over de
activiteiten van de kring is "eigen gelijksoortige" communicatie. Aan de uitzondering hangen twee
voorwaarden waaraan stap 2 en 4 voldoen: bij elke verzending zit een afmeldmogelijkheid, en die is
gratis en eenvoudig.

Adressen die niet uit de ledenadministratie komen — oude deelnemerslijsten, visitekaartjes, van de
website geplukt — vallen hier niet onder en horen niet in de lijst. Eén klacht bij de ACM weegt
zwaarder dan honderd extra ontvangers.

| Post | Bedrag | Toelichting |
| --- | --- | --- |
| Laposta gratis account | €0 | Tot 2.000 relaties, 12.000 mailings per maand, met Laposta-regel |
| Adresvalidatie, eenmalig | ~€15 | De beste besteding in dit hele plan |
| DNS-wijzigingen | €0 | Zit in het bestaande ZXCS-pakket |
| Optioneel: 5.000 mailcredits | €125 excl. btw | Haalt de Laposta-regel weg, goed voor ~3 nieuwsbrieven |

Mailcredits verlopen nooit, wat het model geschikt maakt voor een kring die weinig verstuurt. Maar
het gratis account vervalt zodra credits worden gekocht; het is dus een of-of. Het advies is om de
eerste nieuwsbrief gratis te versturen — die is toch vooral een test — en daarna aan het bestuur
te vragen of die ene regel storend is.
