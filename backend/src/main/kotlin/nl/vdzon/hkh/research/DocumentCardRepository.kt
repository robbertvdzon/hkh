package nl.vdzon.hkh.research

import java.sql.ResultSet
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import tools.jackson.databind.ObjectMapper

interface DocumentCardStore {
    /** Records zonder kaart, met een verouderde extractieversie of gewijzigde invoer; met [includeFailed] ook eerder mislukte. */
    fun pending(collection: String, version: String, includeFailed: Boolean, limit: Int): List<PendingCardRecord>
    fun pendingCount(version: String, includeFailed: Boolean): Long
    fun save(card: DocumentCard)
    fun saveError(collection: String, ident: String, version: String, model: String?, sourceHash: String, error: String)
    fun find(collection: String, ident: String): DocumentCard?
    fun stats(version: String): CardStats
}

@Repository
class DocumentCardRepository(
    private val jdbc: JdbcTemplate,
    private val objectMapper: ObjectMapper,
) : DocumentCardStore {

    /** De invoerhash in SQL, zodat de pending-query en het opslaan dezelfde definitie delen. */
    private val sourceHashSql = "md5(i.search_text || ' ' || coalesce(i.document_text, ''))"

    override fun pending(collection: String, version: String, includeFailed: Boolean, limit: Int): List<PendingCardRecord> =
        jdbc.query(
            """
            SELECT i.collection, i.ident, i.title, i.description, i.year, i.fields, i.document_text, i.image_url,
                   $sourceHashSql AS source_hash
            FROM collection_item i
            LEFT JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident
            WHERE i.collection = ?
              AND (c.collection IS NULL OR c.extraction_version <> ? OR c.source_hash <> $sourceHashSql OR (? AND c.error IS NOT NULL))
              AND (? OR c.error IS NULL OR c.extraction_version <> ? OR c.source_hash <> $sourceHashSql)
            ORDER BY length(i.ident), i.ident
            LIMIT ?
            """.trimIndent(),
            { rs, _ ->
                PendingCardRecord(
                    collection = rs.getString("collection"),
                    ident = rs.getString("ident"),
                    title = rs.getString("title"),
                    description = rs.getString("description"),
                    year = (rs.getObject("year") as Number?)?.toInt(),
                    fields = parseFields(rs.getString("fields")),
                    documentText = rs.getString("document_text"),
                    hasImage = rs.getString("image_url") != null,
                    sourceHash = rs.getString("source_hash"),
                )
            },
            collection, version, includeFailed, includeFailed, version, limit,
        )

    override fun pendingCount(version: String, includeFailed: Boolean): Long = jdbc.queryForObject(
        """
        SELECT COUNT(*) FROM collection_item i
        LEFT JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident
        WHERE (c.collection IS NULL OR c.extraction_version <> ? OR c.source_hash <> $sourceHashSql OR (? AND c.error IS NOT NULL))
          AND (? OR c.error IS NULL OR c.extraction_version <> ? OR c.source_hash <> $sourceHashSql)
        """.trimIndent(),
        Long::class.java, version, includeFailed, includeFailed, version,
    ) ?: 0

    @Transactional
    override fun save(card: DocumentCard) {
        jdbc.update(
            """
            INSERT INTO document_card (collection, ident, summary, has_image, extraction_version, model, source_hash, error, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, NULL, CURRENT_TIMESTAMP)
            ON CONFLICT (collection, ident) DO UPDATE SET
                summary = EXCLUDED.summary, has_image = EXCLUDED.has_image, extraction_version = EXCLUDED.extraction_version,
                model = EXCLUDED.model, source_hash = EXCLUDED.source_hash, error = NULL, created_at = CURRENT_TIMESTAMP
            """.trimIndent(),
            card.collection, card.ident, card.summary, card.hasImage, card.extractionVersion, card.model, card.sourceHash,
        )
        jdbc.update("DELETE FROM keyword_mention WHERE collection = ? AND ident = ?", card.collection, card.ident)
        val unique = card.keywords
            .filter { it.normalized.isNotBlank() }
            .groupBy { it.type to it.normalized.trim() }
            .map { (_, group) -> group.first() }
        for (keyword in unique) {
            val id = jdbc.queryForObject(
                """
                INSERT INTO keyword (normalized, type) VALUES (?, ?)
                ON CONFLICT (normalized, type) DO UPDATE SET normalized = EXCLUDED.normalized
                RETURNING id
                """.trimIndent(),
                Long::class.java, keyword.normalized.trim(), keyword.type.name,
            )!!
            jdbc.update(
                """
                INSERT INTO keyword_mention (keyword_id, collection, ident, literal, year_from, year_to, source)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (keyword_id, collection, ident) DO NOTHING
                """.trimIndent(),
                id, card.collection, card.ident, keyword.literal.trim().ifBlank { keyword.normalized.trim() },
                keyword.yearFrom, keyword.yearTo, keyword.source.name,
            )
        }
    }

    override fun saveError(collection: String, ident: String, version: String, model: String?, sourceHash: String, error: String) {
        jdbc.update(
            """
            INSERT INTO document_card (collection, ident, summary, has_image, extraction_version, model, source_hash, error, created_at)
            VALUES (?, ?, '', false, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT (collection, ident) DO UPDATE SET
                extraction_version = EXCLUDED.extraction_version, model = EXCLUDED.model, source_hash = EXCLUDED.source_hash,
                error = EXCLUDED.error, created_at = CURRENT_TIMESTAMP
            """.trimIndent(),
            collection, ident, version, model, sourceHash, error.take(500),
        )
    }

    override fun find(collection: String, ident: String): DocumentCard? {
        val card = jdbc.query(
            "SELECT * FROM document_card WHERE collection = ? AND ident = ?",
            { rs: ResultSet, _: Int ->
                DocumentCard(
                    collection = rs.getString("collection"), ident = rs.getString("ident"), summary = rs.getString("summary"),
                    hasImage = rs.getBoolean("has_image"), keywords = emptyList(), extractionVersion = rs.getString("extraction_version"),
                    model = rs.getString("model"), sourceHash = rs.getString("source_hash"), error = rs.getString("error"),
                    createdAt = rs.getTimestamp("created_at")?.toInstant(),
                )
            },
            collection, ident,
        ).singleOrNull() ?: return null
        val keywords = jdbc.query(
            """
            SELECT k.normalized, k.type, m.literal, m.year_from, m.year_to, m.source
            FROM keyword_mention m JOIN keyword k ON k.id = m.keyword_id
            WHERE m.collection = ? AND m.ident = ? ORDER BY k.type, k.normalized
            """.trimIndent(),
            { rs, _ ->
                CardKeyword(
                    type = KeywordType.parse(rs.getString("type")), literal = rs.getString("literal"), normalized = rs.getString("normalized"),
                    yearFrom = (rs.getObject("year_from") as Number?)?.toInt(), yearTo = (rs.getObject("year_to") as Number?)?.toInt(),
                    source = runCatching { KeywordSource.valueOf(rs.getString("source")) }.getOrDefault(KeywordSource.MODEL),
                )
            },
            collection, ident,
        )
        return card.copy(keywords = keywords)
    }

    override fun stats(version: String): CardStats = CardStats(
        cards = jdbc.queryForObject("SELECT COUNT(*) FROM document_card WHERE error IS NULL AND extraction_version = ?", Long::class.java, version) ?: 0,
        failed = jdbc.queryForObject("SELECT COUNT(*) FROM document_card WHERE error IS NOT NULL", Long::class.java) ?: 0,
        pending = pendingCount(version, includeFailed = false),
        keywords = jdbc.queryForObject("SELECT COUNT(*) FROM keyword", Long::class.java) ?: 0,
    )

    @Suppress("UNCHECKED_CAST")
    private fun parseFields(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return objectMapper.readValue(json, Map::class.java) as Map<String, String>
    }
}
