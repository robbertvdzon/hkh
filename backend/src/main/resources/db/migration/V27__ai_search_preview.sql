-- Pijplijn: de eerste treffers (zeven stuks met aantallen per collectie) die de gebruiker direct na de
-- snelle zoekstap ziet, nog voordat het model ze heeft beoordeeld. JSON (geen JSONB) zodat de volgorde van de
-- collecties, grootste eerst, behouden blijft.
ALTER TABLE ai_search_turn ADD COLUMN preview JSON;
