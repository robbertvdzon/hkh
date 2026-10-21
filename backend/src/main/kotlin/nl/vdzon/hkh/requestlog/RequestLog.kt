package nl.vdzon.hkh.requestlog

import jakarta.servlet.http.HttpServletRequest
import java.math.BigDecimal
import java.time.Instant
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import nl.vdzon.hkh.auth.AdminAuthConfig
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.web.context.request.RequestContextHolder
import org.springframework.web.context.request.ServletRequestAttributes

/** Naam van het bezoekerscookie van de AI-zoekfunctie; ook de sleutel om unieke bezoekers te tellen. */
const val VISITOR_COOKIE_NAME = "hkh_ai_visitor"

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
    /** Browsertype zoals de bezoeker het meestuurde (ingekort). */
    val userAgent: String? = null,
    /** Bot of script: telt niet mee in de bezoekersaantallen. */
    val bot: Boolean = false,
    /** Testverkeer (beheerder, testset of een aanroep die zich als HKH-Test meldt): telt mee, maar is gemarkeerd. */
    val test: Boolean = false,
    /** Pseudonieme bezoekerssleutel (v: cookie, u: gebruiker, h: hash van adres en browser); na 30 dagen verwijderd. */
    val visitorKey: String? = null,
    /** true als het IP-adres al is afgekapt. */
    val ipAnonymized: Boolean = false,
)

/** Aantallen over een periode, voor de startpagina van beheer. */
data class UsagePeriod(
    val aiQuestions: Long,
    val expansions: Long,
    val searches: Long,
    val uniqueVisitors: Long,
    /** Hoeveel van de unieke bezoekers testverkeer zijn. */
    val testVisitors: Long,
    val testRequests: Long,
    val botRequests: Long,
    val failed: Long,
    val costUsd: BigDecimal,
    val averageAnswerMs: Long?,
)

/**
 * Logboek van alle verzoeken. Het IP-adres komt uit het lopende webverzoek (achter de route via
 * X-Forwarded-For); verzoeken zonder webcontext, zoals de testset, krijgen geen adres. Alle
 * schrijfacties zijn bewust vergevingsgezind: een fout in het logboek mag een verzoek nooit laten
 * mislukken.
 */
@Service
class RequestLogService(private val jdbc: JdbcTemplate, private val adminConfig: AdminAuthConfig) {
    private val salt: String by lazy { loadOrCreateSalt() }

