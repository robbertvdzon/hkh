-- Logboek van verzoeken: browsertype, bot- en testmarkering en een pseudonieme bezoekerssleutel om unieke
-- bezoekers te tellen. Het volledige IP-adres en de sleutel worden na 30 dagen afgekapt, respectievelijk
-- verwijderd (nachtelijke taak); de regel zelf blijft voor de statistieken bestaan.
ALTER TABLE request_log
    ADD COLUMN user_agent    VARCHAR(300),
    ADD COLUMN bot           BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN test          BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN visitor_key   VARCHAR(64),
    ADD COLUMN ip_anonymized BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX request_log_visitor_idx ON request_log (created_at DESC, visitor_key) WHERE visitor_key IS NOT NULL;
