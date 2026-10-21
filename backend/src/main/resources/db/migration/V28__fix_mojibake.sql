-- Herstel van kapotte tekens in het archief: waarden die als UTF-8 zijn verstuurd maar als ISO-8859-1 zijn
-- gelezen ("NotariÃ«le akte", "cafÃ©"). Raakt alleen waarden die zich volledig laten terugzetten; de rest blijft
-- ongewijzigd. De scraper herstelt dit voortaan bij het inlezen (TextRepair).
CREATE OR REPLACE FUNCTION pg_temp.hkh_fix_mojibake(input text) RETURNS text AS $$
BEGIN
    IF input IS NULL OR input !~ '[ÂÃâ][\x80-\xbf]' THEN
        RETURN input;
    END IF;
    RETURN convert_from(convert_to(input, 'LATIN1'), 'UTF8');
EXCEPTION WHEN others THEN
    RETURN input;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Kaarten die vóór het herstel actueel waren, blijven actueel: de samenvatting hangt niet aan deze accenten.
CREATE TEMP TABLE mojibake_current_cards ON COMMIT DROP AS
SELECT i.collection, i.ident
FROM collection_item i
JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident
WHERE c.source_hash = md5(i.search_text || ' ' || coalesce(i.document_text, ''))
  AND (i.title ~ '[ÂÃâ][\x80-\xbf]' OR i.description ~ '[ÂÃâ][\x80-\xbf]' OR i.search_text ~ '[ÂÃâ][\x80-\xbf]' OR i.fields::text ~ '[ÂÃâ][\x80-\xbf]');

UPDATE collection_item SET
    title = pg_temp.hkh_fix_mojibake(title),
    description = pg_temp.hkh_fix_mojibake(description),
    search_text = pg_temp.hkh_fix_mojibake(search_text),
    fields = (
        SELECT jsonb_object_agg(e.key, CASE WHEN jsonb_typeof(e.value) = 'string' THEN to_jsonb(pg_temp.hkh_fix_mojibake(e.value #>> '{}')) ELSE e.value END)
        FROM jsonb_each(fields) e
    )
WHERE title ~ '[ÂÃâ][\x80-\xbf]' OR description ~ '[ÂÃâ][\x80-\xbf]' OR search_text ~ '[ÂÃâ][\x80-\xbf]' OR fields::text ~ '[ÂÃâ][\x80-\xbf]';

UPDATE document_card c SET source_hash = md5(i.search_text || ' ' || coalesce(i.document_text, ''))
FROM collection_item i, mojibake_current_cards t
WHERE c.collection = i.collection AND c.ident = i.ident AND t.collection = i.collection AND t.ident = i.ident;

-- Trefwoorden uit metadatavelden (bijvoorbeeld het thema "Openbare leven (bioscoop, cafÃ©, horeca)"). Een
-- trefwoord waarvan de herstelde naam al bestaat blijft ongemoeid, zodat de unieke sleutel niet botst.
UPDATE keyword k SET normalized = pg_temp.hkh_fix_mojibake(k.normalized)
WHERE k.normalized ~ '[ÂÃâ][\x80-\xbf]'
  AND NOT EXISTS (SELECT 1 FROM keyword o WHERE o.type = k.type AND o.normalized = pg_temp.hkh_fix_mojibake(k.normalized) AND o.id <> k.id);
UPDATE keyword_mention SET literal = pg_temp.hkh_fix_mojibake(literal) WHERE literal ~ '[ÂÃâ][\x80-\xbf]';

DROP FUNCTION pg_temp.hkh_fix_mojibake(text);
