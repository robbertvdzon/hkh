package nl.vdzon.hkh.research

import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service

/** Eén zoekopdracht van het model: termen met optionele periode, collecties en beeldfilter. */
data class ResearchQuery(
    val terms: List<String>,
    val yearFrom: Int? = null,
    val yearTo: Int? = null,
    val collections: List<String> = emptyList(),
    val withImage: Boolean? = null,
    val reason: String? = null,
)

data class ResearchRef(val collection: String, val ident: String) {
    override fun toString() = "$collection/$ident"
}

/** Een kandidaat voor het model: de kaart van een record plus hoe hij gevonden is. */
data class CandidateCard(
    val ref: ResearchRef,
    val title: String,
    val year: Int?,
    val hasImage: Boolean,
    val summary: String,
    val keywords: List<String>,
    val matchedTerms: Set<String>,
    val score: Double,
)

/** Per zoekterm: welke trefwoordvarianten meededen en hoeveel records er in totaal bij horen. */
data class TermReport(val term: String, val variants: List<String>, val keywordHits: Long, val textHits: Long) {
    val total: Long get() = maxOf(keywordHits, textHits)
}

data class SearchResult(val candidates: List<CandidateCard>, val terms: List<TermReport>)

/**
 * Stap B van het onderzoek, zonder model: trigram-tolerant zoeken op trefwoorden (Oostrum vindt
 * ook Oostrom en Van Oostrum), jaren als bereik, en de bestaande volledige-tekstzoekmachine als
 * vangnet voor wat de extractie miste. Levert gerangschikte kaarten met een plafond per ronde.
 */
@Service
open class KeywordSearchService(private val jdbc: JdbcTemplate) {

    open fun search(queries: List<ResearchQuery>, exclude: Set<ResearchRef>, limit: Int = DEFAULT_LIMIT): SearchResult {
        val scores = mutableMapOf<ResearchRef, MutableMap<String, Double>>()
        val reports = mutableListOf<TermReport>()
        val seenTerms = mutableSetOf<String>()
        for (query in queries) {
            val filter = Filter(query)
            for (raw in query.terms) {
                val term = raw.trim().replace(Regex("\\s+"), " ")
                if (term.length < 2 || !seenTerms.add(term.lowercase() + filter.key)) continue
                val year = term.toIntOrNull()?.takeIf { it in 1500..2100 }
                val report = if (year != null) {
                    searchYear(year, filter, term, scores)
                } else {
                    searchTerm(term, filter, scores)
                }
                reports += report
            }
        }
        val ranked = scores.entries
            .filter { it.key !in exclude }
            .map { (ref, perTerm) -> ref to (perTerm.values.sum() + 0.5 * (perTerm.size - 1)) }
            .sortedWith(compareByDescending<Pair<ResearchRef, Double>> { it.second }.thenBy { it.first.toString() })
            .take(limit)
        val cards = loadCards(ranked.map { it.first })
        val candidates = ranked.mapNotNull { (ref, score) ->
            cards[ref]?.copy(matchedTerms = scores[ref]?.keys.orEmpty(), score = Math.round(score * 100) / 100.0)
        }
        return SearchResult(candidates, reports)
    }

    /** Kaarten voor opgegeven records (bijvoorbeeld de bronnen van een eerder antwoord). */
    open fun cards(refs: List<ResearchRef>): List<CandidateCard> {
        val loaded = loadCards(refs)
        return refs.mapNotNull { loaded[it] }
    }

