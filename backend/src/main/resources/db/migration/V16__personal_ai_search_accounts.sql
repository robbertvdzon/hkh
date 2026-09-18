CREATE INDEX ai_search_session_personal_user_idx
    ON ai_search_session (user_id, created_at DESC)
    WHERE dossier_id IS NULL AND user_id IS NOT NULL;
