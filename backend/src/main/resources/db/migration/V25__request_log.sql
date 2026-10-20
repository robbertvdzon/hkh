-- Logboek van alle verzoeken aan de site: AI-vragen (en hun uitwerkingen) en zoekopdrachten in de
-- collecties. Voor beheer: wie vroeg wat, hoe snel kwam de eerste terugkoppeling en het antwoord,
-- welk model en wat kostte het.
CREATE TABLE request_log (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    kind              VARCHAR(30)  NOT NULL,
    ip                VARCHAR(64),
    user_email        VARCHAR(320),
    question          TEXT         NOT NULL,
    collection        VARCHAR(40),
    reference         VARCHAR(64),
    expansion         BOOLEAN      NOT NULL DEFAULT FALSE,
    model             VARCHAR(200),
    status            VARCHAR(20)  NOT NULL DEFAULT 'RUNNING',
    first_feedback_ms INTEGER,
    answer_ms         INTEGER,
    cost_usd          NUMERIC(10, 4)
);
CREATE INDEX request_log_created_idx ON request_log (created_at DESC);
CREATE INDEX request_log_reference_idx ON request_log (reference) WHERE reference IS NOT NULL;
