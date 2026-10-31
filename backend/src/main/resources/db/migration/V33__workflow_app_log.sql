-- App-log van de workflow-app: de logregels (INFO en hoger) van hkh-workflow, in pakketjes (chunks) opgestuurd.
-- Anders dan de sessies en inlogpogingen worden deze regels opgeruimd (standaard na 30 dagen, zie hkh.workflow-log.app-log-retention-days).
CREATE TABLE workflow_app_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    received_at TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    logged_at   TIMESTAMPTZ  NOT NULL,
    level       VARCHAR(10)  NOT NULL,
    logger      VARCHAR(200) NOT NULL DEFAULT '',
    message     TEXT         NOT NULL,
    source      VARCHAR(80)  NOT NULL,
    computer    VARCHAR(120) NOT NULL,
    app_version VARCHAR(80)
);
CREATE INDEX workflow_app_log_logged_idx ON workflow_app_log (logged_at DESC, id DESC);
CREATE INDEX workflow_app_log_source_computer_idx ON workflow_app_log (source, computer);
CREATE INDEX workflow_app_log_level_idx ON workflow_app_log (level);
CREATE INDEX workflow_app_log_version_idx ON workflow_app_log (app_version);

-- Welke pakketjes al zijn ontvangen, zodat een herhaling na een time-out niet dubbel wordt bewaard.
CREATE TABLE workflow_app_log_chunk (
    source      VARCHAR(80)  NOT NULL,
    computer    VARCHAR(120) NOT NULL,
    chunk_id    VARCHAR(120) NOT NULL,
    received_at TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (source, computer, chunk_id)
);
CREATE INDEX workflow_app_log_chunk_received_idx ON workflow_app_log_chunk (received_at);
