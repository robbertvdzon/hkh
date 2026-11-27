-- Stappen van een onderzoek zoals de bezoeker ze te zien krijgt ("Zoekt in het archief naar ...",
-- "42 archiefstukken gevonden", "De onderzoeker schrijft het antwoord"), met het moment erbij.
ALTER TABLE ai_search_turn ADD COLUMN steps JSONB;
