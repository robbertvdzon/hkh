package nl.vdzon.hkh.aisearch

import java.time.Instant
import java.util.UUID
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Repository
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/** A campaign choice is immutable; normal public searches never read this table. */
data class CapacityConfig(
    val execution: AiExecution,
    val method: AiResearchMethod,
    val writeBudgetChars: Int,
    val parallelism: Int,
    val maxScenarios: Int,
    val endsAt: Instant,
    val repeatQuestions: Boolean = false,
    val accountAlias: String = "default",
    val datasetVersion: String = "onbekend",
    val codeVersion: String = "onbekend",
    val promptVersion: String = "hkh-capacity-v1",
    val maxCostUsd: java.math.BigDecimal? = null,
    val expandIfAvailable: Boolean = false,
    val followUpQuestion: String? = null,
)

data class CapacityQuestion(val question: String, val depth: AiResearchDepth = AiResearchDepth.DEFAULT, val category: String = "overig")
class CapacitySuspended : RuntimeException("De campagne dispatcht tijdelijk geen nieuwe AI-fasen")

@Repository
class AiCapacityStore(val jdbc: JdbcTemplate, val mapper: ObjectMapper) {
    fun config(turnId: String): CapacityConfig? = jdbc.queryForList(
        "SELECT c.config::text FROM ai_capacity_turn r JOIN ai_capacity_campaign c ON c.id=r.campaign_id WHERE r.turn_id=?::uuid",
        String::class.java, turnId,
    ).singleOrNull()?.let { mapper.readValue(it, CapacityConfig::class.java) }

    fun isCapacity(turnId: String): Boolean = config(turnId) != null
    fun turnId(key: String): String? = key.removePrefix("hkh-capacity-").takeIf { key.startsWith("hkh-capacity-") && it.length >= 36 }?.take(36)
    fun prefix(turnId: String): String = if (isCapacity(turnId)) "hkh-capacity-$turnId" else "hkh-ai-$turnId"

    fun canDispatch(turnId: String): Boolean = jdbc.queryForObject(
        """SELECT EXISTS(SELECT 1 FROM ai_capacity_turn r JOIN ai_capacity_campaign c ON c.id=r.campaign_id
            WHERE r.turn_id=?::uuid AND r.status='ACTIVE' AND c.status IN ('RUNNING','PAUSING') AND (c.next_dispatch_at IS NULL OR c.next_dispatch_at<=now()) AND (c.config->>'endsAt')::timestamptz > now())""",
        Boolean::class.java, turnId,
    ) == true

    fun stopped(turnId: String): Boolean = jdbc.queryForObject(
        """SELECT EXISTS(SELECT 1 FROM ai_capacity_turn r JOIN ai_capacity_campaign c ON c.id=r.campaign_id
            WHERE r.turn_id=?::uuid AND c.status IN ('STOPPING','STOPPED'))""", Boolean::class.java, turnId,
    ) == true

    fun <T : Any> checkpoint(turnId: String, name: String, type: Class<T>, produce: () -> T): T {
        fun read(): T? = jdbc.queryForList("SELECT value::text FROM ai_capacity_checkpoint WHERE turn_id=?::uuid AND name=?", String::class.java, turnId, name)
            .singleOrNull()?.let { mapper.readValue(it, type) }
        read()?.let { return it }
        val value = produce()
        jdbc.update("INSERT INTO ai_capacity_checkpoint(turn_id,name,value) VALUES (?::uuid,?,?::jsonb) ON CONFLICT DO NOTHING", turnId, name, mapper.writeValueAsString(value))
        return requireNotNull(read())
    }

    fun event(id: String, message: String) { jdbc.update("INSERT INTO ai_capacity_event(campaign_id,message) VALUES (?::uuid,?)", id, message) }
    fun json(value: Any): String = mapper.writeValueAsString(value)
    fun rows(sql: String, vararg args: Any?): List<Map<String, Any?>> = jdbc.query(sql, { rs, _ ->
        (1..rs.metaData.columnCount).associate { index ->
            val key = rs.metaData.getColumnLabel(index)
            val raw = rs.getObject(index)
            key to when (raw) {
                is java.sql.Timestamp -> raw.toInstant().toString()
                is UUID -> raw.toString()
                else -> if (rs.metaData.getColumnTypeName(index) in setOf("json", "jsonb")) mapper.readTree(rs.getString(index) ?: "null") else raw
            }
        }
    }, *args)
    fun node(row: Map<String, Any?>, key: String): JsonNode = mapper.valueToTree(row[key])
}
