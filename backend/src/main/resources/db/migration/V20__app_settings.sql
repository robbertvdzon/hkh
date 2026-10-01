-- Instellingen die een beheerder in de app wijzigt zonder uitrol, zoals het AI-model van de
-- digitale onderzoeker. Eén rij per sleutel; de waarde is JSON.
CREATE TABLE app_setting (
    key        VARCHAR(80)  PRIMARY KEY,
    value      TEXT         NOT NULL,
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(320)
);
