-- Een dossier krijgt een eigen lees-/onderzoekskopie; de browserzoekopdracht blijft bestaan.
ALTER TABLE ai_search_session
    ADD COLUMN source_session_id UUID REFERENCES ai_search_session(id) ON DELETE SET NULL;
ALTER TABLE ai_search_session
    ADD CONSTRAINT ai_search_dossier_source_unique UNIQUE (dossier_id, source_session_id);
