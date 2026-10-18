-- Onderzoeksmethode per vraag: AGENT (de agent zoekt zelf via de REST-API) of PIPELINE (de code
-- bestuurt de rondes; het model beoordeelt kaarten en schrijft). Vastgelegd bij het stellen, zodat
-- een vraag consistent wordt afgehandeld als de beheerder tussendoor wisselt. research_stats
-- bewaart jobs, modellen en tokens per vraag voor de vergelijking tussen methodes en modellen.
ALTER TABLE ai_search_turn
    ADD COLUMN research_method VARCHAR(20) NOT NULL DEFAULT 'AGENT',
    ADD COLUMN research_stats JSONB;
