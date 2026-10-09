# Website-vernieuwing: onderzoek en structuurvoorstel

Onderzoek naar de huidige site https://www.historischekringheemskerk.nl/ (9 oktober 2026) en een
voorstel voor de indeling van de nieuwe site op basis van de HKH-app in deze repository.
Dit is bewust nog geen UX-ontwerp; eerst wordt de structuur vastgesteld.

| Bestand | Inhoud |
|---|---|
| [01-inventarisatie-huidige-website.md](01-inventarisatie-huidige-website.md) | techniek, menu, alle pagina's en functies van de huidige site |
| [02-bevindingen.md](02-bevindingen.md) | wat er onhandig, dubbel, leeg of fout is, en wat behouden moet blijven |
| [03-voorstel-nieuwe-structuur.md](03-voorstel-nieuwe-structuur.md) | nieuwe hoofdindeling (schema), per onderdeel, homepage-opbouw, mapping oud → nieuw, inschrijven met wachtlijst, educatie, beheer, open vragen |
| `screenshots/` | 23 schermafbeeldingen van de huidige site, genummerd in de volgorde van het onderzoek |
| [voorbeelden/](voorbeelden/README.md) | zes voorbeeldschermen van de nieuwe structuur (homepage, agenda, inschrijven, wachtlijst, educatie) als screenshot en als losse HTML-bestanden |
| [fase1-screenshots/](fase1-screenshots/README.md) | schermafbeeldingen van de gebouwde app met de vaste inhoud (fase 1) |
| [scripts/](scripts/README.md) | scripts die de inhoud van de oude site ophalen en omzetten naar `frontend/lib/content/generated_content.dart` |
| `bronnen/` | ruwe gegevens: alle URL's uit de sitemap, menustructuur, tabel met alle pagina's, gelinkte PDF's, het lesaanbod (PDF + tekst) en het beleidsplan |

## Hoe het onderzoek is gedaan

- Browser: homepage, menu, agenda, evenementpagina, werkgroepen, nav-pagina's, webshop,
  ZCBS-beeldbank, Over HKH, nieuwsbrieven, lid worden, Geheugen van Heemskerk, berichten,
  exposities en de sitezoekfunctie zijn bekeken en vastgelegd.
- Sitemap: alle 113 URL's uit de Yoast-sitemap zijn opgehaald en per pagina samengevat
  (titel, tekst, links, PDF's, embeds, formulieren).
- De zes ZCBS-beeldbanken en het Geheugen zijn apart opgehaald omdat ze buiten de sitemap vallen.
- De 13 gelinkte PDF's zijn gedownload; het lesaanbod en het beleidsplan zijn gelezen.

## Kern in drie zinnen

De huidige site is ingedeeld naar de interne organisatie van de HKH en verbergt alles achter een
hamburgermenu met lege tussenpagina's. Het voorstel kiest zes bezoekersdoelen als hoofdingangen
(Agenda, Nieuws, Ontdek Heemskerk, Collecties, Educatie, Vereniging) plus een knop Lid worden.
Nieuw zijn online inschrijven met wachtlijst, educatie als eigen onderdeel met aanvraagformulier,
en één zoekfunctie over pagina's en collecties.
