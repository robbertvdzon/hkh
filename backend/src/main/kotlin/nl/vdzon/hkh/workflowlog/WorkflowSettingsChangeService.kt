package nl.vdzon.hkh.workflowlog

import java.sql.ResultSet
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/** Opslag en opvragen van de wijzigingen in de instellingen van de workflow-app. Ze worden niet opgeruimd. */
@Service
class WorkflowSettingsChangeService(private val jdbc: JdbcTemplate, private val objectMapper: ObjectMapper) {
    fun count(): Long = jdbc.queryForObject("SELECT count(*) FROM workflow_settings_change", Long::class.java)!!

    fun record(report: SettingsChangeReport) {
        val changes = objectMapper.writeValueAsString(report.changes.map { mapOf("field" to it.field, "old" to it.old, "new" to it.new) })
        jdbc.update(
            "INSERT INTO workflow_settings_change (source, computer, app_version, user_name, address, reason, changes, settings) VALUES (?, ?, ?, ?, ?, ?, ?::jsonb, ?::jsonb)",
            report.source, report.computer, report.appVersion, report.user, report.address, report.reason, changes, objectMapper.writeValueAsString(report.settings),
        )
    }

    /** De wijzigingen, nieuwste eerst, eventueel van één bron. */
    fun changes(limit: Int = DEFAULT_LIMIT, source: String? = null): List<SettingsChangeSummary> = jdbc.query(
        "SELECT id, created_at, source, computer, app_version, user_name, address, reason, changes FROM workflow_settings_change " +
            "WHERE (?::text IS NULL OR source = ?) ORDER BY created_at DESC, id DESC LIMIT ?",
        { rs, _ -> summary(rs) }, source, source, limit.coerceIn(1, MAX_LIMIT),
    )

    /** Eén wijziging met de volledige nieuwe instellingen, of null als hij niet bestaat. */
    fun change(id: Long): SettingsChangeDetail? = jdbc.query(
        "SELECT id, created_at, source, computer, app_version, user_name, address, reason, changes, settings::text AS settings FROM workflow_settings_change WHERE id = ?",
        { rs, _ ->
            val s = summary(rs)
            SettingsChangeDetail(s.id, s.createdAt, s.source, s.computer, s.appVersion, s.user, s.address, s.reason, s.changeCount, s.changes, objectMapper.readTree(rs.getString("settings")))
        }, id,
    ).firstOrNull()

    private fun summary(rs: ResultSet): SettingsChangeSummary {
        val node: JsonNode = objectMapper.readTree(rs.getString("changes"))
        val changes = (0 until node.size()).map { i ->
            val c = node.get(i)
            SettingChange(c.path("field").asString(""), c.get("old")?.takeIf { it.isString }?.stringValue(), c.get("new")?.takeIf { it.isString }?.stringValue())
        }
        return SettingsChangeSummary(
            id = rs.getLong("id"), createdAt = rs.getTimestamp("created_at").toInstant(), source = rs.getString("source"), computer = rs.getString("computer"),
            appVersion = rs.getString("app_version"), user = rs.getString("user_name"), address = rs.getString("address"), reason = rs.getString("reason"),
            changeCount = changes.size, changes = changes,
        )
    }

    companion object {
        const val DEFAULT_LIMIT = 100
        const val MAX_LIMIT = 500
    }
}
