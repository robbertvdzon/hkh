package nl.vdzon.hkh.workflowlog

import java.time.Instant
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service

/** Een melding dat de workflow-app met een andere versie is gestart dan de vorige keer. [reason] zegt of er is bijgewerkt of teruggezet. */
data class VersionChangeReport(val source: String, val computer: String, val previous: String, val current: String, val reason: String)

/** Een versiewissel zoals het beheerscherm hem toont. */
data class VersionChangeEntry(val id: Long, val createdAt: Instant, val source: String, val computer: String, val previous: String, val current: String, val reason: String)

/** Opslag en opvragen van de versiewissels van de workflow-app. Ze worden niet opgeruimd. */
@Service
class WorkflowVersionChangeService(private val jdbc: JdbcTemplate) {
    fun count(): Long = jdbc.queryForObject("SELECT count(*) FROM workflow_version_change", Long::class.java)!!

    fun record(report: VersionChangeReport) {
        jdbc.update(
            "INSERT INTO workflow_version_change (source, computer, previous_version, current_version, reason) VALUES (?, ?, ?, ?, ?)",
            report.source, report.computer, report.previous, report.current, report.reason,
        )
    }

    /** De versiewissels, nieuwste eerst, eventueel van één bron. */
    fun changes(limit: Int = DEFAULT_LIMIT, source: String? = null): List<VersionChangeEntry> = jdbc.query(
        "SELECT id, created_at, source, computer, previous_version, current_version, reason FROM workflow_version_change " +
            "WHERE (?::text IS NULL OR source = ?) ORDER BY created_at DESC, id DESC LIMIT ?",
        { rs, _ ->
            VersionChangeEntry(
                rs.getLong("id"), rs.getTimestamp("created_at").toInstant(), rs.getString("source"), rs.getString("computer"),
                rs.getString("previous_version"), rs.getString("current_version"), rs.getString("reason"),
            )
        }, source, source, limit.coerceIn(1, MAX_LIMIT),
    )

    companion object {
        const val DEFAULT_LIMIT = 200
        const val MAX_LIMIT = 500
    }
}
