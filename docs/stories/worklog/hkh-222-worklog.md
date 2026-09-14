# hkh-222 — Homepage, appbalk, widgettests en functionele documentatie

## Plan

- [x] Repository-instructies, bestaande homepage/tests en UX-01 t/m UX-10 lezen.
- [x] Hero, AI-vraagkaart en neutrale collectiekaart volgens de vastgelegde
  teksten, kleuren, hiërarchie en afrondingen implementeren.
- [x] Zoektips en Uitgebreid zoeken onafhankelijk en standaard ingeklapt maken.
- [x] De inclusieve 600px-grens, 320px/200%-tekstschaling en brede verticale
  ritmiek implementeren.
- [x] Mijn dossiers uit het accountmenu naar een eigen responsieve appbalkactie
  verplaatsen.
- [x] Homepage-widgettests en `docs/factory/functional-spec.md` bijwerken.
- [x] Gerichte analyse, volledige frontend-tests en diffcontrole uitvoeren.

## Gerealiseerd

- `frontend/lib/main.dart` gebruikt `#FBF6EE` als homepage-achtergrond, bevat
  geen hero-archiefpictogram meer en toont de voorgeschreven hero- en AI-teksten.
  De AI-route staat als groene, dominante kaart vóór de omrande collectiezoeker.
- De AI- en collectievelden hebben zichtbare labels. De enige gevulde actie in
  de homepage-inhoud is Vraag stellen; Zoeken is omrand. Kaarten gebruiken 16 px
  en velden, knoppen, focus- en foutkaders 10 px afronding.
- Zoektips en Uitgebreid zoeken hebben afzonderlijke state en starten beide
  ingeklapt. De bestaande zoeksyntaxtekst is letterlijk behouden.
- Tot en met 600 px stapelen velden en knoppen; de knoppen zijn volle breedte.
  Boven 600 px staan ze naast elkaar. De appbalk en inhoud zijn bestand tegen
  320 px met 200% tekstschaling.
- Een collectiezoekfout toont een begrijpelijke live melding en behoudt de
  ingevoerde zoekwaarden. Resultaten, lege toestand en doornavigatie gebruiken
  de bestaande datasource en routes.
- Ingelogde gebruikers hebben Mijn dossiers als losse appbalkactie: boven
  600 px met icoon en label, tot en met 600 px als icoon met tooltip en
  toegankelijke naam. Het accountmenu bevat alleen Uitloggen.
- `frontend/test/widget_test.dart` dekt breed/smal, beide AI-startvarianten,
  Eerdere vragen, gewoon/uitgebreid collectiezoeken, beide disclosures,
  resultaten/leeg/fout, doornavigatie, 320 px met 200% tekst en beide ingelogde
  appbalkvarianten.
- `docs/factory/functional-spec.md` beschrijft de gerealiseerde interface en
  bevat de exacte zichtbare teksten en Zoektips-inhoud.

## Verificatie

- `flutter analyze` in `frontend/`: geen issues.
- `flutter test test/widget_test.dart --reporter github`: 13 tests geslaagd.
- `flutter test --reporter github` in `frontend/`: 43 tests geslaagd.
- `git diff --check`: geen whitespacefouten.
- Geen `pubspec.lock`-churn ontstaan.

## Niet gedaan / aangepast

- Geen AI-, collectie-, authenticatie-, dossier- of backendlogica en geen
  bestaande routes gewijzigd.
- Backend en `frontend-admin/` zijn niet aangepast; het volledige factory-vangnet
  wordt aansluitend door de Runtime-worker uitgevoerd.
