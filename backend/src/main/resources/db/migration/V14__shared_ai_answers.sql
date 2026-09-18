-- Een deelbare leesversie bevat uitsluitend de gekozen vraag en het afgeronde antwoord.
CREATE TABLE ai_answer_share (
    answer_id UUID PRIMARY KEY REFERENCES ai_search_turn(id) ON DELETE CASCADE,
    token UUID NOT NULL UNIQUE,
    question TEXT NOT NULL,
    title TEXT,
    answer_html TEXT NOT NULL,
    sources JSONB NOT NULL DEFAULT '[]',
    answered_at TIMESTAMPTZ,
    shared_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
