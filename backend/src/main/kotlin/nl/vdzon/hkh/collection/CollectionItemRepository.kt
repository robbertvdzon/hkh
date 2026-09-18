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
    fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int? = null, options: CollectionSearchOptions = CollectionSearchOptions()): List<CollectionItem>
    fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int? = null, options: CollectionSearchOptions = CollectionSearchOptions()): Long
    fun facet(query: String?, collection: String, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions, field: String, valueQuery: String): CollectionFacet = CollectionFacet(field, emptyList(), 0)
    fun searchCounts(query: String?, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions): List<CollectionCount> =
        counts().map { CollectionCount(it.collection, searchCount(query, it.collection, fieldQueries, year, options)) }
    fun documentTextAvailable(): Boolean = false
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

    override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?, options: CollectionSearchOptions): List<CollectionItem> {
        val (where, args) = buildWhere(query, collection, fieldQueries, year, options)
        val orderArgs = mutableListOf<Any>()
        val ordering = when (options.sort) {
            "title" -> "lower(title), collection, ident"
            "number" -> "collection, length(ident), ident"
            "newest" -> "$dateYear DESC NULLS LAST, collection, ident"
            "oldest" -> "$dateYear ASC NULLS LAST, collection, ident"
            "author" -> "lower(coalesce(fields ->> 'Auteur(s)', '')), collection, ident"
            "added" -> "added_at DESC NULLS LAST, collection, ident"
            else -> if (!query.isNullOrBlank() && options.mode == "web" && options.field == "all" && options.documentText) {
                orderArgs += query
                "ts_rank(search_vector, websearch_to_tsquery('dutch', ?)) DESC, year DESC NULLS LAST, collection, ident"
            } else "collection, $dateYear DESC NULLS LAST, ident"
        }
        return jdbc.query("SELECT * FROM collection_item $where ORDER BY $ordering LIMIT ? OFFSET ?",
            rowMapper, *(args + orderArgs + listOf(limit, offset)).toTypedArray())
    }

    override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions): Long {
        val (where, args) = buildWhere(query, collection, fieldQueries, year, options)
        return jdbc.queryForObject("SELECT COUNT(*) FROM collection_item $where", Long::class.java, *args.toTypedArray()) ?: 0
    }

    override fun searchCounts(query: String?, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions): List<CollectionCount> {
        val (where, args) = buildWhere(query, null, fieldQueries, year, options)
        return jdbc.query("SELECT collection, COUNT(*) AS n FROM collection_item $where GROUP BY collection ORDER BY collection",
            { rs, _ -> CollectionCount(rs.getString("collection"), rs.getLong("n")) }, *args.toTypedArray())
    }

    override fun documentTextAvailable(): Boolean = jdbc.queryForObject(
        "SELECT EXISTS (SELECT 1 FROM collection_item WHERE ($documentText) <> '')", Boolean::class.java,
    ) == true

    override fun facet(query: String?, collection: String, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions, field: String, valueQuery: String): CollectionFacet {
        // Exclude this facet's own selections so alternatives remain selectable (OR within one facet).
        val (where, args) = buildWhere(query, collection, fieldQueries, year, options.copy(filters = options.filters - field))
        val rows = jdbc.query(
            """SELECT value, COUNT(*) AS n, COUNT(*) OVER () AS total_values
               FROM (SELECT btrim(coalesce(fields ->> ?, '')) AS value FROM collection_item $where) candidates
               WHERE value <> '' AND value ILIKE ? ESCAPE '!'
               GROUP BY value ORDER BY lower(value), value LIMIT 100""",
            { rs, _ -> Triple(rs.getString("value"), rs.getLong("n"), rs.getLong("total_values")) },
            *(listOf(field) + args + listOf("%" + escapeLike(valueQuery) + "%")).toTypedArray(),
        )
        return CollectionFacet(field, rows.map { FacetValue(it.first, it.second) }, rows.firstOrNull()?.third ?: 0)
    }

    private data class Expression(val sql: String, val args: List<Any> = emptyList())

    private val documentKeys = CollectionCatalog.documentFields.joinToString(",") { "'${it.lowercase()}'" }
    private val documentText get() = "coalesce((SELECT string_agg(value, ' ') FROM jsonb_each_text(fields) WHERE lower(key) IN ($documentKeys)), '')"
    private val metadataText get() = "concat_ws(' ', title, description, ident, (SELECT string_agg(value, ' ') FROM jsonb_each_text(fields) WHERE lower(key) NOT IN ($documentKeys)))"
    // A bidprent's generic year can denote death/publication; never treat that as its birth year.
    private val dateYear = "CASE WHEN collection = 'bidprent' THEN substring(fields ->> 'Geboren op' from '(?:^|[^0-9])([12][0-9]{3})(?:[^0-9]|$)')::integer ELSE year END"

    private fun expression(field: String, includeDocument: Boolean): Expression = when (field.lowercase()) {
        "all" -> Expression(if (includeDocument) "search_text" else metadataText)
        "title" -> Expression("title")
        "description" -> Expression("description")
        "ident" -> Expression("ident")
        "title_description" -> Expression("concat_ws(' ', title, description)")
        "name_place" -> Expression("concat_ws(' ', fields ->> 'Achternaam overledene', fields ->> 'Geboren te')")
        else -> Expression("coalesce(fields ->> ?, '')", listOf(field))
    }

    private fun buildWhere(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions): Pair<String, List<Any>> {
        val clauses = mutableListOf<String>()
        val args = mutableListOf<Any>()
        fun match(field: String, value: String, mode: String) {
            if (value.isBlank()) return
            val expr = expression(field, options.documentText)
            if (mode == "web") {
                val vector = if (field == "all" && options.documentText) "search_vector" else "to_tsvector('dutch', ${expr.sql})"
                clauses += "$vector @@ websearch_to_tsquery('dutch', ?)"
                args.addAll(if (vector == "search_vector") emptyList() else expr.args)
                args += value
                return
            }
            val words = if (mode == "phrase") listOf(value.trim().removeSurrounding("\"")) else
                Regex("\"([^\"]+)\"|(\\S+)").findAll(value).map { it.groupValues[1].ifEmpty { it.groupValues[2] } }.toList()
            clauses += words.joinToString(if (mode == "or") " OR " else " AND ", "(", ")") { word ->
                args.addAll(expr.args)
                if (options.partial) {
                    args += "%" + escapeLike(word) + "%"
                    "${expr.sql} ILIKE ? ESCAPE '!'"
                } else {
                    // PostgreSQL word boundaries, without stemming or user-supplied regex syntax.
                    args += "\\m" + escapeRegex(word) + "\\M"
                    "${expr.sql} ~* ?"
                }
            }
        }
        if (!query.isNullOrBlank()) match(options.field, query, options.mode)
        fieldQueries.forEach { (field, value) -> match(field, value, if (options.mode == "web") "web" else "and") }
        if (!collection.isNullOrBlank()) { clauses += "collection = ?"; args += collection }
        if (year != null) { clauses += "year = ?"; args += year } // Legacy exact-year links retain their meaning.
        if (options.yearFrom != null) { clauses += "$dateYear >= ?"; args += options.yearFrom }
        if (options.yearTo != null) { clauses += "$dateYear <= ?"; args += options.yearTo }
        if (options.recentDays != null) { clauses += "added_at >= CURRENT_TIMESTAMP - (? * INTERVAL '1 day')"; args += options.recentDays }
        options.filters.forEach { (field, values) ->
            if (values.isNotEmpty()) {
                clauses += "btrim(coalesce(fields ->> ?, '')) IN (${values.joinToString(",") { "?" }})"
                args += field
                args.addAll(values)
            }
        }
        return (if (clauses.isEmpty()) "" else "WHERE " + clauses.joinToString(" AND ")) to args
    }

    private fun escapeLike(value: String) = value.replace("!", "!!").replace("%", "!%").replace("_", "!_")
    private fun escapeRegex(value: String) = buildString {
        value.forEach { ch ->
            if (ch in "\\.^$|?*+()[]{}") append('\\')
            append(ch)
        }
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
