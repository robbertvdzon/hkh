-- De standing acceptatieomgeving is niet aan een PR gebonden, dus heeft geen pr_number om te seeden.
-- CHECK (pr_number > 0) blijft ongewijzigd staan: een CHECK-constraint laat NULL altijd door (SQL-
-- standaardgedrag), dus alleen de NOT NULL-eis hoeft te vervallen.
ALTER TABLE preview_seed_history ALTER COLUMN pr_number DROP NOT NULL;
