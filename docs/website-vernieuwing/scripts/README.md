# Scripts voor de vaste inhoud (fase 1)

1. `extract.py` haalt alle pagina's uit `bronnen/alle-urls-uit-sitemap.txt` op van de oude site
   en schrijft `content.json` (tekstblokken, foto's, agendagegevens per pagina). Draai het in een
   lege werkmap met een kopie van de URL-lijst als `urls.txt`.
2. `generate_dart.py <doel>` zet `content.json` en `bestuur.json` om in
   `frontend/lib/content/generated_content.dart`. De voorbeeldwaarden voor inschrijvingen,
   prijzen en partneractiviteiten staan bovenin het script.

3. `extract_geheugen.py` haalt de index en alle verhalen van het Geheugen van Heemskerk op naar
   `geheugen.json`; `generate_memory_dart.py <doel>` zet die om in
   `frontend/lib/content/generated_memory.dart`.

De scripts zijn alleen nodig om de inhoud opnieuw van de oude site over te nemen; in fase 2
vervangt de backend de gegenereerde lijsten.
