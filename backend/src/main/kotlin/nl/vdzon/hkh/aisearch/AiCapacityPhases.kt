package nl.vdzon.hkh.aisearch

import org.springframework.stereotype.Component
import tools.jackson.databind.JsonNode

/** Persist the exact request before dispatch and the result before moving to the next phase. */
@Component
class AiCapacityPhases(private val store: AiCapacityStore) {
    fun request(turnId: String, key: String, proposed: Map<String, Any>): Pair<Int, JsonNode> {
        val prior = store.rows("SELECT * FROM ai_capacity_phase WHERE turn_id=?::uuid AND phase_key=? ORDER BY generation DESC LIMIT 1", turnId, key).singleOrNull()
        if (prior != null && prior["status"] != "RETRY") return (prior["generation"] as Number).toInt() to store.node(prior, "request")
        if (!store.canDispatch(turnId)) throw CapacitySuspended()
        val generation = if (prior == null) 0 else (prior["generation"] as Number).toInt() + 1
        // Keep the first request even when retrying a failed phase.
        val saved = prior?.let { store.node(it, "request") } ?: store.mapper.valueToTree(proposed)
        store.jdbc.update("""INSERT INTO ai_capacity_phase(turn_id,phase_key,generation,request)
            VALUES (?::uuid,?,?,?::jsonb) ON CONFLICT DO NOTHING""", turnId, key, generation, saved.toString())
        return generation to store.node(store.rows("SELECT request FROM ai_capacity_phase WHERE turn_id=?::uuid AND phase_key=? AND generation=?", turnId, key, generation).single(), "request")
    }

    fun job(turnId: String, key: String, generation: Int): String? = store.jdbc.queryForList(
        "SELECT job_id FROM ai_capacity_phase WHERE turn_id=?::uuid AND phase_key=? AND generation=? AND job_id IS NOT NULL", String::class.java, turnId, key, generation,
    ).singleOrNull()

    fun attach(turnId: String, key: String, generation: Int, jobId: String) {
        store.jdbc.update("UPDATE ai_capacity_phase SET job_id=?,updated_at=now() WHERE turn_id=?::uuid AND phase_key=? AND generation=?", jobId, turnId, key, generation)
    }

    fun dispatchBody(turnId: String, key: String, generation: Int): JsonNode? = store.jdbc.queryForList(
        "SELECT dispatch_body::text FROM ai_capacity_phase WHERE turn_id=?::uuid AND phase_key=? AND generation=? AND dispatch_body IS NOT NULL", String::class.java, turnId, key, generation,
    ).singleOrNull()?.let(store.mapper::readTree)

    fun saveBody(turnId: String, key: String, generation: Int, body: Map<String, Any>): JsonNode {
        store.jdbc.update("""UPDATE ai_capacity_phase SET dispatch_body=?::jsonb WHERE turn_id=?::uuid AND phase_key=? AND generation=? AND dispatch_body IS NULL AND status<>'CANCELLED'""",
            store.json(body), turnId, key, generation)
        return dispatchBody(turnId, key, generation) ?: throw CapacitySuspended()
    }

    fun finished(jobId: String, status: String, result: JsonNode? = null) {
        store.jdbc.update("UPDATE ai_capacity_phase SET status=?,result=COALESCE(?::jsonb,result),updated_at=now() WHERE job_id=?", status, result?.toString(), jobId)
    }

    fun result(jobId: String): JsonNode? = store.jdbc.queryForList("SELECT result::text FROM ai_capacity_phase WHERE job_id=? AND result IS NOT NULL", String::class.java, jobId)
        .singleOrNull()?.let(store.mapper::readTree)
}