    /** Legt een nieuw verzoek vast; bij een AI-vraag met de beurt-id als verwijzing voor latere updates. */
    fun open(
        kind: RequestKind, question: String, userEmail: String?, reference: String? = null, expansion: Boolean = false,
        collection: String? = null, visitor: String? = null,
    ): Long? = runCatching {
        val who = describeRequester(userEmail, visitor)
        jdbc.queryForObject(
            """
            INSERT INTO request_log (kind, ip, user_email, question, collection, reference, expansion, user_agent, bot, test, visitor_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id
            """.trimIndent(),
            Long::class.java,
            kind.name, who.ip, userEmail?.take(320), question.take(4000), collection?.take(40), reference?.take(64), expansion,
            who.userAgent, who.bot, who.test, who.visitorKey,
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
    fun logSearch(query: String, collection: String?, userEmail: String?, durationMs: Long, userId: String? = null) {
        runCatching {
            val who = describeRequester(userEmail, userId?.let { "u:$it" })
            jdbc.update(
                """
                INSERT INTO request_log (kind, ip, user_email, question, collection, status, first_feedback_ms, answer_ms, user_agent, bot, test, visitor_key)
                VALUES (?, ?, ?, ?, ?, 'SUCCEEDED', ?, ?, ?, ?, ?, ?)
                """.trimIndent(),
                RequestKind.COLLECTION_SEARCH.name, who.ip, userEmail?.take(320), query.take(4000), collection?.take(40), durationMs.toInt(), durationMs.toInt(),
                who.userAgent, who.bot, who.test, who.visitorKey,
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
                userAgent = rs.getString("user_agent"),
                bot = rs.getBoolean("bot"),
                test = rs.getBoolean("test"),
                visitorKey = rs.getString("visitor_key"),
                ipAnonymized = rs.getBoolean("ip_anonymized"),
            )
        },
        limit.coerceIn(1, 1000),
    )

    /** Aantallen sinds [since]: verzoeken, unieke bezoekers (zonder bots), testverkeer, fouten, kosten en gemiddelde antwoordtijd. */
    fun usage(since: Instant): UsagePeriod = jdbc.queryForObject(
        """
        SELECT
          count(*) FILTER (WHERE kind = 'AI_QUESTION' AND NOT expansion AND NOT bot) AS ai,
          count(*) FILTER (WHERE kind = 'AI_QUESTION' AND expansion AND NOT bot) AS expansions,
          count(*) FILTER (WHERE kind = 'COLLECTION_SEARCH' AND NOT bot) AS searches,
          count(DISTINCT visitor_key) FILTER (WHERE NOT bot AND visitor_key IS NOT NULL) AS visitors,
          count(DISTINCT visitor_key) FILTER (WHERE NOT bot AND test AND visitor_key IS NOT NULL) AS test_visitors,
          count(*) FILTER (WHERE test AND NOT bot) AS test_requests,
          count(*) FILTER (WHERE bot) AS bots,
          count(*) FILTER (WHERE kind = 'AI_QUESTION' AND status = 'FAILED') AS failed,
          coalesce(sum(cost_usd), 0) AS cost,
          avg(answer_ms) FILTER (WHERE kind = 'AI_QUESTION' AND status = 'SUCCEEDED' AND NOT bot) AS average_ms
        FROM request_log WHERE created_at >= ?
        """.trimIndent(),
        { rs, _ ->
            UsagePeriod(
                aiQuestions = rs.getLong("ai"), expansions = rs.getLong("expansions"), searches = rs.getLong("searches"),
                uniqueVisitors = rs.getLong("visitors"), testVisitors = rs.getLong("test_visitors"), testRequests = rs.getLong("test_requests"),
                botRequests = rs.getLong("bots"), failed = rs.getLong("failed"), costUsd = rs.getBigDecimal("cost"),
                averageAnswerMs = (rs.getObject("average_ms") as Number?)?.toLong(),
            )
        },
        java.sql.Timestamp.from(since),
    )!!

    /**
     * Kapt de IP-adressen van regels ouder dan [retentionDays] af en verwijdert hun bezoekerssleutel. De
     * regel zelf blijft staan voor de statistieken. Geeft het aantal bijgewerkte regels terug.
     */
    fun anonymizeOld(retentionDays: Int = RETENTION_DAYS): Int {
        var total = 0
        while (true) {
            val rows = jdbc.query(
                "SELECT id, ip FROM request_log WHERE NOT ip_anonymized AND created_at < CURRENT_TIMESTAMP - make_interval(days => ?) ORDER BY id LIMIT 500",
                { rs, _ -> rs.getLong("id") to rs.getString("ip") },
                retentionDays,
            )
            if (rows.isEmpty()) return total
            for ((id, ip) in rows) {
                jdbc.update("UPDATE request_log SET ip = ?, visitor_key = NULL, ip_anonymized = TRUE WHERE id = ?", RequestClassifier.anonymizeIp(ip), id)
            }
            total += rows.size
        }
    }

    // ---- Wie vraagt het? ----

    private class Requester(val ip: String?, val userAgent: String?, val bot: Boolean, val test: Boolean, val visitorKey: String?)

    /**
     * Adres, browsertype, bot- en testmarkering en bezoekerssleutel uit het lopende webverzoek. Buiten een
     * webverzoek, zoals bij de testset, is er geen adres en geen browsertype.
     */
    private fun describeRequester(userEmail: String?, visitor: String?): Requester {
        val request = (RequestContextHolder.getRequestAttributes() as? ServletRequestAttributes)?.request
        val ip = request?.let(::clientAddress)
        val agent = request?.getHeader("User-Agent")?.trim()?.take(300)
        val test = RequestClassifier.isTestAgent(agent) ||
            userEmail?.startsWith("testset:") == true ||
            (userEmail != null && adminConfig.isAllowed(userEmail))
        val bot = request != null && RequestClassifier.isBot(agent)
        val key = visitor ?: request?.let(::cookieVisitor) ?: ip?.let { "h:" + sign("$it|${agent.orEmpty()}") }
        return Requester(ip, agent, bot, test, key)
    }

    private fun cookieVisitor(request: HttpServletRequest): String? =
        request.cookies?.firstOrNull { it.name == VISITOR_COOKIE_NAME }?.value
            ?.let { runCatching { UUID.fromString(it).toString() }.getOrNull() }?.let { "v:$it" }

    private fun sign(value: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(salt.toByteArray(), "HmacSHA256"))
        return mac.doFinal(value.toByteArray()).joinToString("") { "%02x".format(it) }.take(24)
    }

    /** Het geheim voor de hash van adres en browser; één keer aangemaakt en bewaard in de instellingen. */
    private fun loadOrCreateSalt(): String = runCatching {
        jdbc.update(
            "INSERT INTO app_setting (key, value, updated_at, updated_by) VALUES ('request-log.salt', ?, CURRENT_TIMESTAMP, 'system') ON CONFLICT (key) DO NOTHING",
            UUID.randomUUID().toString() + UUID.randomUUID().toString(),
        )
        jdbc.queryForObject("SELECT value FROM app_setting WHERE key = 'request-log.salt'", String::class.java)!!
    }.getOrElse { UUID.randomUUID().toString() }

    companion object {
        const val RETENTION_DAYS = 30

        /**
         * Het echte adres van de bezoeker: achter Cloudflare staat het in CF-Connecting-IP (dat een client niet zelf
         * kan invullen); anders vooraan in X-Forwarded-For van de route.
         */
        fun clientAddress(request: HttpServletRequest): String? =
            request.getHeader("CF-Connecting-IP")?.trim()?.takeIf { it.isNotEmpty() }
                ?: request.getHeader("X-Forwarded-For")?.split(',')?.firstOrNull()?.trim()?.takeIf { it.isNotEmpty() }
                ?: request.getHeader("X-Real-IP")?.trim()?.takeIf { it.isNotEmpty() }
                ?: request.remoteAddr
    }
}
