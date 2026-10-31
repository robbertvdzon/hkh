package nl.vdzon.hkh.workflowlog

import java.security.MessageDigest
import java.time.Duration
import java.time.Instant
import java.util.UUID
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/** Het sessiegeheim hoort niet bij deze sessie: de melding komt van iemand anders dan de maker. */
class WorkflowSessionForbidden : RuntimeException("Sessiegeheim klopt niet")

/** Opslag en opvragen van het workflow-logboek: inlogpogingen en sessies van de workflow-app. */
@Service
class WorkflowLogService(private val jdbc: JdbcTemplate, private val objectMapper: ObjectMapper) {
    fun sessionExists(id: UUID): Boolean =
        jdbc.queryForObject("SELECT count(*) FROM workflow_session WHERE id = ?", Long::class.java, id)!! > 0

    fun sessionCount(): Long = jdbc.queryForObject("SELECT count(*) FROM workflow_session", Long::class.java)!!

    fun recordLogin(report: WorkflowLoginReport, ip: String?) {
        jdbc.update(
            "INSERT INTO workflow_login (user_name, success, method, detail, app_version, computer, ip, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            report.user, report.success, report.method, report.detail, report.appVersion, report.computer, ip?.take(64), report.source,
        )
    }

    /**
     * Maakt de sessie aan of werkt hem bij met de volledige momentopname. Het geheugen van de app is de bron: elke
     * melding vervangt de vorige. Alleen wie het sessiegeheim kent mag een bestaande sessie bijwerken.
     */
    @Transactional
    fun record(report: WorkflowSessionReport, snapshot: JsonNode?, ip: String?) {
        val hash = hash(report.secret)
        val previous = jdbc.query(
            "SELECT phase, status, secret_hash FROM workflow_session WHERE id = ? FOR UPDATE",
            { rs, _ -> Triple(rs.getInt("phase"), rs.getString("status"), rs.getString("secret_hash")) }, report.id,
        ).firstOrNull()
        if (previous != null && previous.third != hash) throw WorkflowSessionForbidden()
        val json = snapshot?.let(objectMapper::writeValueAsString)
        if (previous == null) {
            jdbc.update(
                """
                INSERT INTO workflow_session (id, kind, secret_hash, user_name, collection, phase, phase_count, phase_label, status, file_count, app_version, computer, ip, source, snapshot)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?::jsonb, '{}'::jsonb))
                """.trimIndent(),
                report.id, report.kind.name, hash, report.user, report.collection, report.phase, report.phaseCount, report.phaseLabel,
                report.status.name, report.fileCount, report.appVersion, report.computer, ip?.take(64), report.source, json,
            )
        } else {
            jdbc.update(
                """
                UPDATE workflow_session SET updated_at = CURRENT_TIMESTAMP, updates = updates + 1, user_name = COALESCE(?, user_name),
                    collection = COALESCE(?, collection), phase = ?, phase_count = ?, phase_label = ?, status = ?, file_count = ?,
                    app_version = COALESCE(?, app_version), computer = COALESCE(?, computer), source = COALESCE(?, source), snapshot = COALESCE(?::jsonb, snapshot)
                WHERE id = ?
                """.trimIndent(),
                report.user, report.collection, report.phase, report.phaseCount, report.phaseLabel, report.status.name, report.fileCount,
                report.appVersion, report.computer, report.source, json, report.id,
            )
        }
        val changed = previous == null || previous.first != report.phase || previous.second != report.status.name
        val message = report.event ?: if (changed) defaultMessage(report, previous == null) else null
        if (message != null) {
            jdbc.update(
                "INSERT INTO workflow_session_event (session_id, phase, phase_label, status, message) VALUES (?, ?, ?, ?, ?)",
                report.id, report.phase, report.phaseLabel, report.status.name, message.take(500),
            )
        }
    }

    private fun defaultMessage(report: WorkflowSessionReport, first: Boolean) = when {
        first -> "Sessie gestart"
        report.status == WorkflowStatus.FINISHED -> "Klaar"
        report.status == WorkflowStatus.FAILED -> "Mislukt"
        else -> "Fase ${report.phase}${report.phaseLabel?.let { ": $it" } ?: ""}"
    }

