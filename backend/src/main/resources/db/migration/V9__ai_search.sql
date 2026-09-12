CREATE TABLE ai_search_session (
    id          UUID PRIMARY KEY,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ai_search_turn (
    id                    UUID PRIMARY KEY,
    session_id            UUID NOT NULL REFERENCES ai_search_session(id) ON DELETE CASCADE,
    turn_number           INTEGER NOT NULL,
    question              VARCHAR(1000) NOT NULL,
    runtime_job_id        VARCHAR(80),
    status                VARCHAR(24) NOT NULL,
    progress_percent      INTEGER,
    progress_message      VARCHAR(500),
    title                 VARCHAR(500),
    answer_html           TEXT,
    sources               JSONB NOT NULL DEFAULT '[]'::jsonb,
    suggested_follow_ups  JSONB NOT NULL DEFAULT '[]'::jsonb,
    error_message         VARCHAR(1000),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at          TIMESTAMPTZ,
    CONSTRAINT ai_search_turn_number_unique UNIQUE (session_id, turn_number)
);

CREATE INDEX ai_search_turn_session_idx ON ai_search_turn (session_id, turn_number);
CREATE INDEX ai_search_turn_status_idx ON ai_search_turn (status) WHERE status IN ('SUBMITTING', 'QUEUED', 'RUNNING');
