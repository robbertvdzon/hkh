CREATE TABLE dossier (
    id                    UUID PRIMARY KEY,
    owner_user_id         UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    title                 VARCHAR(200) NOT NULL,
    goal                  VARCHAR(2000) NOT NULL DEFAULT '',
    fact_sheet_md         TEXT NOT NULL DEFAULT '',
    fact_sheet_status     VARCHAR(16) NOT NULL DEFAULT 'IDLE',
    fact_sheet_job_id     VARCHAR(80),
    fact_sheet_dirty      BOOLEAN NOT NULL DEFAULT FALSE,
    fact_sheet_error      VARCHAR(1000),
    fact_sheet_updated_at TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX dossier_owner_idx ON dossier (owner_user_id);

-- Leden staan op e-mailadres zodat iemand uitgenodigd kan worden die nog nooit heeft ingelogd.
CREATE TABLE dossier_member (
    dossier_id         UUID NOT NULL REFERENCES dossier(id) ON DELETE CASCADE,
    user_email         VARCHAR(320) NOT NULL,
    role               VARCHAR(16) NOT NULL,
    invited_by_user_id UUID REFERENCES app_user(id) ON DELETE SET NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (dossier_id, user_email)
);

CREATE INDEX dossier_member_email_idx ON dossier_member (user_email);

-- Vragen in een dossier zijn gewone AI-zoekopdrachten zonder bezoekerscookie.
ALTER TABLE ai_search_session ALTER COLUMN visitor_id DROP NOT NULL;
ALTER TABLE ai_search_session ADD COLUMN dossier_id UUID REFERENCES dossier(id) ON DELETE CASCADE;
ALTER TABLE ai_search_session ADD COLUMN user_id UUID REFERENCES app_user(id) ON DELETE SET NULL;
ALTER TABLE ai_search_session ADD COLUMN created_by_email VARCHAR(320);

CREATE INDEX ai_search_session_dossier_idx ON ai_search_session (dossier_id, created_at DESC);

ALTER TABLE ai_search_turn ADD COLUMN dossier_context TEXT;

CREATE TABLE article (
    id                 UUID PRIMARY KEY,
    dossier_id         UUID NOT NULL REFERENCES dossier(id) ON DELETE CASCADE,
    title              VARCHAR(200) NOT NULL,
    created_by_email   VARCHAR(320),
    current_version_id UUID,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX article_dossier_idx ON article (dossier_id, updated_at DESC);

CREATE TABLE article_version (
    id                   UUID PRIMARY KEY,
    article_id           UUID NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    version_number       INTEGER NOT NULL,
    title                VARCHAR(200) NOT NULL,
    content_md           TEXT NOT NULL DEFAULT '',
    author_kind          VARCHAR(8) NOT NULL,
    author_email         VARCHAR(320),
    ai_instruction       TEXT,
    change_summary       VARCHAR(1000),
    state                VARCHAR(12) NOT NULL,
    based_on_version_id  UUID REFERENCES article_version(id) ON DELETE SET NULL,
    runtime_job_id       VARCHAR(80),
    job_status           VARCHAR(16),
    progress_message     VARCHAR(500),
    error_message        VARCHAR(1000),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_at           TIMESTAMPTZ,
    decided_by_email     VARCHAR(320),
    CONSTRAINT article_version_number_unique UNIQUE (article_id, version_number)
);

ALTER TABLE article ADD CONSTRAINT article_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES article_version(id) ON DELETE SET NULL;

CREATE INDEX article_version_job_idx ON article_version (job_status)
    WHERE job_status IN ('SUBMITTING', 'RUNNING');
