# Luchtfoto Heemskerk

De pagina gebruikt twee beelden met hetzelfde raster: 2040 × 1120 pixels,
noord boven, 5 meter per pixel, RD / EPSG:28992. De uitsnede is
`[99600, 500000, 109800, 505600]` (xmin, ymin, xmax, ymax). De worldfiles
zijn identiek. De PNG heeft een volledig witte achtergrond voor onbekende
historische gebieden; gebruik hiervoor geen transparante versie over de
actuele foto.

- `heemskerk-2026.jpg`: ongewijzigde download van de openbare
  [PDOK-luchtfotolaag](https://service.pdok.nl/hwh/luchtfotorgb/wms/v1_0?SERVICE=WMS&REQUEST=GetCapabilities),
  laag `2026_orthoHR`. PDOK / Beeldmateriaal, CC BY 4.0.
  Het jaartal betreft de bronlaag; de lokale vluchtdag is niet vastgesteld.
- `heemskerk-1962-1964.png`: geometrisch geplaatste delen van HKH-objecten
  [10905](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10905) (circa 1964,
  beschrijving 1963–1964) en
  [12309](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/12309) (1963).
  Historische Kring Heemskerk. Ongeveer 0,39 km² is ingevuld.

Dit is een eerste, gedeeltelijke uitlijning van kleine, schuine archieffoto's.
Het brede overzicht heeft een indicatieve plaatsingsonzekerheid van enkele
tientallen meters (ongeveer 20–40 m, geen gegarandeerde foutgrens). Voor Oud
Haerlem is de interne controle circa 6 m RMS; dit is geen landmeetkundige
nauwkeurigheidsmeting. Hoge objecten kunnen bij overvloeien verschuiven.

Wit betekent dat er geen beschikbaar of voldoende betrouwbaar geplaatst
historisch beeld is. Er zijn geen gebieden gegenereerd, met actuele beelden
aangevuld of ingekleurd. De oorspronkelijke archiefpixels zijn alleen met een
projectieve transformatie en bilineaire resampling op het raster gezet. De
slider toont daarom **Rond 1963** en vermeldt de bronperiode 1962–1964.

`provenance.json` legt bron-URL's, hashes, plaatsing en controlegegevens vast.
Alleen de twee afbeeldingen zijn Flutter-assets; de documentatie en worldfiles
dienen voor onderhoud. Houd bij vervanging het gedeelde raster en de witte
historische achtergrond in stand.
