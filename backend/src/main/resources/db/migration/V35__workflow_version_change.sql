-- Een andere versie van de workflow-app: bij het opstarten meldt hkh-workflow dat hij met een andere versie draait dan de vorige keer
-- (bijgewerkt, of de vorige versie teruggezet). Zo is te zien wanneer een server is bijgewerkt. Het zijn er weinig; ze worden niet opgeruimd.
CREATE TABLE workflow_version_change (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source           VARCHAR(80)  NOT NULL,
    computer         VARCHAR(120) NOT NULL,
    previous_version VARCHAR(120) NOT NULL,
    current_version  VARCHAR(120) NOT NULL,
    reason           VARCHAR(200) NOT NULL
);
CREATE INDEX workflow_version_change_created_idx ON workflow_version_change (created_at DESC, id DESC);
CREATE INDEX workflow_version_change_source_idx ON workflow_version_change (source);
