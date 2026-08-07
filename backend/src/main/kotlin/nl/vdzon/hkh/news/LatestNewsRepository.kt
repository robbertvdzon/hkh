package nl.vdzon.hkh.news

import java.sql.ResultSet
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository

interface LatestNewsStore {
    fun findAll(): List<LatestNews>
    fun create(title: String, message: String, createdBy: String): LatestNews
}

@Repository
class LatestNewsRepository(private val jdbcTemplate: JdbcTemplate) : LatestNewsStore {
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
