package nl.vdzon.hkh.news

import java.sql.ResultSet
import java.sql.Timestamp
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository

interface LatestNewsStore {
    fun findAll(): List<LatestNews>
    fun create(title: String, message: String, createdBy: String): LatestNews
}

@Repository
class LatestNewsRepository(private val jdbcTemplate: JdbcTemplate) : LatestNewsStore, PreviewLatestNewsSeedStore {
    override fun findAll(): List<LatestNews> = jdbcTemplate.query(
        """
        SELECT id, title, message, published_at, created_at, created_by
        FROM latest_news
        ORDER BY published_at DESC, id DESC
        """.trimIndent(),
        rowMapper,
    )

    override fun create(title: String, message: String, createdBy: String): LatestNews = jdbcTemplate.query(
        """
        INSERT INTO latest_news (title, message, created_by)
        VALUES (?, ?, ?)
        RETURNING id, title, message, published_at, created_at, created_by
        """.trimIndent(),
        rowMapper,
        title,
        message,
        createdBy,
    ).single()

    override fun upsert(records: List<PreviewLatestNewsSeed>) {
        records.forEach { record ->
            jdbcTemplate.update(
                """
                INSERT INTO latest_news (id, title, message, published_at, created_at, created_by)
                OVERRIDING SYSTEM VALUE
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET
                    title = EXCLUDED.title,
                    message = EXCLUDED.message,
                    published_at = EXCLUDED.published_at,
                    created_at = EXCLUDED.created_at,
                    created_by = EXCLUDED.created_by
                """.trimIndent(),
                record.id,
                record.title,
                record.message,
                Timestamp.from(record.publishedAt),
                Timestamp.from(record.createdAt),
                record.createdBy,
            )
        }
    }

    private companion object {
        val rowMapper = RowMapper { result: ResultSet, _: Int ->
            LatestNews(
                id = result.getLong("id"),
                title = result.getString("title"),
                message = result.getString("message"),
                publishedAt = result.getTimestamp("published_at").toInstant(),
                createdAt = result.getTimestamp("created_at").toInstant(),
                createdBy = result.getString("created_by"),
            )
        }
    }
}
