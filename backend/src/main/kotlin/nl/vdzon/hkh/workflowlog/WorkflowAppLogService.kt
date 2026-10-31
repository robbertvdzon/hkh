package nl.vdzon.hkh.workflowlog

import java.sql.Timestamp
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Base64
import org.springframework.beans.factory.annotation.Value
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

/** De cursor van een pagina uit het app-log klopt niet. */
class AppLogCursorInvalid : RuntimeException("Ongeldige cursor")

/**
 * Opslag en opvragen van het app-log: de logregels (INFO en hoger) die de workflow-app in pakketjes opstuurt. Deze regels worden,
 * anders dan de sessies en inlogpogingen, na [retentionDays] dagen opgeruimd. Alle tijdgevoelige functies nemen `now` mee, zodat ze
 * met een eigen klok te testen zijn.
 */
@Service
class WorkflowAppLogService(
    private val jdbc: JdbcTemplate,
    @param:Value("\${hkh.workflow-log.app-log-retention-days:30}") private val retentionDays: Int,
) {
    /**
     * Bewaart een pakketje. Een pakketje met een chunkId dat al eerder van deze bron en computer kwam, wordt genegeerd (herhaling na een
     * time-out). Regels van ouder dan de bewaartermijn of van meer dan twee dagen in de toekomst worden weggegooid. Geeft het aantal
     * bewaarde regels terug; 0 bij een herhaling.
     */
    @Transactional
    fun record(chunk: AppLogChunk, now: Instant = Instant.now()): Int {
        val oldest = now.minus(Duration.ofDays(retentionDays.toLong()))
        val newest = now.plus(MAX_FUTURE)
        val lines = chunk.lines.filter { it.time in oldest..newest }
        val isNew = jdbc.update(
            "INSERT INTO workflow_app_log_chunk (source, computer, chunk_id, received_at) VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING",
            chunk.source, chunk.computer, chunk.chunkId, Timestamp.from(now),
        ) > 0
        if (!isNew || lines.isEmpty()) return 0
        jdbc.batchUpdate(
            "INSERT INTO workflow_app_log (received_at, logged_at, level, logger, message, source, computer, app_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            lines, BATCH_SIZE,
        ) { ps, line ->
            ps.setTimestamp(1, Timestamp.from(now))
            ps.setTimestamp(2, Timestamp.from(line.time))
            ps.setString(3, line.level)
            ps.setString(4, line.logger)
            ps.setString(5, line.message)
            ps.setString(6, chunk.source)
            ps.setString(7, chunk.computer)
            ps.setString(8, chunk.appVersion)
        }
        return lines.size
    }

    /** Verwijdert wat ouder is dan de bewaartermijn: regels op hun logtijd, pakketnamen op hun ontvangsttijd. Geeft het aantal verwijderde regels. */
    @Transactional
    fun deleteExpired(now: Instant = Instant.now()): Int {
        val limit = Timestamp.from(now.minus(Duration.ofDays(retentionDays.toLong())))
        jdbc.update("DELETE FROM workflow_app_log_chunk WHERE received_at < ?", limit)
        return jdbc.update("DELETE FROM workflow_app_log WHERE logged_at < ?", limit)
    }

    /**
     * Logregels, nieuwste eerst. [minLevel] is een minimumniveau (WARN geeft ook ERROR), [query] zoekt zonder hoofdletters in bericht en logger.
     * [before] is de cursor uit [AppLogPage.next] van de vorige pagina.
     */
    fun entries(
        source: String? = null, computer: String? = null, minLevel: String? = null, version: String? = null,
        query: String? = null, before: String? = null, limit: Int = DEFAULT_LIMIT,
    ): AppLogPage {
        val size = limit.coerceIn(1, MAX_LIMIT)
        val where = mutableListOf<String>()
        val args = mutableListOf<Any>()
        source?.takeIf { it.isNotBlank() }?.let { where += "source = ?"; args += it }
        computer?.takeIf { it.isNotBlank() }?.let { where += "computer = ?"; args += it }
        version?.takeIf { it.isNotBlank() }?.let { where += "app_version = ?"; args += it }
        when (minLevel?.trim()?.uppercase()) {
            "WARN" -> where += "level IN ('WARN', 'ERROR')"
            "ERROR" -> where += "level = 'ERROR'"
        }
        query?.takeIf { it.isNotBlank() }?.let {
            val pattern = "%" + it.trim().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
            where += "(message ILIKE ? ESCAPE '\\' OR logger ILIKE ? ESCAPE '\\')"
            args += pattern; args += pattern
        }
        before?.takeIf { it.isNotBlank() }?.let {
            val (at, id) = decodeCursor(it)
            where += "(logged_at, id) < (?, ?)"
            args += Timestamp.from(at); args += id
        }
        val sql = "SELECT id, logged_at, level, logger, message, source, computer, app_version FROM workflow_app_log" +
            (if (where.isEmpty()) "" else " WHERE " + where.joinToString(" AND ")) +
            " ORDER BY logged_at DESC, id DESC LIMIT ?"
        args += size + 1
        val rows = jdbc.query(sql, { rs, _ ->
            AppLogEntry(
                id = rs.getLong("id"), time = rs.getTimestamp("logged_at").toInstant(), level = rs.getString("level"),
                logger = rs.getString("logger"), message = rs.getString("message"), source = rs.getString("source"),
                computer = rs.getString("computer"), appVersion = rs.getString("app_version"),
            )
        }, *args.toTypedArray())
        val items = rows.take(size)
        return AppLogPage(items, if (rows.size > size) encodeCursor(items.last()) else null)
    }

    /** Per bron en computer: de versie van de nieuwste regel, wanneer er voor het laatst iets binnenkwam en de aantallen van de laatste 24 uur. */
    fun overview(now: Instant = Instant.now()): List<AppLogOverviewRow> {
        val since = Timestamp.from(now.minus(Duration.ofHours(24)))
        return jdbc.query(
            """
            SELECT source, computer,
                   (array_agg(app_version ORDER BY logged_at DESC, id DESC))[1] AS app_version,
                   max(received_at) AS last_seen,
                   count(*) FILTER (WHERE logged_at >= ?) AS lines24h,
                   count(*) FILTER (WHERE logged_at >= ? AND level = 'WARN') AS warnings24h,
                   count(*) FILTER (WHERE logged_at >= ? AND level = 'ERROR') AS errors24h
            FROM workflow_app_log GROUP BY source, computer ORDER BY last_seen DESC, source, computer
            """.trimIndent(),
            { rs, _ ->
                AppLogOverviewRow(
                    source = rs.getString("source"), computer = rs.getString("computer"), appVersion = rs.getString("app_version"),
                    lastSeen = rs.getTimestamp("last_seen").toInstant(), lines24h = rs.getInt("lines24h"),
                    warnings24h = rs.getInt("warnings24h"), errors24h = rs.getInt("errors24h"),
                )
            }, since, since, since,
        )
    }

    /** De versies van de app waarvan er regels zijn, de nieuwste (laatst gelogd) eerst. */
    fun versions(): List<String> = jdbc.queryForList(
        "SELECT app_version FROM workflow_app_log WHERE app_version IS NOT NULL GROUP BY app_version ORDER BY max(logged_at) DESC, app_version",
        String::class.java,
    )

    private fun encodeCursor(entry: AppLogEntry): String {
        val micros = ChronoUnit.MICROS.between(Instant.EPOCH, entry.time)
        return Base64.getUrlEncoder().withoutPadding().encodeToString("$micros:${entry.id}".toByteArray())
    }

    private fun decodeCursor(cursor: String): Pair<Instant, Long> = try {
        val (micros, id) = String(Base64.getUrlDecoder().decode(cursor.trim())).split(':', limit = 2)
        Instant.EPOCH.plus(micros.toLong(), ChronoUnit.MICROS) to id.toLong()
    } catch (_: Exception) {
        throw AppLogCursorInvalid()
    }

    companion object {
        const val DEFAULT_LIMIT = 200
        const val MAX_LIMIT = 1000
        private const val BATCH_SIZE = 1000

        /** Regels die verder in de toekomst liggen, komen van een computer met een verkeerde klok en worden weggegooid. */
        val MAX_FUTURE: Duration = Duration.ofDays(2)
    }
}
