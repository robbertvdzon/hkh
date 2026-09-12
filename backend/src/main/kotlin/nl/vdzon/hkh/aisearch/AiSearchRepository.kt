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
    fun createSession(owner: AiSearchOwner): String {
        val id = UUID.randomUUID().toString()
        jdbc.update(
            """
            INSERT INTO ai_search_session (id, visitor_id, dossier_id, user_id, created_by_email)
            VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, ?)
            """.trimIndent(),
            id, owner.visitorId, owner.dossierId, owner.userId, owner.userEmail,
        )
        return id
    }

    fun sessionExists(id: String, visitorId: String): Boolean = jdbc.queryForObject(
        "SELECT EXISTS(SELECT 1 FROM ai_search_session WHERE id = ?::uuid AND visitor_id = ?::uuid AND dossier_id IS NULL)",
        Boolean::class.java,
        id,
        visitorId,
    ) == true

    fun sessionInDossier(id: String, dossierId: String): Boolean = jdbc.queryForObject(
        "SELECT EXISTS(SELECT 1 FROM ai_search_session WHERE id = ?::uuid AND dossier_id = ?::uuid)",
        Boolean::class.java,
        id,
        dossierId,
    ) == true

    fun sessionDossierId(id: String): String? = jdbc.queryForList(
        "SELECT dossier_id::text FROM ai_search_session WHERE id = ?::uuid",
        String::class.java,
        id,
    ).singleOrNull()

    fun sessionIds(visitorId: String): List<String> = jdbc.queryForList(
        """
        SELECT session.id::text
        FROM ai_search_session session
        LEFT JOIN ai_search_turn turn_item ON turn_item.session_id = session.id
        WHERE session.visitor_id = ?::uuid AND session.dossier_id IS NULL
        GROUP BY session.id, session.created_at
        ORDER BY COALESCE(MAX(turn_item.updated_at), session.created_at) DESC
        """.trimIndent(),
        String::class.java,
        visitorId,
    )

    fun sessionIdsForDossier(dossierId: String): List<String> = jdbc.queryForList(
        """
        SELECT session.id::text
        FROM ai_search_session session
        LEFT JOIN ai_search_turn turn_item ON turn_item.session_id = session.id
        WHERE session.dossier_id = ?::uuid
        GROUP BY session.id, session.created_at
        ORDER BY COALESCE(MAX(turn_item.updated_at), session.created_at) DESC
        """.trimIndent(),
        String::class.java,
        dossierId,
    )

    /** Verplaatst een cookie-zoekopdracht naar een dossier; daarna is de cookie niet meer de sleutel. */
    fun adoptSession(id: String, visitorId: String, owner: AiSearchOwner): Boolean = jdbc.update(
        """
        UPDATE ai_search_session SET visitor_id = NULL, dossier_id = ?::uuid, user_id = ?::uuid, created_by_email = ?
        WHERE id = ?::uuid AND visitor_id = ?::uuid AND dossier_id IS NULL
        """.trimIndent(),
        owner.dossierId, owner.userId, owner.userEmail, id, visitorId,
    ) > 0

    fun deleteSession(id: String, visitorId: String): Boolean = jdbc.update(
        "DELETE FROM ai_search_session WHERE id = ?::uuid AND visitor_id = ?::uuid AND dossier_id IS NULL",
        id,
        visitorId,
    ) > 0

    fun deleteSessionInDossier(id: String, dossierId: String): Boolean = jdbc.update(
        "DELETE FROM ai_search_session WHERE id = ?::uuid AND dossier_id = ?::uuid",
        id,
        dossierId,
    ) > 0

    fun createTurn(sessionId: String, question: String, dossierContext: String? = null): AiSearchTurn {
        val id = UUID.randomUUID().toString()
        val number = jdbc.queryForObject(
            "SELECT COALESCE(MAX(turn_number), 0) + 1 FROM ai_search_turn WHERE session_id = ?::uuid",
            Int::class.java,
            sessionId,
        ) ?: 1
        jdbc.update(
            """
            INSERT INTO ai_search_turn (id, session_id, turn_number, question, status, progress_percent, progress_message, dossier_context)
            VALUES (?::uuid, ?::uuid, ?, ?, 'SUBMITTING', 2, 'De vraag wordt voorbereid', ?)
            """.trimIndent(),
            id, sessionId, number, question, dossierContext,
        )
        return requireNotNull(findTurn(id))
    }

    fun turns(sessionId: String): List<AiSearchTurn> = jdbc.query(
        "SELECT * FROM ai_search_turn WHERE session_id = ?::uuid ORDER BY turn_number",
        rowMapper,
        sessionId,
    )

    /** Alle geslaagde antwoorden in een dossier, nieuwste eerst. */
    fun dossierAnswers(dossierId: String, excludingTurnId: String? = null, limit: Int = Int.MAX_VALUE): List<AiSearchTurn> = jdbc.query(
        """
        SELECT turn_item.* FROM ai_search_turn turn_item
        JOIN ai_search_session session ON session.id = turn_item.session_id
        WHERE session.dossier_id = ?::uuid AND turn_item.status = 'SUCCEEDED'
          AND (?::uuid IS NULL OR turn_item.id <> ?::uuid)
        ORDER BY turn_item.completed_at DESC NULLS LAST
        LIMIT ?
        """.trimIndent(),
        rowMapper,
        dossierId, excludingTurnId, excludingTurnId, limit,
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

    fun activeTurnCountForUser(userId: String): Int = jdbc.queryForObject(
        """
        SELECT COUNT(*) FROM ai_search_turn turn_item
        JOIN ai_search_session session ON session.id = turn_item.session_id
        WHERE session.user_id = ?::uuid AND turn_item.status IN ('SUBMITTING', 'QUEUED', 'RUNNING')
        """.trimIndent(),
        Int::class.java,
        userId,
    ) ?: 0

    fun hasActiveTurn(sessionId: String): Boolean = jdbc.queryForObject(
        "SELECT EXISTS(SELECT 1 FROM ai_search_turn WHERE session_id = ?::uuid AND status IN ('SUBMITTING', 'QUEUED', 'RUNNING'))",
        Boolean::class.java,
        sessionId,
    ) == true

    fun attachJob(id: String, jobId: String): Boolean = jdbc.update(
            "UPDATE ai_search_turn SET runtime_job_id = ?, status = 'QUEUED', progress_percent = 5, progress_message = 'Het onderzoek staat klaar', updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid AND status = 'SUBMITTING'",
            jobId, id,
        ) > 0

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
            dossierContext = rs.getString("dossier_context"),
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
