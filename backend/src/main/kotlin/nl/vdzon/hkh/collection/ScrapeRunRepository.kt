package nl.vdzon.hkh.collection

import java.sql.ResultSet
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository
import tools.jackson.databind.ObjectMapper

interface ScrapeRunStore {
    fun start(startedBy: String, force: Boolean): Long
    fun update(run: RunProgress)
    fun finish(id: Long, status: ScrapeStatus, message: String?)
    fun latest(): ScrapeRun?
    fun anyRunning(): Boolean
}

/** Mutabele voortgang die de scraper tijdens het draaien bijwerkt. */
data class RunProgress(
    val id: Long,
    var total: Int = 0,
    var processed: Int = 0,
    var skipped: Int = 0,
    var failed: Int = 0,
    var currentCollection: String? = null,
    val perCollection: MutableMap<String, Int> = linkedMapOf(),
)

@Repository
class ScrapeRunRepository(
    private val jdbc: JdbcTemplate,
    private val objectMapper: ObjectMapper,
) : ScrapeRunStore {

    override fun start(startedBy: String, force: Boolean): Long =
        jdbc.queryForObject(
            """
            INSERT INTO scrape_run (status, started_by, force_rescrape)
            VALUES ('RUNNING', ?, ?)
            RETURNING id
            """.trimIndent(),
            Long::class.java,
            startedBy,
            force,
        )!!

    override fun update(run: RunProgress) {
        jdbc.update(
            """
            UPDATE scrape_run
            SET total = ?, processed = ?, skipped = ?, failed = ?,
                current_collection = ?, per_collection = ?::jsonb
            WHERE id = ?
            """.trimIndent(),
            run.total,
            run.processed,
            run.skipped,
            run.failed,
            run.currentCollection,
            objectMapper.writeValueAsString(run.perCollection),
            run.id,
        )
    }

    override fun finish(id: Long, status: ScrapeStatus, message: String?) {
        jdbc.update(
            """
            UPDATE scrape_run
            SET status = ?, message = ?, current_collection = NULL, finished_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """.trimIndent(),
            status.name,
            message,
            id,
        )
    }

    override fun latest(): ScrapeRun? =
        jdbc.query("SELECT * FROM scrape_run ORDER BY started_at DESC, id DESC LIMIT 1", rowMapper)
            .singleOrNull()

    override fun anyRunning(): Boolean =
        (jdbc.queryForObject("SELECT COUNT(*) FROM scrape_run WHERE status = 'RUNNING'", Long::class.java) ?: 0) > 0

    private val rowMapper = RowMapper { rs: ResultSet, _: Int ->
        ScrapeRun(
            id = rs.getLong("id"),
            status = ScrapeStatus.valueOf(rs.getString("status")),
            startedBy = rs.getString("started_by"),
            force = rs.getBoolean("force_rescrape"),
            startedAt = rs.getTimestamp("started_at").toInstant(),
            finishedAt = rs.getTimestamp("finished_at")?.toInstant(),
            total = rs.getInt("total"),
            processed = rs.getInt("processed"),
            skipped = rs.getInt("skipped"),
            failed = rs.getInt("failed"),
            currentCollection = rs.getString("current_collection"),
            message = rs.getString("message"),
            perCollection = parseCounts(rs.getString("per_collection")),
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseCounts(json: String?): Map<String, Int> {
        if (json.isNullOrBlank()) return emptyMap()
        val raw = objectMapper.readValue(json, Map::class.java) as Map<String, Any?>
        return raw.mapValues { (it.value as? Number)?.toInt() ?: 0 }
    }
}
