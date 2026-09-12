package nl.vdzon.hkh.aisearch

import java.sql.ResultSet
import java.util.UUID
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository
import tools.jackson.databind.ObjectMapper

@Repository
class AiSearchRepository(
    private val jdbc: JdbcTemplate,
    private val objectMapper: ObjectMapper,
) {
    fun createSession(): String {
        val id = UUID.randomUUID().toString()
        jdbc.update("INSERT INTO ai_search_session (id) VALUES (?::uuid)", id)
        return id
    }

    fun sessionExists(id: String): Boolean =
        jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM ai_search_session WHERE id = ?::uuid)", Boolean::class.java, id) == true

    fun createTurn(sessionId: String, question: String): AiSearchTurn {
        val id = UUID.randomUUID().toString()
        val number = jdbc.queryForObject(
            "SELECT COALESCE(MAX(turn_number), 0) + 1 FROM ai_search_turn WHERE session_id = ?::uuid",
            Int::class.java,
            sessionId,
        ) ?: 1
        jdbc.update(
            """
            INSERT INTO ai_search_turn (id, session_id, turn_number, question, status, progress_percent, progress_message)
            VALUES (?::uuid, ?::uuid, ?, ?, 'SUBMITTING', 2, 'De vraag wordt voorbereid')
            """.trimIndent(),
            id, sessionId, number, question,
        )
        return requireNotNull(findTurn(id))
    }

    fun turns(sessionId: String): List<AiSearchTurn> = jdbc.query(
        "SELECT * FROM ai_search_turn WHERE session_id = ?::uuid ORDER BY turn_number",
        rowMapper,
        sessionId,
    )

    fun findTurn(id: String): AiSearchTurn? = jdbc.query(
        "SELECT * FROM ai_search_turn WHERE id = ?::uuid",
        rowMapper,
        id,
    ).singleOrNull()

    fun activeTurns(): List<AiSearchTurn> = jdbc.query(
        "SELECT * FROM ai_search_turn WHERE status IN ('SUBMITTING', 'QUEUED', 'RUNNING') ORDER BY created_at",
        rowMapper,
    )

    fun activeTurnCount(): Int = jdbc.queryForObject(
        "SELECT COUNT(*) FROM ai_search_turn WHERE status IN ('SUBMITTING', 'QUEUED', 'RUNNING')",
        Int::class.java,
    ) ?: 0

    fun hasActiveTurn(sessionId: String): Boolean = jdbc.queryForObject(
        "SELECT EXISTS(SELECT 1 FROM ai_search_turn WHERE session_id = ?::uuid AND status IN ('SUBMITTING', 'QUEUED', 'RUNNING'))",
        Boolean::class.java,
        sessionId,
    ) == true

    fun attachJob(id: String, jobId: String) {
        jdbc.update(
            "UPDATE ai_search_turn SET runtime_job_id = ?, status = 'QUEUED', progress_percent = 5, progress_message = 'Het onderzoek staat klaar', updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid",
            jobId, id,
        )
    }

    fun updateProgress(id: String, status: AiTurnStatus, percent: Int?, message: String?) {
        jdbc.update(
            "UPDATE ai_search_turn SET status = ?, progress_percent = ?, progress_message = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid",
            status.name, percent, message?.take(500), id,
        )
    }

    fun succeed(id: String, rendered: RenderedAiAnswer) {
        jdbc.update(
            """
            UPDATE ai_search_turn SET status = 'SUCCEEDED', progress_percent = 100,
                progress_message = 'Onderzoek afgerond', title = ?, answer_html = ?,
                sources = ?::jsonb, suggested_follow_ups = ?::jsonb, error_message = NULL,
                updated_at = CURRENT_TIMESTAMP, completed_at = CURRENT_TIMESTAMP
            WHERE id = ?::uuid
            """.trimIndent(),
            rendered.title.take(500),
            rendered.html,
            objectMapper.writeValueAsString(rendered.sources),
            objectMapper.writeValueAsString(rendered.suggestedFollowUps),
            id,
        )
    }

    fun fail(id: String, message: String, cancelled: Boolean = false) {
        jdbc.update(
            """
            UPDATE ai_search_turn SET status = ?, progress_message = ?, error_message = ?,
                updated_at = CURRENT_TIMESTAMP, completed_at = CURRENT_TIMESTAMP
            WHERE id = ?::uuid
            """.trimIndent(),
            if (cancelled) "CANCELLED" else "FAILED",
            if (cancelled) "Onderzoek gestopt" else "Onderzoek kon niet worden afgerond",
            message.take(1000),
            id,
        )
    }

    private val rowMapper = RowMapper { rs: ResultSet, _: Int ->
        AiSearchTurn(
            id = rs.getString("id"),
            sessionId = rs.getString("session_id"),
            turnNumber = rs.getInt("turn_number"),
            question = rs.getString("question"),
            runtimeJobId = rs.getString("runtime_job_id"),
            status = AiTurnStatus.valueOf(rs.getString("status")),
            progressPercent = (rs.getObject("progress_percent") as Number?)?.toInt(),
            progressMessage = rs.getString("progress_message"),
            title = rs.getString("title"),
            answerHtml = rs.getString("answer_html"),
            sources = parseSources(rs.getString("sources")),
            suggestedFollowUps = parseStrings(rs.getString("suggested_follow_ups")),
            errorMessage = rs.getString("error_message"),
            createdAt = rs.getTimestamp("created_at").toInstant(),
            updatedAt = rs.getTimestamp("updated_at").toInstant(),
            completedAt = rs.getTimestamp("completed_at")?.toInstant(),
        )
    }

    private fun parseSources(json: String?): List<AiSourceRef> {
        if (json.isNullOrBlank()) return emptyList()
        val result = mutableListOf<AiSourceRef>()
        for (node in objectMapper.readTree(json)) {
            val collection = node.path("collection").asText("")
            val ident = node.path("ident").asText("")
            if (collection.isNotBlank() && ident.isNotBlank()) result += AiSourceRef(collection, ident)
        }
        return result
    }

    private fun parseStrings(json: String?): List<String> {
        if (json.isNullOrBlank()) return emptyList()
        val result = mutableListOf<String>()
        for (node in objectMapper.readTree(json)) result += node.asText()
        return result
    }
}
