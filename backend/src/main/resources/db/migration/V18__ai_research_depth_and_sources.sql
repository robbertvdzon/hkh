-- Onderzoeksdiepte per vraag (Snel, Doorzoeken, Uitgebreid), gekozen door de gebruiker.
ALTER TABLE ai_search_turn ADD COLUMN research_depth VARCHAR(16) NOT NULL DEFAULT 'FAST';

-- De bronnenlijst met beschrijvingen en beelden staat voortaan los van de antwoordtekst, zodat de
-- app hem als aparte pagina kan tonen. Oudere antwoorden houden de lijst in answer_html.
ALTER TABLE ai_search_turn ADD COLUMN sources_html TEXT;
ALTER TABLE ai_answer_share ADD COLUMN sources_html TEXT;
