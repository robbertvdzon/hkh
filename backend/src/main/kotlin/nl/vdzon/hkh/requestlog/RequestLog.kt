package nl.vdzon.hkh.requestlog

import jakarta.servlet.http.HttpServletRequest
import java.math.BigDecimal
import java.time.Instant
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.web.context.request.RequestContextHolder
import org.springframework.web.context.request.ServletRequestAttributes

/** Soort verzoek: een AI-vraag (of de uitwerking ervan) of een zoekopdracht in de collecties. */
enum class RequestKind { AI_QUESTION, COLLECTION_SEARCH }

/** Eén regel uit het logboek, zoals het beheerscherm hem toont. */
data class RequestLogEntry(
    val id: Long,
    val createdAt: Instant,
    val kind: RequestKind,
    val ip: String?,
    val userEmail: String?,
    val question: String,
    val collection: String?,
    /** Verwijzing naar de bron van het verzoek, bij AI-vragen de beurt-id. */
    val reference: String?,
    /** true als dit de uitwerking van een eerder, beknopt antwoord is. */
    val expansion: Boolean,
    val model: String?,
    val status: String,
    /** Milliseconden tot de eerste inhoudelijke terugkoppeling (bij AI: de tussenconclusie). */
    val firstFeedbackMs: Int?,
    /** Milliseconden tot het antwoord (bij zoeken: de duur van de zoekopdracht). */
    val answerMs: Int?,
    val costUsd: BigDecimal?,
)

/**
 * Logboek van alle verzoeken. Het IP-adres komt uit het lopende webverzoek (achter de route via
 * X-Forwarded-For); verzoeken zonder webcontext, zoals de testset, krijgen geen adres. Alle
 * schrijfacties zijn bewust vergevingsgezind: een fout in het logboek mag een verzoek nooit laten
 * mislukken.
 */
@Service
class RequestLogService(private val jdbc: JdbcTemplate) {

    /** Legt een nieuw verzoek vast; bij een AI-vraag met de beurt-id als verwijzing voor latere updates. */
    fun open(kind: RequestKind, question: String, userEmail: String?, reference: String? = null, expansion: Boolean = false, collection: String? = null): Long? =
        runCatching {
            jdbc.queryForObject(
                """
                INSERT INTO request_log (kind, ip, user_email, question, collection, reference, expansion)
                VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id
                """.trimIndent(),
                Long::class.java,
                kind.name, clientAddress(), userEmail?.take(320), question.take(4000), collection?.take(40), reference?.take(64), expansion,
            )
        }.getOrNull()

    /** De eerste inhoudelijke terugkoppeling; alleen de eerste keer telt. */
    fun firstFeedback(reference: String) {
        runCatching {
            jdbc.update(
                """
                UPDATE request_log SET first_feedback_ms = (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) * 1000)::integer
                WHERE reference = ? AND first_feedback_ms IS NULL
                """.trimIndent(),
                reference,
            )
        }
    }

    /** Het verzoek is afgerond (geslaagd, mislukt of gestopt): tijd tot antwoord, model en kosten. */
    fun finish(reference: String, status: String, model: String?, costUsd: BigDecimal?, completedAt: Instant? = null) {
        runCatching {
            jdbc.update(
                """
                UPDATE request_log SET status = ?, model = ?, cost_usd = ?,
                    answer_ms = (EXTRACT(EPOCH FROM (COALESCE(?::timestamptz, CURRENT_TIMESTAMP) - created_at)) * 1000)::integer,
                    first_feedback_ms = COALESCE(first_feedback_ms, (EXTRACT(EPOCH FROM (COALESCE(?::timestamptz, CURRENT_TIMESTAMP) - created_at)) * 1000)::integer)
                WHERE reference = ? AND status = 'RUNNING'
                """.trimIndent(),
                status.take(20), model?.take(200), costUsd, completedAt?.let { java.sql.Timestamp.from(it) }, completedAt?.let { java.sql.Timestamp.from(it) }, reference,
            )
        }
    }

    /** Een zoekopdracht in de collecties: in één keer vastgelegd met de duur. */
    fun logSearch(query: String, collection: String?, userEmail: String?, durationMs: Long) {
        runCatching {
            jdbc.update(
                """
                INSERT INTO request_log (kind, ip, user_email, question, collection, status, first_feedback_ms, answer_ms)
                VALUES (?, ?, ?, ?, ?, 'SUCCEEDED', ?, ?)
                """.trimIndent(),
                RequestKind.COLLECTION_SEARCH.name, clientAddress(), userEmail?.take(320), query.take(4000), collection?.take(40), durationMs.toInt(), durationMs.toInt(),
            )
        }
    }

    fun recent(limit: Int): List<RequestLogEntry> = jdbc.query(
        "SELECT * FROM request_log ORDER BY created_at DESC, id DESC LIMIT ?",
        { rs, _ ->
            RequestLogEntry(
                id = rs.getLong("id"),
                createdAt = rs.getTimestamp("created_at").toInstant(),
                kind = RequestKind.entries.firstOrNull { it.name == rs.getString("kind") } ?: RequestKind.AI_QUESTION,
                ip = rs.getString("ip"),
                userEmail = rs.getString("user_email"),
                question = rs.getString("question"),
                collection = rs.getString("collection"),
                reference = rs.getString("reference"),
                expansion = rs.getBoolean("expansion"),
                model = rs.getString("model"),
                status = rs.getString("status"),
                firstFeedbackMs = (rs.getObject("first_feedback_ms") as Number?)?.toInt(),
                answerMs = (rs.getObject("answer_ms") as Number?)?.toInt(),
                costUsd = rs.getBigDecimal("cost_usd"),
            )
        },
        limit.coerceIn(1, 1000),
    )

    /** Het adres van de aanvrager uit het lopende webverzoek; null buiten een webverzoek. */
    private fun clientAddress(): String? {
        val request = (RequestContextHolder.getRequestAttributes() as? ServletRequestAttributes)?.request ?: return null
        return clientAddress(request)
    }

    companion object {
        /** Achter de OpenShift-route staat de bezoeker vooraan in X-Forwarded-For. */
        fun clientAddress(request: HttpServletRequest): String? =
            request.getHeader("X-Forwarded-For")?.split(',')?.firstOrNull()?.trim()?.takeIf { it.isNotEmpty() }
                ?: request.getHeader("X-Real-IP")?.trim()?.takeIf { it.isNotEmpty() }
                ?: request.remoteAddr
    }
}
