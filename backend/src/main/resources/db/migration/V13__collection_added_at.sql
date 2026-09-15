-- Existing rows have no reliable arrival date: do not present a reimport as a new item.
ALTER TABLE collection_item ADD COLUMN added_at TIMESTAMPTZ;
ALTER TABLE collection_item ALTER COLUMN added_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE INDEX collection_item_added_at_idx ON collection_item (added_at DESC) WHERE added_at IS NOT NULL;
