-- Onderscheidt snel (lijstpagina, samenvatting) van volledig (detailpagina, alle velden)
-- gescrapete records, zodat een snelle scan nooit een al-complete rij overschrijft en een
-- volledige scan gericht alleen ontbrekende/onvolledige records kan bijwerken.
ALTER TABLE collection_item ADD COLUMN is_complete BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX collection_item_incomplete_idx ON collection_item (collection) WHERE is_complete = false;

-- Bewaart met welke modus (FAST of FULL) een scrape-run is gestart, voor weergave in de admin-UI.
ALTER TABLE scrape_run ADD COLUMN mode VARCHAR(10) NOT NULL DEFAULT 'FULL';
