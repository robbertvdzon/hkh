package nl.vdzon.hkh.aisearch

import java.time.Instant
import java.util.UUID
import nl.vdzon.hkh.collection.CollectionLinks
import org.springframework.http.HttpStatus
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.server.ResponseStatusException
import tools.jackson.databind.ObjectMapper

data class AiAnswerShareState(val token: String?)

data class SharedAiAnswer(
    val question: String,
    val title: String?,
    val answerHtml: String,
    val sources: List<AiSourceRef>,
    val answeredAt: Instant?,
    val sharedAt: Instant,
)

@Service
class AiAnswerShareService(
    private val repository: AiSearchRepository,
    private val jdbc: JdbcTemplate,
    private val mapper: ObjectMapper,
) {
    fun state(visitorId: String, answerId: UUID): AiAnswerShareState {
        requireOwner(visitorId, answerId)
        return AiAnswerShareState(token(answerId))
    }

    @Transactional
    fun create(visitorId: String, answerId: UUID): AiAnswerShareState {
        val answer = requireOwner(visitorId, answerId)
        if (answer.status != AiTurnStatus.SUCCEEDED || answer.answerHtml.isNullOrBlank()) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Alleen een afgerond antwoord kan worden gedeeld.")
        }
        // Een herhaalde klik houdt dezelfde link en dezelfde leesversie in stand.
        jdbc.update(
            """
            INSERT INTO ai_answer_share (answer_id, token, question, title, answer_html, sources, answered_at)
            SELECT turn_item.id, ?::uuid, ?, ?, ?, ?::jsonb, turn_item.completed_at
            FROM ai_search_turn turn_item JOIN ai_search_session session ON session.id = turn_item.session_id
            WHERE turn_item.id = ?::uuid AND session.visitor_id = ?::uuid AND session.dossier_id IS NULL
            ON CONFLICT (answer_id) DO NOTHING
            """.trimIndent(),
            UUID.randomUUID(), CollectionLinks.rewrite(answer.question),
            answer.title?.let(CollectionLinks::rewrite), CollectionLinks.rewrite(answer.answerHtml),
            mapper.writeValueAsString(answer.sources), answerId, visitorId,
        )
        return AiAnswerShareState(token(answerId) ?: throw ResponseStatusException(HttpStatus.NOT_FOUND))
    }

    fun revoke(visitorId: String, answerId: UUID) {
        requireOwner(visitorId, answerId)
        jdbc.update("DELETE FROM ai_answer_share WHERE answer_id = ?", answerId)
    }

    fun read(token: UUID): SharedAiAnswer = jdbc.query(
        """
        SELECT share.* FROM ai_answer_share share
        JOIN ai_search_turn turn_item ON turn_item.id = share.answer_id
        JOIN ai_search_session session ON session.id = turn_item.session_id
        WHERE share.token = ? AND session.dossier_id IS NULL
        """.trimIndent(),
        { rs, _ ->
            SharedAiAnswer(
                question = rs.getString("question"),
                title = rs.getString("title"),
                answerHtml = rs.getString("answer_html"),
                sources = buildList {
                    for (node in mapper.readTree(rs.getString("sources"))) {
                        add(AiSourceRef(node.path("collection").asText(), node.path("ident").asText()))
                    }
                },
                answeredAt = rs.getTimestamp("answered_at")?.toInstant(),
                sharedAt = rs.getTimestamp("shared_at").toInstant(),
            )
        },
        token,
    ).singleOrNull() ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Deze deellink is niet meer beschikbaar.")

    private fun token(answerId: UUID): String? = jdbc.queryForList(
        "SELECT token::text FROM ai_answer_share WHERE answer_id = ?", String::class.java, answerId,
    ).singleOrNull()

    private fun requireOwner(visitorId: String, answerId: UUID): AiSearchTurn {
        val answer = repository.findTurn(answerId.toString())
        if (answer == null || !repository.sessionExists(answer.sessionId, visitorId)) {
            throw ResponseStatusException(HttpStatus.NOT_FOUND)
        }
        return answer
    }
}
