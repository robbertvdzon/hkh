-- Onderzoekslogboek: de agent meldt na iedere zoekronde zijn stand (bronnen, gevonden, volgende sporen)
-- via een POST op een per-vraag geheime URL; in het antwoord daarop krijgt hij de bijsturing van de
-- gebruiker terug (stop en schrijf, of een aanwijzing voor de volgende ronde).
ALTER TABLE ai_search_turn
    ADD COLUMN research_log JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN control_token VARCHAR(64),
    ADD COLUMN steer_stop BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN steer_hint VARCHAR(500),
    ADD COLUMN steer_delivered_at TIMESTAMPTZ;

CREATE INDEX ai_search_turn_control_idx ON ai_search_turn (control_token) WHERE control_token IS NOT NULL;
