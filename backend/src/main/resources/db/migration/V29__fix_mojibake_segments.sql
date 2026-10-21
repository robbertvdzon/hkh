-- Vervolg op V28: records waarin kapotte tekens ("cafÃ©") naast gewone accenten staan (zoals een echte "é")
-- lieten zich niet als geheel terugzetten. Hier wordt elke kapotte reeks afzonderlijk hersteld; reeksen die geen
-- geldige UTF-8 vormen blijven staan. De scraper doet hetzelfde bij het inlezen (TextRepair).
CREATE OR REPLACE FUNCTION pg_temp.hkh_fix_segments(input text) RETURNS text AS $$
DECLARE
    token text;
    fixed text;
    result text := input;
BEGIN
    IF input IS NULL THEN
        RETURN NULL;
    END IF;
    FOR token IN
        SELECT DISTINCT m[1]
        FROM regexp_matches(input, '([\xc2-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf4][\x80-\xbf]{3})', 'g') AS m
    LOOP
        BEGIN
            fixed := convert_from(convert_to(token, 'LATIN1'), 'UTF8');
            result := replace(result, token, fixed);
        EXCEPTION WHEN others THEN
            NULL;
        END;
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Kaarten die vóór het herstel actueel waren, blijven actueel.
CREATE TEMP TABLE mojibake_current_cards ON COMMIT DROP AS
SELECT i.collection, i.ident
FROM collection_item i
JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident
WHERE c.source_hash = md5(i.search_text || ' ' || coalesce(i.document_text, ''))
  AND i.search_text ~ '[ÂÃâ][\x80-\xbf]';

UPDATE collection_item SET search_text = pg_temp.hkh_fix_segments(search_text)
WHERE search_text ~ '[ÂÃâ][\x80-\xbf]';

UPDATE document_card c SET source_hash = md5(i.search_text || ' ' || coalesce(i.document_text, ''))
FROM collection_item i, mojibake_current_cards t
WHERE c.collection = i.collection AND c.ident = i.ident AND t.collection = i.collection AND t.ident = i.ident;

DROP FUNCTION pg_temp.hkh_fix_segments(text);
