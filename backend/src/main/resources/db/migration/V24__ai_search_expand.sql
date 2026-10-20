-- Een antwoord van de pijplijn is begrensd (hoogstens tien alinea's). De schrijver meldt of er
-- meer te vertellen is; de gebruiker kan dan een uitwerkbeurt starten die dezelfde bronnen
-- opnieuw gebruikt en het korte antwoord als basis neemt.
ALTER TABLE ai_search_turn
    ADD COLUMN more_available BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN more_summary   TEXT,
    ADD COLUMN expands_turn_id UUID REFERENCES ai_search_turn (id) ON DELETE SET NULL;
CREATE INDEX ai_search_turn_expands_idx ON ai_search_turn (expands_turn_id) WHERE expands_turn_id IS NOT NULL;
