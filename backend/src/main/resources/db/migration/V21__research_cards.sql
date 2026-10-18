-- Kaarten voor het AI-onderzoek: per record een korte feitensamenvatting en getypeerde
-- trefwoorden (personen, adressen, straten, jaren, instellingen). 's Nachts gemaakt door een
-- klein model via de agent-runtime; de vraagbeantwoording zoekt hierin met spellingtolerantie.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE document_card (
    collection         VARCHAR(40)  NOT NULL,
    ident              VARCHAR(64)  NOT NULL,
    summary            TEXT         NOT NULL DEFAULT '',
    has_image          BOOLEAN      NOT NULL DEFAULT FALSE,
    extraction_version VARCHAR(40)  NOT NULL,
    model              VARCHAR(200),
    source_hash        VARCHAR(64)  NOT NULL,
    error              VARCHAR(500),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (collection, ident),
    FOREIGN KEY (collection, ident) REFERENCES collection_item (collection, ident) ON DELETE CASCADE
);

CREATE TABLE keyword (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    normalized TEXT        NOT NULL,
    type       VARCHAR(20) NOT NULL,
    CONSTRAINT keyword_unique UNIQUE (normalized, type)
);

CREATE INDEX keyword_normalized_trgm_idx ON keyword USING GIN (normalized gin_trgm_ops);

CREATE TABLE keyword_mention (
    keyword_id BIGINT      NOT NULL REFERENCES keyword (id) ON DELETE CASCADE,
    collection VARCHAR(40) NOT NULL,
    ident      VARCHAR(64) NOT NULL,
    literal    TEXT        NOT NULL,
    year_from  INTEGER,
    year_to    INTEGER,
    source     VARCHAR(10) NOT NULL, -- FIELD (uit een metadataveld) of MODEL (uit de vrije tekst)
    PRIMARY KEY (keyword_id, collection, ident),
    FOREIGN KEY (collection, ident) REFERENCES collection_item (collection, ident) ON DELETE CASCADE
);

CREATE INDEX keyword_mention_item_idx ON keyword_mention (collection, ident);
CREATE INDEX keyword_mention_literal_trgm_idx ON keyword_mention USING GIN (literal gin_trgm_ops);
CREATE INDEX keyword_mention_year_idx ON keyword_mention (year_from, year_to) WHERE year_from IS NOT NULL;

-- Tellers voor kaarten in een scrape-run.
ALTER TABLE scrape_run
    ADD COLUMN cards INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN cards_failed INTEGER NOT NULL DEFAULT 0;
