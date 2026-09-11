package nl.vdzon.hkh.collection

import java.sql.ResultSet
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository
import tools.jackson.databind.ObjectMapper

interface CollectionItemStore {
    fun upsert(record: ScrapedRecord)
    fun upsertSummary(summary: ListSummary)
    fun existingIdents(collection: String): Set<String>
    fun completeIdents(collection: String): Set<String>
    fun counts(): List<CollectionCount>
    fun totalCount(): Long
    fun find(collection: String, ident: String): CollectionItem?
    fun search(query: String?, collection: String?, field: String?, limit: Int, offset: Int): List<CollectionItem>
    fun searchCount(query: String?, collection: String?, field: String?): Long
    fun distinctFields(collection: String?): List<String>
}

@Repository
class CollectionItemRepository(
    private val jdbc: JdbcTemplate,
    private val objectMapper: ObjectMapper,
) : CollectionItemStore {

    override fun upsert(record: ScrapedRecord) {
        val fieldsJson = objectMapper.writeValueAsString(record.fields)
        val searchText = buildSearchText(record.title, record.description, record.ident, record.fields)
        jdbc.update(
            """
            INSERT INTO collection_item
                (collection, ident, title, description, year, image_url, pdf_url, detail_url, fields, search_text, is_complete, scraped_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb, ?, true, CURRENT_TIMESTAMP)
            ON CONFLICT (collection, ident) DO UPDATE SET
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                year = EXCLUDED.year,
                image_url = EXCLUDED.image_url,
                pdf_url = EXCLUDED.pdf_url,
                detail_url = EXCLUDED.detail_url,
                fields = EXCLUDED.fields,
                search_text = EXCLUDED.search_text,
                is_complete = true,
                scraped_at = CURRENT_TIMESTAMP
            """.trimIndent(),
            record.collection,
            record.ident,
            record.title,
            record.description,
            record.year,
            record.imageUrl,
            record.pdfUrl,
            record.detailUrl,
            fieldsJson,
            searchText,
        )
    }

    /**
     * Slaat een lijstpagina-samenvatting op. Overschrijft nooit een al-complete rij (die uit
     * [upsert] komt): een snelle scan mag data alleen aanvullen, niet degraderen.
     */
    override fun upsertSummary(summary: ListSummary) {
        val fieldsJson = objectMapper.writeValueAsString(summary.fields)
        val searchText = buildSearchText(summary.title, summary.description, summary.ident, summary.fields)
        jdbc.update(
            """
            INSERT INTO collection_item
                (collection, ident, title, description, year, image_url, detail_url, fields, search_text, is_complete, scraped_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?::jsonb, ?, false, CURRENT_TIMESTAMP)
            ON CONFLICT (collection, ident) DO UPDATE SET
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                year = EXCLUDED.year,
                image_url = EXCLUDED.image_url,
                detail_url = EXCLUDED.detail_url,
                fields = EXCLUDED.fields,
                search_text = EXCLUDED.search_text,
                scraped_at = CURRENT_TIMESTAMP
            WHERE collection_item.is_complete = false
            """.trimIndent(),
            summary.collection,
            summary.ident,
            summary.title,
            summary.description,
            summary.year,
            summary.imageUrl,
            summary.detailUrl,
            fieldsJson,
            searchText,
        )
    }

    override fun existingIdents(collection: String): Set<String> =
        jdbc.query(
            "SELECT ident FROM collection_item WHERE collection = ?",
            { rs, _ -> rs.getString("ident") },
            collection,
        ).toHashSet()

    override fun completeIdents(collection: String): Set<String> =
        jdbc.query(
            "SELECT ident FROM collection_item WHERE collection = ? AND is_complete = true",
            { rs, _ -> rs.getString("ident") },
            collection,
        ).toHashSet()

    override fun counts(): List<CollectionCount> =
        jdbc.query(
            "SELECT collection, COUNT(*) AS c FROM collection_item GROUP BY collection ORDER BY collection",
        ) { rs, _ -> CollectionCount(rs.getString("collection"), rs.getLong("c")) }

    override fun totalCount(): Long =
        jdbc.queryForObject("SELECT COUNT(*) FROM collection_item", Long::class.java) ?: 0

    override fun find(collection: String, ident: String): CollectionItem? =
        jdbc.query(
            "SELECT * FROM collection_item WHERE collection = ? AND ident = ?",
            rowMapper,
            collection,
            ident,
        ).singleOrNull()

    override fun search(query: String?, collection: String?, field: String?, limit: Int, offset: Int): List<CollectionItem> {
        val (where, args) = buildWhere(query, collection, field)
        val ordering: String
        val orderArgs: List<Any>
        if (query.isNullOrBlank()) {
            ordering = "ORDER BY collection, year DESC NULLS LAST, ident"
            orderArgs = emptyList()
        } else {
            val match = matchClause(field)
            ordering = "ORDER BY ts_rank(${match.expr}, websearch_to_tsquery('dutch', ?)) DESC, year DESC NULLS LAST"
            orderArgs = match.exprArgs + listOf(query)
        }
        val fullArgs = args + orderArgs + listOf(limit, offset)
        return jdbc.query(
            "SELECT * FROM collection_item $where $ordering LIMIT ? OFFSET ?",
            rowMapper,
            *fullArgs.toTypedArray(),
        )
    }

    override fun searchCount(query: String?, collection: String?, field: String?): Long {
        val (where, args) = buildWhere(query, collection, field)
        return jdbc.queryForObject(
            "SELECT COUNT(*) FROM collection_item $where",
            Long::class.java,
            *args.toTypedArray(),
        ) ?: 0
    }

    override fun distinctFields(collection: String?): List<String> =
        if (collection.isNullOrBlank()) {
            jdbc.query(
                "SELECT DISTINCT key FROM collection_item, jsonb_object_keys(fields) AS key ORDER BY key LIMIT 200",
            ) { rs, _ -> rs.getString(1) }
        } else {
            jdbc.query(
                "SELECT DISTINCT key FROM collection_item, jsonb_object_keys(fields) AS key WHERE collection = ? ORDER BY key LIMIT 200",
                { rs, _ -> rs.getString(1) },
                collection,
            )
        }

    /** Bepaalt tegen welke tsvector-expressie gezocht wordt: alles, een vaste kolom, of één los veld uit [fields]. */
    private fun matchClause(field: String?): MatchClause = when {
        field.isNullOrBlank() || field.equals("all", ignoreCase = true) -> MatchClause("search_vector", emptyList())
        field.equals("title", ignoreCase = true) -> MatchClause("to_tsvector('dutch', title)", emptyList())
        field.equals("description", ignoreCase = true) -> MatchClause("to_tsvector('dutch', description)", emptyList())
        else -> MatchClause("to_tsvector('dutch', coalesce(fields ->> ?, ''))", listOf(field))
    }

    private data class MatchClause(val expr: String, val exprArgs: List<Any>)

    private fun buildWhere(query: String?, collection: String?, field: String?): Pair<String, List<Any>> {
        val clauses = mutableListOf<String>()
        val args = mutableListOf<Any>()
        if (!query.isNullOrBlank()) {
            val match = matchClause(field)
            clauses += "${match.expr} @@ websearch_to_tsquery('dutch', ?)"
            args.addAll(match.exprArgs)
            args += query
        }
        if (!collection.isNullOrBlank()) {
            clauses += "collection = ?"
            args += collection
        }
        val where = if (clauses.isEmpty()) "" else "WHERE " + clauses.joinToString(" AND ")
        return where to args
    }

    private fun buildSearchText(title: String, description: String, ident: String, fields: Map<String, String>): String =
        buildString {
            append(title).append(' ')
            append(description).append(' ')
            append(ident).append(' ')
            fields.values.forEach { append(it).append(' ') }
        }.trim()

    private val rowMapper = RowMapper { rs: ResultSet, _: Int ->
        CollectionItem(
            id = rs.getLong("id"),
            collection = rs.getString("collection"),
            ident = rs.getString("ident"),
            title = rs.getString("title"),
            description = rs.getString("description"),
            year = (rs.getObject("year") as Number?)?.toInt(),
            imageUrl = rs.getString("image_url"),
            pdfUrl = rs.getString("pdf_url"),
            detailUrl = rs.getString("detail_url"),
            fields = parseFields(rs.getString("fields")),
            isComplete = rs.getBoolean("is_complete"),
            scrapedAt = rs.getTimestamp("scraped_at").toInstant(),
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseFields(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return objectMapper.readValue(json, Map::class.java) as Map<String, String>
    }
}