    /** De bronnen die ooit iets hebben gemeld, alfabetisch. */
    fun sources(): List<String> = jdbc.queryForList(
        "SELECT source FROM (SELECT source FROM workflow_login UNION SELECT source FROM workflow_session) s WHERE source IS NOT NULL ORDER BY source",
        String::class.java,
    )

    fun logins(limit: Int, source: String? = null): List<WorkflowLoginEntry> = jdbc.query(
        "SELECT * FROM workflow_login WHERE (?::text IS NULL OR source = ?) ORDER BY created_at DESC, id DESC LIMIT ?",
        { rs, _ ->
            WorkflowLoginEntry(
                id = rs.getLong("id"), createdAt = rs.getTimestamp("created_at").toInstant(), user = rs.getString("user_name"),
                success = rs.getBoolean("success"), method = rs.getString("method"), detail = rs.getString("detail"),
                appVersion = rs.getString("app_version"), computer = rs.getString("computer"), ip = rs.getString("ip"),
                source = rs.getString("source"),
            )
        },
        source, source, limit.coerceIn(1, 1000),
    )

    fun sessions(kind: WorkflowKind, limit: Int, source: String? = null, now: Instant = Instant.now()): List<WorkflowSessionSummary> = jdbc.query(
        "SELECT id, kind, created_at, updated_at, user_name, collection, phase, phase_count, phase_label, status, file_count, updates, app_version, computer, ip, source " +
            "FROM workflow_session WHERE kind = ? AND (?::text IS NULL OR source = ?) ORDER BY created_at DESC LIMIT ?",
        { rs, _ -> summary(rs, now) }, kind.name, source, source, limit.coerceIn(1, 1000),
    )

    fun session(id: UUID, now: Instant = Instant.now()): WorkflowSessionDetail? {
        val row = jdbc.query(
            "SELECT id, kind, created_at, updated_at, user_name, collection, phase, phase_count, phase_label, status, file_count, updates, app_version, computer, ip, source, snapshot::text AS snapshot " +
                "FROM workflow_session WHERE id = ?",
            { rs, _ -> summary(rs, now) to rs.getString("snapshot") }, id,
        ).firstOrNull() ?: return null
        val events = jdbc.query(
            "SELECT id, created_at, phase, phase_label, status, message FROM workflow_session_event WHERE session_id = ? ORDER BY id",
            { rs, _ ->
                WorkflowEventEntry(rs.getLong("id"), rs.getTimestamp("created_at").toInstant(), rs.getInt("phase"), rs.getString("phase_label"), rs.getString("status"), rs.getString("message"))
            }, id,
        )
        return WorkflowSessionDetail(row.first, objectMapper.readTree(row.second), events)
    }

    private fun summary(rs: java.sql.ResultSet, now: Instant): WorkflowSessionSummary {
        val updated = rs.getTimestamp("updated_at").toInstant()
        val status = rs.getString("status")
        return WorkflowSessionSummary(
            id = UUID.fromString(rs.getString("id")), kind = WorkflowKind.valueOf(rs.getString("kind")),
            createdAt = rs.getTimestamp("created_at").toInstant(), updatedAt = updated, user = rs.getString("user_name"),
            collection = rs.getString("collection"), phase = rs.getInt("phase"), phaseCount = rs.getInt("phase_count"),
            phaseLabel = rs.getString("phase_label"),
            status = if (status == WorkflowStatus.RUNNING.name && Duration.between(updated, now) > ABANDONED_AFTER) "ABANDONED" else status,
            fileCount = rs.getInt("file_count"), updates = rs.getInt("updates"), appVersion = rs.getString("app_version"),
            computer = rs.getString("computer"), ip = rs.getString("ip"), source = rs.getString("source"),
        )
    }

    companion object {
        /** Een doorloop die zo lang niets meldt en niet is afgerond, geldt als verlaten. */
        val ABANDONED_AFTER: Duration = Duration.ofMinutes(30)

        fun hash(secret: String): String =
            MessageDigest.getInstance("SHA-256").digest(secret.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
