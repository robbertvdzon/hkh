-- Workflow-logboek: de Windows-app hkh-workflow meldt hier elke inlogpoging en elke stap van een doorloop
-- (nieuwe bestanden in ZCBS zetten, of records aanpassen). Per sessie (uuid) staat de laatst ontvangen
-- volledige momentopname, plus een korte tijdlijn van de stappen.
CREATE TABLE workflow_login (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_name   VARCHAR(200),
    success     BOOLEAN      NOT NULL,
    method      VARCHAR(20)  NOT NULL,
    detail      VARCHAR(300),
    app_version VARCHAR(80),
    computer    VARCHAR(120),
    ip          VARCHAR(64)
);
CREATE INDEX workflow_login_created_idx ON workflow_login (created_at DESC);

CREATE TABLE workflow_session (
    id          UUID PRIMARY KEY,
    kind        VARCHAR(20)  NOT NULL,
    secret_hash VARCHAR(64)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_name   VARCHAR(200),
    collection  VARCHAR(80),
    phase       INTEGER      NOT NULL DEFAULT 0,
    phase_count INTEGER      NOT NULL DEFAULT 0,
    phase_label VARCHAR(120),
    status      VARCHAR(20)  NOT NULL DEFAULT 'RUNNING',
    file_count  INTEGER      NOT NULL DEFAULT 0,
    app_version VARCHAR(80),
    computer    VARCHAR(120),
    ip          VARCHAR(64),
    updates     INTEGER      NOT NULL DEFAULT 1,
    snapshot    JSONB        NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX workflow_session_kind_created_idx ON workflow_session (kind, created_at DESC);

CREATE TABLE workflow_session_event (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id  UUID         NOT NULL REFERENCES workflow_session (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    phase       INTEGER      NOT NULL DEFAULT 0,
    phase_label VARCHAR(120),
    status      VARCHAR(20)  NOT NULL,
    message     VARCHAR(500) NOT NULL
);
CREATE INDEX workflow_session_event_session_idx ON workflow_session_event (session_id, id);
