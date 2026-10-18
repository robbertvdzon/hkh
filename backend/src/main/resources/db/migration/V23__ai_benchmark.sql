-- Testset voor het vergelijken van onderzoeksmethodes en modellen: vaste vragen die vanuit het
-- beheerscherm opnieuw gesteld worden. De antwoorden zijn gewone ai_search_turn-rijen in een sessie
-- van de testset-eigenaar, zodat de bestaande weergave en statistieken gelden.
CREATE TABLE ai_benchmark_question (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    question   VARCHAR(1000) NOT NULL,
    depth      VARCHAR(20)   NOT NULL DEFAULT 'FAST',
    created_at TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(320)
);

-- Een beurt uit de testset verwijst naar zijn vraag; handmatige vragen hebben NULL.
ALTER TABLE ai_search_turn ADD COLUMN benchmark_question_id BIGINT REFERENCES ai_benchmark_question (id) ON DELETE SET NULL;
CREATE INDEX ai_search_turn_benchmark_idx ON ai_search_turn (benchmark_question_id) WHERE benchmark_question_id IS NOT NULL;
