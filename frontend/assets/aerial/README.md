# Luchtfoto Heemskerk

## Huidige vergelijking: schuine luchtfoto's rond de Dorpskerk

De viewer gebruikt de twee op 4 oktober 2026 door Robbert gekozen foto's:

- `heemskerk-62057-toen.png` (1370 × 1116): de ongewijzigde aangeleverde
  historische foto, rond 1963. De oorspronkelijke boekfoto 62057 blijft
  beschikbaar onder `book/1963-62057.jpeg`.
- `heemskerk-62057-nu-ai.png` (1390 × 1132): de AI-bewerking
  `heemskerk-62057-oude-kijkhoek-ai.png`, gemaakt met de ingebouwde imagegen-tool
  uit Robberts Google Earth-opname en de historische foto als kijkhoekreferentie.
  Het bestand is ongewijzigd overgenomen. De moderne bronopname is niet bewezen
  uit 2026; de gebruiker ziet daarom geen jaartal bij 'Nu'. Bebouwing en andere
  details kunnen door de AI-bewerking afwijken van de werkelijke situatie.

`lib/aerial/aerial_photo_alignment.dart` legt de geometrische uitlijning vast.
De historische foto bepaalt het beeldvlak. De moderne foto krijgt een vaste
transformatie op herkenbare punten van de Dorpskerk. De bronpixels blijven
intact: Flutter past deze transformatie bij het tekenen toe. De viewer toont
alleen de gezamenlijke rechthoekige uitsnede, zodat beide lagen alle hoeken
bedekken. Eén gedeelde zoom-/verplaatsingstransformatie houdt de kerk ook
tijdens het overvloeien op dezelfde schermpositie.

De vaste kerkpunten (moderne bronpixel → historische bronpixel) zijn:

- torenspits: `(738,182) → (745,194)`;
- voet van de toren bij het schip: `(740,359) → (755,370)`;
- rechter dakrand: `(800,342) → (841,345)`.

De gemeenschappelijke uitsnede is `(0,82)–(1370,1085)` in de historische foto:
1370 × 1003 pixels. De gekozen punten vallen rekenkundig exact samen;
handmatig aanwijzen in de bronbeelden blijft beperkt tot ongeveer 1–2 pixels.

De uitlijning van de omgeving is bij benadering. Verschillen in perspectief,
bebouwing, bomen en AI-reconstructie maken volledige pixelovereenkomst van
de hele wijk onmogelijk. De bronviewer blijft de zeven ongewijzigde boekfoto's
tonen; alleen 62057 is de historische bron van deze vergelijking.

## Eerdere kaartvergelijking (niet meer gebundeld in de app)

De eerdere vergelijking gebruikte twee beelden van 2040 × 1120 pixels met dezelfde
uitsnede, schaal en oriëntatie: noord boven, 5 meter per pixel, RD / EPSG:28992,
begrenzing `[99600, 500000, 109800, 505600]`. De worldfiles zijn identiek.
Onbekende historische gebieden zijn volledig wit; de historische afbeelding
mag niet door een transparante laag worden vervangen.

- `heemskerk-2026.jpg`: ongewijzigde download uit de openbare
  [PDOK-luchtfotolaag](https://service.pdok.nl/hwh/luchtfotorgb/wms/v1_0?SERVICE=WMS&REQUEST=GetCapabilities)
  `2026_orthoHR`, PDOK / Beeldmateriaal, CC BY 4.0. De exacte lokale vluchtdag
  is niet vastgesteld.
- `heemskerk-1962-1965.png`: circa 0,45 km² aan gecontroleerde historische
  fragmenten, samengesteld uit vier boekfoto’s en een bestaande archiefopname.
- `book/`: alle zeven ongewijzigde aangeleverde boekfoto’s. De bronviewer toonde
  het jaartal uit het boek en vermeldde of een foto deels op de kaart stond.

| Boek | Boekjaar | HKH-object | Gebruik |
| --- | --- | --- | --- |
| 62057 | 1963 | [10903](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10903) | Beperkt grondvlak Zaalberglaan / Poelenburglaan / Bonckenburchstraat |
| 62058 | 1963 | [10904](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10904) | Beperkt grondvlak Dorpskerk / Ruysdaelstraat / Zaalberglaan |
| 62059 | 1963 | [10902](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10902) | Bronviewer; Laurentiuskerk / Dr. Prinsenhal nog niet betrouwbaar uitgelijnd |
| 64797 | 1964 | [10905](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10905) | Gecontroleerd overzicht tot de Neksloot; meer bronpixels dan de kleine archiefscan |
| 67781 | 1965 | Geen exacte match gevonden | Beperkt grondvlak van centrum naar Mariakerk / Kerkbeek |
| 67782 | 1965 | Geen exacte match gevonden | Bronviewer; Assumburg nog niet betrouwbaar uitgelijnd |
| 67783 | 1965 | [10941](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10941) | Bronviewer; Tolweg / Hoflaan nog niet betrouwbaar uitgelijnd |

HKH dateert 10902, 10903 en 10904 op 1962, het boek op 1963. Beide dateringen
zijn bewaard. Op verzoek zijn de foto’s uit 1965 toegestaan; de vergelijking
heet daarom 1962–1965 en stelt geen enkel opnamemoment voor.
De bestaande archiefopname [12309](https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/12309)
(1963) levert daarnaast het afzonderlijke fragment bij Oud Haerlem.

Alleen herkende grondpunten en hun beperkte omtrek zijn gebruikt. De plaatsing
is indicatief: ongeveer 10–40 meter afhankelijk van de bron, zonder bewezen
uniforme foutgrens. Gebouwen en bomen houden door hun hoogte verschuivingen;
boekbolling, glans en drukraster blijven zichtbaar. Interne fitfouten en
leave-one-out-controles zijn geen landmeetkundige nauwkeurigheidsmetingen.
Het historische beeld is gedeeltelijk, heeft zichtbare naden en is geen exacte
orthofoto. Gebieden zonder betrouwbare plaatsing blijven wit.

Voor de eerdere kaart is geen generatieve AI, inpainting of invulling met moderne beelden gebruikt.
De verwerking bestaat uit grijsconversie, geometrische projectie en bilineaire
interpolatie van bestaande bronpixels. `provenance.json` bewaart dateringen,
controlepunten, beoordelingen, projecties, maskers en hashes. Bronmaskerwaarde
60001 is een interne code voor boekfoto 67781 en geen HKH-objectnummer.

De afzonderlijke originelen en het volledige eerdere onderzoek staan lokaal in
`hkh-luchtfoto-1963/boekfotos`; de reproduceerbare rasterpipeline staat in
`hkh-luchtfoto-1963/uitlijning`. De bronviewer is beschikbaar vanuit Luchtfoto;
de eerdere kaartbestanden, worldfiles en `provenance.json` blijven bewaard voor
herleidbaarheid, maar worden niet meer geladen door de vergelijkingsviewer.
