-- Eenmalige opruiming: de grijze volgorde-teller ("1.", "2.", ...) op een ZCBS-lijstpagina
-- stond zonder scheidingsteken naast het eerste veld, waardoor de snelle scan labels als
-- "100. Objectnummer" of "1000. Volgnummer" opsloeg i.p.v. "Objectnummer"/"Volgnummer" (zie
-- ZcbsClient.parseListItem). Verwijdert die vervuilde sleutels uit al opgeslagen records;
-- toekomstige scans slaan ze niet meer zo op.
UPDATE collection_item
SET fields = (
    SELECT COALESCE(jsonb_object_agg(key, value), '{}'::jsonb)
    FROM jsonb_each(fields)
    WHERE key !~ '^[0-9]+\.\s'
)
WHERE fields::text ~ '"[0-9]+\. ';
