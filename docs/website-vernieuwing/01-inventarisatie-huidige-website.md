# Inventarisatie van de huidige website

Onderzocht op 9 oktober 2026 via de browser (alle hoofdschermen bekeken) plus een volledige
sitemap-crawl van alle 113 pagina's. Screenshots staan in `screenshots/`, ruwe gegevens in
`bronnen/`.

Hoofdstuk 4 beschrijft alleen de pagina's die een bezoeker al klikkend vanaf de homepage kan
bereiken (via het menu, de voet of links in de inhoud): 97 van de 113. De overige 16 pagina's
bestaan wel maar zijn niet of nauwelijks bereikbaar; die staan apart in hoofdstuk 6.

## 1. Techniek

| Onderdeel | Wat er draait |
|---|---|
| CMS | WordPress 7.1.3 met Elementor Pro 4.3.4 (thema Hello Elementor + child-thema "artbeving-theme") |
| Agenda | plugin The Events Calendar (`/evenementen/`, `/evenement/...`) |
| SEO | Yoast SEO (sitemap `sitemap_index.xml`), Google Site Kit |
| Eigen inhoudstypen | `hkh-bestuurslid`, `hkh-nieuwsbrief`, `hkh-product` (+ categorie boeken / foto's / wandelingen), `tribe_events` |
| Collecties (beeldbanken) | losstaand Perl/CGI-systeem **ZCBS 4.18q** van Gerard van Nes op `/cgi-bin/*.pl`, geheel eigen vormgeving |
| Geheugen van Heemskerk | statische HTML-site uit 2005-2010 op `/Geheugen/geheugen_index.html`, eigen vormgeving |
| Formulieren | Elementor Forms (contact-popup, contactpagina, lid-worden-wizard in 3 stappen) |
| Kaarten | Google Maps embeds (per evenement, kastelenkaart via My Maps) |
| Gebouwd door | reclamebureau ARTbeving (bericht "Vernieuwde website", live sinds ca. december 2025) |

De site bestaat dus feitelijk uit **drie losse werelden** met elk een eigen uiterlijk en navigatie:
de WordPress-site, de ZCBS-beeldbanken en het oude Geheugen van Heemskerk.

## 2. Navigatie zoals die nu is

Bovenbalk: logo, zoekveld (zoekt alleen in WordPress-pagina's en berichten, niet in de
collecties), YouTube / Instagram / Facebook, en een **hamburgermenu** (ook op desktop).
Het hamburgermenu opent zeven items, waarvan vier een uitklapbaar megamenu hebben.

```
Home
Informatie
  Algemeen ............ Over Heemskerk · Over Historische Kring Heemskerk
  Wie zijn wij? ....... Bestuursleden · Historisch Huis · Heemsstichting · Contactformulier (popup) · Lid worden
  ANBI ................ Financiën · Beleidsplan · Juridische disclaimer · Privacy + integriteitsregeling
Activiteiten + Nieuws
  Op onze locatie ..... Openstelling Historisch Huis · Werkgroepen
  Berichten ........... Alle berichten van de HKH
  Nieuwsbrieven ....... Overzicht nieuwsbrieven
  Agenda .............. Bekijk de HKH kalender
  (uitgelicht) ........ eerstvolgend evenement (nu: Lezing het Palmhoutwrak)
Publicaties
  Heemskring .......... (alleen een kop, geen link of tekst)
  Wetenswaardigheden .. Dorpskerk en kerkhof · Heemskerker ezels · Fort Veldhuis · Huldtoneel · Laurentiuskerk · Maerten van Heemskerck
  Kastelen ............ Alle kastelen op de kaart · De Vlotter · Marquette · 't Hoge Werfje · Poelenburg · Rietwijk/Reewijk · Assumburg · Beijerlust · Oud Haarlem · Meeresteijn
Collecties
  Beeldbanken ......... archief · foto's · bibliotheek · bidprentjes · artikelen · objecten  (alle zes naar ZCBS /cgi-bin)
  Exposities .......... exposities algemeen · man en paard benoemen (#) · agrarisch heemskerk (#) · deutzstraat · Gerrit van Assendelftstraat (#) · boerderijen (#)
  Geheugen ............ het geheugen van Heemskerk (oude statische site) · webshop · links
Webshop
Links
```

De menu-items "Informatie", "Activiteiten + Nieuws", "Publicaties" en "Collecties" linken zelf
naar pagina's `/nav-informatie/`, `/nav-activiteiten-nieuws/`, `/nav-publicaties/` en
`/nav-collecties/`. Dat zijn **lege stubpagina's** met alleen de titel en de standaard-zijbalk
(screenshot 13).

Footer: logo, socials, knop "Ik wil lid worden", bezoek- en postadres (A. Verherentstraat 5/2a,
1961 GD Heemskerk, telefoon (0251) 25 26 58), disclaimer en privacy.

## 3. Wat er op de homepage staat

1. Fotostrook (vijf historische foto's).
2. Titel "Historische Kring Heemskerk" met ezel-ornament.
3. Drie kaarten: **Nieuws** (nieuwste bericht), **Evenementen** (eerstvolgend evenement),
   **In de spotlight** (een webshopproduct).
4. Twee tekstblokken "Over Heemskerk" en "Over de Historische Kring Heemskerk" met "lees verder".
5. Blok "Lid worden?" (€ 18,75 per jaar) met knop.
6. Footer.

Er is geen ingang naar de collecties, de agenda als geheel, educatie of de werkgroepen op de
homepage; daarvoor moet het hamburgermenu open.

## 4. Alle inhoud, gegroepeerd per soort

### 4.1 Vereniging en organisatie (statische pagina's)

| Pagina | Inhoud |
|---|---|
| Over Historische Kring Heemskerk | ontstaan 1988, doel, 1850 leden, werkgroepen, Heemskring, Historisch Huis, exposities, contributie (hier € 18,00) |
| Over Heemskerk | ontstaansgeschiedenis van het dorp (strandwal, opgravingen, kastelen, tuinbouw) |
| HKH bestuursleden | 7 bestuursleden met foto, functie, telefoon, e-mail, "actief sinds", motivatie (Guus de Jonge voorzitter, Jan Bos, Joke Kranendonk, Klaas Pelgrim, Olga Lievers, Piet van Zwieten, Jan Daas) |
| Historisch Huis | geschiedenis van de St. Mariaschool (1920-1974) waarin de HKH zit |
| Openstelling Historisch Huis | maandagmiddag 14.00-16.00 uur; vragen, uitgifte, verkoop boeken/Heemskring, spullen inbrengen |
| Heemsstichting | stichting (1994) die monumentaal erfgoed veiligstelt; pagina heeft als titel "historisch huis" |
| Werkgroepen | 12 werkgroepen in één lap tekst: Objecten, Bibliotheek, **Educatie**, Exposities, Film/Video/Audio, Fotocollectie, Genealogie, Open Monumentendagen, Rondleidingen, Presentaties, Archief, Redactie Heemskring |
| Lid worden | 3-staps formulier: aanhef, voorletters, naam, adres, postcode, plaats, telefoon, e-mail, bankrekening, incasso-akkoord |
| Contactformulier (popup) | naam, e-mail, onderwerp, keuze ontvanger (voorzitter, secretaris, penningmeester, bezorging/ledenadministratie, webmaster), bericht, privacy-akkoord. Opent als popup vanuit het menu en de zijbalk; staat ook onderaan elke pagina |
| Financiën | tekst + 4 PDF's: financieel verslag 2023, overzicht 2024, overzicht 2025, begroting 2026 |
| Beleidsplan | samenvatting + PDF Beleidsplan 2024-2027 |
| Juridische disclaimer | auteursrecht op foto's, teksten en overige inhoud |
| Privacy- en integriteitsregeling | tekst + PDF privacyreglement + PDF integriteitsregeling |
| Links | 10 logo's: Museum Kennemerland, HG Midden-Kennemerland, Oud Castricum, Oud Uitgeest, HG Assendelft, HK Velsen, Stichting Oer-IJ, Aircraft Recovery Group 40-45, Gemeente Heemskerk, ARTbeving |

### 4.2 Agenda (The Events Calendar)

- Overzicht `/evenementen/` als lijst (ook maand/dag-weergave, zoekveld "Zoeken naar
  evenementen", knoppen vorige/volgende/vandaag), abonneren via Google Calendar, iCal, Outlook,
  .ics-export.
- 35 evenementen sinds januari 2026; de afgelopen zijn bereikbaar via de pijl "vorige" in de
  lijst (drie pagina's "Afgelopen evenementen"). Komende: Museumschuur Piet Diemeer
  (expositie gemeentehuis), Zoektocht Noorderveld, Lezing Palmhoutwrak, Lezing Cornelis
  Corneliszoon, Piet Paree (voorstelling in De Cirkel, kaarten via mail).
- Per evenement: titel, datum/tijd, afbeelding, tekst, organisator (bv. "WG
  vrijdagmiddagactiviteiten"), locatie met Google Maps, "toevoegen aan kalender".
- Vast ritme (uit beleidsplan): eerste en derde vrijdagmiddag en vierde dinsdagavond van de maand.
- **Aanmelden gaat per e-mail** naar `opgeven@historischekringheemskerk.nl`, meestal "max. 25
  mensen", met de waarschuwing dat de opgave pas definitief is na een bevestigingsmail. Voor een
  volgeboekte avond staat handmatig "LET OP: al volgeboekt!!" in de tekst.
- Soorten: lezingen, filmmiddagen, "Raad je straat", "Toen en Nu", wandelingen, exposities in het
  gemeentehuis, boekenmarkt, Open Monumentendagen, en activiteiten van derden (Stichting Oer-IJ,
  OerToer, Feestweek).

### 4.3 Nieuws en nieuwsbrieven

- `/alle-berichten-van-historische-kring-heemskerk/`: 16 berichten. Veel berichten zijn
  **kopieën van agenda-items** (Raad je straat, Films over de Hoogovens, Korte film ARFA, De tien
  kastelen, Verjaardag van Maerten, Fotowandeling, Tentoonstelling WO II, Burgemeester Nielen),
  enkele zijn echt nieuws (Neeltje Snijders-podcast, Etalage Kunstroute, Wateratlas, Vernieuwde
  website).
- Nieuwsbrieven: overzichtspagina met 4 ledennieuwsbrieven als PDF (94 t/m 97, twee per jaar,
  voor de ledenvergaderingen), elk met een korte inhoudsopgave en een downloadknop.
- Heemskring (het magazine, twee keer per jaar) heeft **geen eigen pagina**; alleen een kop in
  het menu, een vermelding in de webshop-categorie en de artikelen in de ZCBS-artikelenbank.

### 4.4 Verhalen over Heemskerk ("Publicaties")

- Wetenswaardigheden: Dorpskerk en kerkhof, Heemskerker ezels, Fort Veldhuis, Huldtoneel,
  Laurentiuskerk, Maerten van Heemskerck.
- Kastelen: kaartpagina (Google My Maps) + 9 kasteelpagina's.
- Exposities: inleidende pagina (verwijst naar fotoboeken in de bibliotheekbank, met PDF "25 jaar
  HKH – de panelen"), Expositie Deutzstraat (fotoreeks kapper Bekker). Vier menu-items zonder
  link.
- Geheugen van Heemskerk: index van honderden herinneringsverhalen (2005-2010) gefilterd op
  thema / buurt / auteur, in de oude statische site.

### 4.5 Collecties (ZCBS-beeldbanken)

| Bank | Aantal online | Zoekvelden |
|---|---|---|
| Archief | 1.788 publicaties (1.816 intranet) | titel/omschrijving, documentnummer, oorspronkelijk archief, plaats, periode, OCR-tekst |
| Foto's | 12.046 foto's | object nr., titel/beschrijving, straatnaam, map/album, fotograaf, wijk, thema, periode |
| Bibliotheek | 1.613 publicaties | boeknummer, titel, beschrijving, auteur, verschijningsjaar, genre |
| Bidprentjes | 1.338 | volgnummer, achternaam, geboren te, rustplaats, leeftijd, echtgeno(o)t(e), geboren op |
| Artikelen (Heemskring) | 523 | artikelnummer, titel, auteur, verschijningsjaar, OCR-tekst; artikelen jonger dan 5 jaar niet volledig |
| Objecten | 760 (1.626 intranet) | objectnummer, titel, thema, materiaal, periode |

Elke bank heeft zoekwijze (aaneengesloten / AND / OR), "woorddeel", "nieuw sinds week/maand/
kwartaal/jaar", galerij- of lijstweergave, sortering, en onderaan keuzelijsten per veld met
aantallen. Dit is precies de functionaliteit die de nieuwe testapp al in één zoekpagina
samenbrengt (zie `README.md` in de repo-root).

### 4.6 Webshop ("HKH producten")

Geen echte webshop: 4 producten (boeken "Honderd Jaar Laurentius", "Een stevige pleister op
m'n neus", "Een wandeling door oud Heemskerk", en "Ik wil een foto afgedrukt hebben") met
leden- en niet-ledenprijs en de tekst "Verkrijgbaar bij: het Historisch Huis". Categorieën
Heemskring, Boeken, DVD's, Foto's, Wandelingen, Fietsroutes staan wel in de filterbalk maar zijn
grotendeels leeg. Geen bestel- of betaalfunctie.

### 4.7 Educatie (het probleem uit de opdracht)

Het lesaanbod voor basisscholen is alleen te vinden via: hamburgermenu → Activiteiten + Nieuws →
Werkgroepen → scrollen naar "Werkgroep Educatie" → link "hier" → PDF `Lesaanbod-HKH.pdf`.
De PDF (maart 2026, zie `bronnen/Lesaanbod-HKH.txt`) bevat zes onderdelen met doelgroep,
kerndoelen, duur, aanmelding en kosten:

1. Rondleidingen kastelen Assumburg en Marquette (alle groepen, € 45 per groep, via Piet van Zwieten)
2. Presentatie "Heemskerk in oorlogstijd 1940-1945" (groep 8, gratis, via Wim Smeels)
3. Historische wandelingen rondom scholen (groep 7/8, gratis, scholen voeren zelf uit)
4. Lesprogramma "Beroemd als Maerten" (groep 7/8, € 65 per groep, aanmelden via Cultuurhuis Heemskerk)
5. Workshops monumentenkist / archeologie / familiegeschiedenis (in herziening)
6. Jaarlijkse activiteit rond de geboortedag van Maerten van Heemskerck

Nieuwsbrief 97 meldt dat de werkgroep educatie plannen heeft voor schooljaar 2026-2027. Nergens
op de site staat een aanvraagformulier of een vast contactpunt voor scholen.

## 5. Wat een bezoeker nu kan dóen

| Actie | Hoe | Opmerking |
|---|---|---|
| Agenda bekijken en abonneren | /evenementen, iCal/Google/Outlook | werkt goed |
| Aanmelden voor een activiteit | e-mail sturen naar opgeven@ | handmatig, geen capaciteit/wachtlijst, bevestiging per mail |
| Lid worden | 3-staps formulier incl. bankrekening en incasso-akkoord | alleen formulier, geen online betaling |
| Contact opnemen | popup/formulier met keuze ontvanger | ook telefoon en bezoekadres in footer |
| Zoeken in collecties | zes aparte ZCBS-banken | andere vormgeving, geen gecombineerd zoeken |
| Zoeken op de site | zoekveld in header | doorzoekt alleen WordPress-inhoud |
| Nieuwsbrieven en jaarstukken lezen | PDF-downloads | |
| Boek kopen / foto bestellen | pagina bekijken, dan langsgaan op maandagmiddag | geen bestelfunctie |
| Lesaanbod bekijken | PDF via werkgroepenpagina | geen aanvraag, geen pagina per onderdeel |
| Herinneringsverhalen lezen | Geheugen van Heemskerk | oude site |
| Volgen via social media | YouTube, Instagram, Facebook-groep | |

## 6. Pagina's die bestaan maar niet via de site bereikbaar zijn

Deze 16 pagina's staan in de sitemap (en dus in zoekmachines) maar een bezoeker komt er niet
door vanaf de homepage te klikken. Ze horen niet bij de structuur van de site en vervallen in
het voorstel; ze staan hier alleen voor de volledigheid en als opruimpunten.

**Alleen bereikbaar via de knoppen "Vorig bericht" / "Volgend bericht"** die onder elke
pagina staan en in een willekeurige volgorde door alle pagina's heen lopen:

| Pagina | Wat erop staat |
|---|---|
| `/contact-formulier/` | hetzelfde contactformulier als de popup, als losse pagina |
| `/juridische-disclaimer-2/` | tweede pagina "Juridische Disclaimer" met de privacy/WBTR-tekst van de pagina Privacy- en integriteitsregeling |
| `/scholen-uit-collecties/` | vultekst ("Hier komt de inhoud van de pagina die de HKH zelf gaat bedenken…") |
| `/test-evenementen-loop/` | testpagina "TEST – evenementen loop" van de bouwer |

**Nergens gelinkt:**

| Pagina's | Wat erop staat |
|---|---|
| `/hkh-bestuurslid/…/` (7 stuks, o.a. `kermit-de-kikker`, `miss-piggy`, `gonzo`, `scooter`) | detailpagina per bestuurslid met alleen de naam; de inhoud staat op de bestuurspagina |
| `/hkh-nieuwsbrief/…/` (4 stuks) | detailpagina per nieuwsbrief met dezelfde korte inhoudsopgave als het overzicht, zonder PDF-link |
