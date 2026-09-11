-- ZCBS collectie-items, gescrapet uit de publieke beeldbanken van de HKH-website.
-- Alleen metadata + verwijzingen naar beeld/PDF; de bestanden zelf blijven op de HKH-webserver.

CREATE TABLE collection_item (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    collection     VARCHAR(40)  NOT NULL,
    ident          VARCHAR(64)  NOT NULL,
    title          TEXT         NOT NULL DEFAULT '',
    description    TEXT         NOT NULL DEFAULT '',
    year           INTEGER,
    image_url      TEXT,
    pdf_url        TEXT,
    detail_url     TEXT         NOT NULL,
    fields         JSONB        NOT NULL DEFAULT '{}'::jsonb,
    search_text    TEXT         NOT NULL DEFAULT '',
    search_vector  tsvector GENERATED ALWAYS AS (to_tsvector('dutch'::regconfig, search_text)) STORED,
    scraped_at     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT collection_item_unique UNIQUE (collection, ident)
);

CREATE INDEX collection_item_search_idx ON collection_item USING GIN (search_vector);
CREATE INDEX collection_item_collection_idx ON collection_item (collection);
CREATE INDEX collection_item_year_idx ON collection_item (year);

-- Eén rij per scrape-run zodat voortgang en historie bewaard blijven, ook na herstart.
CREATE TABLE scrape_run (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status       VARCHAR(20)  NOT NULL,             -- RUNNING | COMPLETED | FAILED
    started_by   VARCHAR(320) NOT NULL,
    force_rescrape BOOLEAN    NOT NULL DEFAULT FALSE,
    started_at   TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at  TIMESTAMPTZ,
    total        INTEGER      NOT NULL DEFAULT 0,   -- totaal aantal te verwerken records
    processed    INTEGER      NOT NULL DEFAULT 0,   -- opgehaald/opgeslagen
    skipped      INTEGER      NOT NULL DEFAULT 0,   -- overgeslagen (al aanwezig)
    failed       INTEGER      NOT NULL DEFAULT 0,   -- mislukte records
    current_collection VARCHAR(40),
    message      TEXT,
    per_collection JSONB      NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX scrape_run_started_at_idx ON scrape_run (started_at DESC, id DESC);
