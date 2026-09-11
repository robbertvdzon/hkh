-- Eenmalige opruiming: een vorige versie van de "toon alles"-zoekopdracht was per ongeluk
-- dubbel URL-gecodeerd, waardoor de HKH-server 0 echte resultaten teruggaf en de scraper het
-- sluitende "<!-- ZCBS-LIST -->"-paginamarkeringen aanzag voor een record (ident "ZCBS-LIST",
-- titel "Helaas..."). Dat ident wordt niet meer geproduceerd, dus deze rommelrecords worden
-- nooit meer overschreven door een volgende scrape - ze worden hier eenmalig verwijderd.
DELETE FROM collection_item WHERE ident = 'ZCBS-LIST';
