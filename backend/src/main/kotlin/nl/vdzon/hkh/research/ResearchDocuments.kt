package nl.vdzon.hkh.research

import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Repository
import tools.jackson.databind.ObjectMapper

/** Een volledig record zoals de schrijver het krijgt: metadata, kaart en documenttekst. */
data class ResearchDocument(
    val ref: ResearchRef,
    val title: String,
    val year: Int?,
    val description: String,
    val fields: Map<String, String>,
    val documentText: String?,
    val hasImage: Boolean,
    val summary: String?,
)

interface ResearchDocumentStore {
    fun load(refs: List<ResearchRef>): List<ResearchDocument>
}

@Repository
class ResearchDocumentRepository(private val jdbc: JdbcTemplate, private val objectMapper: ObjectMapper) : ResearchDocumentStore {
    override fun load(refs: List<ResearchRef>): List<ResearchDocument> {
        if (refs.isEmpty()) return emptyList()
        val placeholders = refs.joinToString(",") { "(?, ?)" }
        val byRef = jdbc.query(
            """
            SELECT i.collection, i.ident, i.title, i.year, i.description, i.fields, i.document_text, i.image_url, c.summary
            FROM collection_item i LEFT JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident AND c.error IS NULL
            WHERE (i.collection, i.ident) IN ($placeholders)
            """.trimIndent(),
            { rs, _ ->
                ResearchDocument(
                    ref = ResearchRef(rs.getString("collection"), rs.getString("ident")),
                    title = rs.getString("title").orEmpty(),
                    year = (rs.getObject("year") as Number?)?.toInt(),
                    description = rs.getString("description").orEmpty(),
                    fields = parseFields(rs.getString("fields")),
                    documentText = rs.getString("document_text"),
                    hasImage = rs.getString("image_url") != null,
                    summary = rs.getString("summary"),
                )
            },
            *refs.flatMap { listOf(it.collection, it.ident) }.toTypedArray(),
        ).associateBy { it.ref }
        return refs.mapNotNull { byRef[it] }
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseFields(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return runCatching { objectMapper.readValue(json, Map::class.java) as Map<String, String> }.getOrDefault(emptyMap())
    }
}
