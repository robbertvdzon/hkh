-- Wijzigingen in de instellingen van de workflow-app: bij elke keer dat iemand de instellingen opslaat meldt hkh-workflow wie, waarom,
-- welke velden (oud en nieuw) en de volledige nieuwe instellingen. Het zijn er weinig; ze worden niet opgeruimd.
CREATE TABLE workflow_settings_change (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source      VARCHAR(80)  NOT NULL,
    computer    VARCHAR(120) NOT NULL,
    app_version VARCHAR(80),
    user_name   VARCHAR(200),
    address     VARCHAR(64),
    reason      VARCHAR(200) NOT NULL,
    changes     JSONB        NOT NULL DEFAULT '[]'::jsonb,
    settings    JSONB        NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX workflow_settings_change_created_idx ON workflow_settings_change (created_at DESC, id DESC);
CREATE INDEX workflow_settings_change_source_idx ON workflow_settings_change (source);