    private fun searchTerm(term: String, filter: Filter, scores: MutableMap<ResearchRef, MutableMap<String, Double>>): TermReport {
        val variants = jdbc.query(
            """
            SELECT k.id, k.normalized, GREATEST(word_similarity(?, k.normalized), word_similarity(k.normalized, ?)) AS s
            FROM keyword k
            WHERE ? <% k.normalized OR k.normalized <% ? OR k.normalized ILIKE ? ESCAPE '!'
            ORDER BY s DESC, length(k.normalized), k.normalized
            LIMIT ?
            """.trimIndent(),
            { rs, _ -> Variant(rs.getLong("id"), rs.getString("normalized"), rs.getDouble("s")) },
            term, term, term, term, "%" + escapeLike(term) + "%", MAX_VARIANTS,
        )
        var keywordHits = 0L
        if (variants.isNotEmpty()) {
            val ids = variants.joinToString(",") { it.id.toString() }
            val similarity = variants.joinToString(" ") { "WHEN ${it.id} THEN ${it.similarity}" }
            val base = """
                FROM keyword_mention m
                JOIN collection_item i ON i.collection = m.collection AND i.ident = m.ident
                WHERE m.keyword_id IN ($ids) ${filter.sql}
            """.trimIndent()
            keywordHits = jdbc.queryForObject("SELECT COUNT(DISTINCT (m.collection, m.ident)) $base", Long::class.java, *filter.args.toTypedArray()) ?: 0
            jdbc.query(
                """
                SELECT m.collection, m.ident, MAX(CASE m.keyword_id $similarity ELSE 0 END) AS s
                $base
                GROUP BY m.collection, m.ident
                ORDER BY s DESC, m.collection, m.ident
                LIMIT $MAX_PER_TERM
                """.trimIndent(),
                { rs, _ -> record(scores, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, rs.getDouble("s")) },
                *filter.args.toTypedArray(),
            )
        }
        // Vangnet: volledige tekst (titel, beschrijving, velden en documenttekst).
        val textBase = "FROM collection_item i, websearch_to_tsquery('dutch', ?) q WHERE i.search_vector @@ q ${filter.sql}"
        val textArgs = listOf(term) + filter.args
        val textHits = jdbc.queryForObject("SELECT COUNT(*) $textBase", Long::class.java, *textArgs.toTypedArray()) ?: 0
        jdbc.query(
            "SELECT i.collection, i.ident, ts_rank(i.search_vector, q) AS r $textBase ORDER BY r DESC, i.collection, i.ident LIMIT $MAX_TEXT_PER_TERM",
            { rs, _ -> record(scores, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, TEXT_SCORE + minOf(rs.getDouble("r"), 0.2)) },
            *textArgs.toTypedArray(),
        )
        return TermReport(term, variants.map { it.normalized }.distinct().take(12), keywordHits, textHits)
    }

    /** Een los jaartal als term: records uit die periode (±2 jaar) via jaarveld of jaartrefwoord. */
    private fun searchYear(year: Int, filter: Filter, term: String, scores: MutableMap<ResearchRef, MutableMap<String, Double>>): TermReport {
        val from = year - 2
        val to = year + 2
        val base = """
            FROM collection_item i
            WHERE ((i.year BETWEEN ? AND ?) OR EXISTS (
                SELECT 1 FROM keyword_mention m WHERE m.collection = i.collection AND m.ident = i.ident
                  AND m.year_from IS NOT NULL AND m.year_from <= ? AND coalesce(m.year_to, m.year_from) >= ?
            )) ${filter.sql}
        """.trimIndent()
        val args = listOf<Any>(from, to, to, from) + filter.args
        val hits = jdbc.queryForObject("SELECT COUNT(*) $base", Long::class.java, *args.toTypedArray()) ?: 0
        jdbc.query(
            "SELECT i.collection, i.ident $base ORDER BY abs(coalesce(i.year, ?) - ?), i.collection, i.ident LIMIT $MAX_PER_TERM",
            { rs, _ -> record(scores, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, YEAR_SCORE) },
            *(args + listOf<Any>(year, year)).toTypedArray(),
        )
        return TermReport(term, listOf("$from-$to"), hits, 0)
    }

