ALTER TABLE ai_search_session ADD COLUMN visitor_id UUID;

-- Bestaande onderzoeken hadden nog geen browseridentiteit. Ze krijgen een
-- niet-raadbare eigenaar, zodat ze niet per ongeluk bij een nieuwe bezoeker
-- zichtbaar worden.
UPDATE ai_search_session SET visitor_id = id WHERE visitor_id IS NULL;

ALTER TABLE ai_search_session ALTER COLUMN visitor_id SET NOT NULL;

CREATE INDEX ai_search_session_visitor_idx
    ON ai_search_session (visitor_id, created_at DESC);
