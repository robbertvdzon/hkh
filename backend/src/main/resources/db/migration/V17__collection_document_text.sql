-- Volledige tekst uit de PDF van een record (archief, artikelen). ZCBS levert die tekst niet via de
-- recordpagina, maar de PDF's hebben een tekstlaag; de backend haalt die er bij het scrapen uit.
-- Eigen kolommen, los van `fields`/`search_text`, omdat een rescrape die twee volledig overschrijft.
ALTER TABLE collection_item
    ADD COLUMN document_text TEXT,
    ADD COLUMN document_pdf_hash VARCHAR(64),
    ADD COLUMN document_text_extracted_at TIMESTAMPTZ,
    ADD COLUMN document_text_error VARCHAR(500);

-- De zoekvector dekt voortaan metadata én documenttekst; gewoon zoeken vindt dus ook treffers
-- in de tekst van een akte of krantenartikel.
ALTER TABLE collection_item DROP COLUMN search_vector;
ALTER TABLE collection_item
    ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('dutch'::regconfig, search_text || ' ' || coalesce(document_text, ''))
    ) STORED;
CREATE INDEX collection_item_search_idx ON collection_item USING GIN (search_vector);

-- Voor de backfill en de "tekst beschikbaar"-vlag.
CREATE INDEX collection_item_document_pending_idx ON collection_item (collection, ident)
    WHERE pdf_url IS NOT NULL AND document_text IS NULL;
CREATE INDEX collection_item_document_text_idx ON collection_item (collection)
    WHERE document_text IS NOT NULL;

-- Tellers voor documentteksten in een scrape-run (FULL haalt ze direct op; TEXT is de backfill).
ALTER TABLE scrape_run
    ADD COLUMN documents INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN documents_failed INTEGER NOT NULL DEFAULT 0;