    private fun record(scores: MutableMap<ResearchRef, MutableMap<String, Double>>, ref: ResearchRef, term: String, score: Double) {
        val perTerm = scores.getOrPut(ref) { mutableMapOf() }
        perTerm.merge(term, score, ::maxOf)
    }

    private fun loadCards(refs: List<ResearchRef>): Map<ResearchRef, CandidateCard> {
        if (refs.isEmpty()) return emptyMap()
        val placeholders = refs.joinToString(",") { "(?, ?)" }
        val args = refs.flatMap { listOf(it.collection, it.ident) }.toTypedArray()
        val keywords = mutableMapOf<ResearchRef, MutableList<String>>()
        jdbc.query(
            """
            SELECT m.collection, m.ident, k.type, k.normalized
            FROM keyword_mention m JOIN keyword k ON k.id = m.keyword_id
            WHERE (m.collection, m.ident) IN ($placeholders)
            ORDER BY m.collection, m.ident, k.type, k.normalized
            """.trimIndent(),
            { rs, _ ->
                val list = keywords.getOrPut(ResearchRef(rs.getString("collection"), rs.getString("ident"))) { mutableListOf() }
                if (list.size < MAX_KEYWORDS_PER_CARD) list += "${rs.getString("type").lowercase()}: ${rs.getString("normalized")}"
            },
            *args,
        )
        val cards = jdbc.query(
            """
            SELECT i.collection, i.ident, i.title, i.year, i.image_url, i.description, c.summary
            FROM collection_item i LEFT JOIN document_card c ON c.collection = i.collection AND c.ident = i.ident AND c.error IS NULL
            WHERE (i.collection, i.ident) IN ($placeholders)
            """.trimIndent(),
            { rs, _ ->
                val ref = ResearchRef(rs.getString("collection"), rs.getString("ident"))
                val summary = rs.getString("summary")?.takeIf { it.isNotBlank() }
                    ?: rs.getString("description").orEmpty().take(600)
                CandidateCard(
                    ref = ref, title = rs.getString("title").orEmpty(), year = (rs.getObject("year") as Number?)?.toInt(),
                    hasImage = rs.getString("image_url") != null, summary = summary, keywords = keywords[ref].orEmpty(),
                    matchedTerms = emptySet(), score = 0.0,
                )
            },
            *args,
        )
        return cards.associateBy { it.ref }
    }

    private class Variant(val id: Long, val normalized: String, val similarity: Double)

    /** Filters uit de zoekopdracht als SQL op alias i. */
    private class Filter(query: ResearchQuery) {
        val sql: String
        val args: List<Any>
        val key: String

        init {
            val clauses = mutableListOf<String>()
            val values = mutableListOf<Any>()
            val collections = query.collections.map { it.trim().lowercase() }.filter { it.matches(Regex("[a-z]+")) }
            if (collections.isNotEmpty()) {
                clauses += "i.collection IN (${collections.joinToString(",") { "?" }})"
                values.addAll(collections)
            }
            val from = query.yearFrom?.takeIf { it in 1000..2100 }
            val to = query.yearTo?.takeIf { it in 1000..2100 }
            if (from != null || to != null) {
                clauses += "(i.year IS NULL OR (i.year >= ? AND i.year <= ?))"
                values += (from ?: 1000)
                values += (to ?: 2100)
            }
            if (query.withImage == true) clauses += "i.image_url IS NOT NULL"
            sql = clauses.joinToString("") { " AND $it" }
            args = values
            key = "|$sql|$values"
        }
    }

    private fun escapeLike(value: String) = value.replace("!", "!!").replace("%", "!%").replace("_", "!_")

    private companion object {
        const val DEFAULT_LIMIT = 40
        const val MAX_VARIANTS = 25
        const val MAX_PER_TERM = 200
        const val MAX_TEXT_PER_TERM = 60
        const val MAX_KEYWORDS_PER_CARD = 25
        const val TEXT_SCORE = 0.45
        const val YEAR_SCORE = 0.4
    }
}
