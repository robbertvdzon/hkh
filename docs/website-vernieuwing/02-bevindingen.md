# Bevindingen over de huidige website

Gerangschikt op wat bezoekers het meest raakt. Nummers tussen haakjes verwijzen naar screenshots.

## A. Structuur en vindbaarheid

1. **Alles zit achter een hamburgermenu, ook op desktop** (02). De homepage toont drie kaarten
   en twee tekstblokken, maar geen ingang naar agenda, collecties, educatie of werkgroepen.
   Een bezoeker moet raden dat "Activiteiten + Nieuws" de agenda bevat en "Publicaties" de
   kastelen.
2. **De vier hoofdmenu-items zijn klikbaar maar leeg** (13). `/nav-informatie/` en consorten
   tonen alleen een titel en de zijbalk. Wie op "Collecties" klikt in plaats van op een subitem
   belandt op een lege pagina.
3. **Educatie is drie klikken en een PDF diep** (11). Het lesaanbod, voor scholen de
   belangrijkste reden om de site te bezoeken, staat als één zin onder "Werkgroepen" met een link
   "hier" naar een PDF. Er is geen aanvraagmogelijkheid en geen contactpersoon per activiteit.
4. **Nieuws en agenda overlappen.** Acht van de zestien nieuwsberichten zijn kopieën van
   agenda-items. Het item "De verjaardag van Maerten" in het nieuws verwijst zelfs met een
   kale URL naar "de agenda elders in de website".
5. **Collecties en Geheugen zijn andere websites** (15, 20). Andere kleuren, andere navigatie,
   geen weg terug behalve de link "Homepage HKH". De sitezoekfunctie in de header doorzoekt deze
   inhoud niet (23).
6. **Dode en halve menu-items.** Onder Collecties → Exposities staan vier items zonder link
   (`#`). Onder Publicaties staat de kop "Heemskring" zonder enige inhoud. "Webshop" en "Links"
   staan zowel in het hoofdmenu als onder Collecties.
7. **Zijbalk en voet herhalen zich op elke pagina** (12): tien "overige berichten",
   contactknop, lid-worden-knop, daarna nog eens de drie homepage-kaarten en het contactformulier.
   Een pagina als "Werkgroepen" is daardoor twee keer zo lang als de eigenlijke inhoud.

## B. Agenda en aanmelden

8. **Aanmelden kan alleen per e-mail** (09). Elk evenement herhaalt de tekst "Opgeven bij
   opgeven@… max. 25 mensen. LET OP: uw opgave is pas definitief als u een bevestiging heeft
   gekregen". De vrijwilliger moet handmatig tellen, bevestigen en bij een volle zaal het
   evenement aanpassen ("LET OP: Deze dinsdagactiviteit is al volgeboekt!!"). Geen wachtlijst,
   geen afmelden, geen overzicht voor de organisator.
9. **Capaciteit, prijs en doelgroep zijn vrije tekst.** Soms staat "Gratis" als veld, soms
   "Kosten: €5,- Leden €3,50" in de tekst, soms niets. Niet filterbaar.
10. Sommige evenementen zijn van derden (Oer-IJ, Feestweek); dat is niet zichtbaar in de lijst.
11. Onder elke pagina staan knoppen "Vorig bericht" / "Volgend bericht" die in een
    willekeurige volgorde door álle pagina's lopen (Werkgroepen → Financiën → Openstelling …).
    Ze helpen niet bij navigeren en leiden naar pagina's die verder nergens gelinkt zijn
    (zie punt 17).

## C. Inhoudelijke slordigheden

12. **Contributie staat op drie plekken met drie bedragen:** € 18,75 (homepage), € 18,00
    (Over de HKH), € 17,50 (beleidsplan 2024).
13. De pagina Heemsstichting heeft als titel "historisch huis".
14. Webshopproduct "Ik wil een foto afgedrukt hebben" heeft als beschrijving "Voor straks: de
    complete beschrijving"; "Een wandeling door oud Heemskerk" heeft prijs "Moet nog worden
    vastgesteld".
15. Het magazine Heemskring, volgens de HKH zelf "het lijfblad", heeft geen plek: geen
    overzicht van nummers, geen inhoudsopgave, geen koppeling naar de artikelenbank. In het
    menu Publicaties staat alleen de kop "Heemskring" zonder link.
16. De PDF-bestandsnamen van nieuwsbrieven variëren (`Nieuwsbrief-95.pdf`,
    `130426_Nieuwsbrief-97_LR.pdf`).

### Opruimpunten: pagina's die bestaan maar niet via de site bereikbaar zijn

Bezoekers komen hier niet via het menu of de inhoud, dus dit zijn geen gebruiksproblemen. Ze
staan wel in de sitemap en kunnen via een zoekmachine opduiken (volledige lijst in
hoofdstuk 6 van de inventarisatie).

17. Vier pagina's zijn alleen bereikbaar via de "Vorig/Volgend bericht"-knoppen: een losse
    contactformulierpagina, een tweede "Juridische Disclaimer" (met de privacy/WBTR-tekst van
    de privacypagina), "Scholen (uit collecties)" met vultekst, en de testpagina
    "TEST – evenementen loop".
18. Zeven bestuurslid-detailpagina's zijn nergens gelinkt en bevatten alleen een naam. Hun
    URL-slugs verraden testitems: voorzitter Guus de Jonge staat op
    `/hkh-bestuurslid/kermit-de-kikker/`, verder `miss-piggy`, `gonzo` en `scooter`. Les voor
    de nieuwe site: geen publieke URL per bestuurslid, of een nette slug.
19. Vier nieuwsbrief-detailpagina's zijn nergens gelinkt; het overzicht linkt direct naar de
    PDF's.

## D. Wat goed werkt en behouden moet blijven

- De agenda-plugin levert nette evenementpagina's met kaart en kalender-abonnement.
- De verhalen (kastelen, Huldtoneel, Maerten van Heemskerck, Dorpskerk) zijn inhoudelijk rijk,
  met historische afbeeldingen; de kastelenkaart is een mooie ingang.
- Bestuurspagina met foto, telefoon, e-mail en motivatie per bestuurslid.
- Contactformulier met keuze van ontvanger.
- ANBI-informatie (financiën, beleidsplan, statuten-gerelateerde stukken) is compleet.
- De ZCBS-banken bevatten alle metadata die de nieuwe zoekpagina al toont.

## E. Conclusie

Het probleem is niet de hoeveelheid inhoud maar de indeling: de site is georganiseerd naar
**hoe de HKH intern is ingedeeld** (werkgroepen, publicaties, collecties) in plaats van naar
**wat een bezoeker komt doen** (iets bezoeken, iets opzoeken, iets lezen, iets aanvragen, lid
worden). Het structuurvoorstel in `03-voorstel-nieuwe-structuur.md` draait dat om.
