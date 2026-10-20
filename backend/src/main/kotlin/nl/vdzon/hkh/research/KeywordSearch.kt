package nl.vdzon.hkh.research

import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service

/** Eén zoekopdracht: termen met optionele periode, collecties, beeldfilter, jaarsortering en vaste records. */
data class ResearchQuery(
    val terms: List<String>,
    val yearFrom: Int? = null,
    val yearTo: Int? = null,
    val collections: List<String> = emptyList(),
    val withImage: Boolean? = null,
    val reason: String? = null,
    /** Sorteer de treffers op jaar (oudste of nieuwste eerst) in plaats van op score. */
    val sortByYear: YearSort? = null,
    /** Records die hoe dan ook vooraan meegaan, ook als geen term ze raakt. */
    val includeRecords: List<ResearchRef> = emptyList(),
) {
    val isEmpty: Boolean get() = terms.isEmpty() && includeRecords.isEmpty()
}

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
    /** Of het record een documenttekst heeft (artikel, transcriptie, archiefstuk). */
    val hasText: Boolean = false,
    /** Fragmenten uit de documenttekst rond een teksttreffer, met de treffer tussen « en ». */
    val fragments: List<String> = emptyList(),
)

/** Per zoekterm: welke trefwoordvarianten meededen en hoeveel records er in totaal bij horen. */
data class TermReport(val term: String, val variants: List<String>, val keywordHits: Long, val textHits: Long) {
    val total: Long get() = maxOf(keywordHits, textHits)
}

/** De gerangschikte kaarten tot het plafond, plus hoeveel records er in totaal geraakt zijn. */
data class SearchResult(val candidates: List<CandidateCard>, val terms: List<TermReport>, val totalFound: Int = candidates.size)

/**
 * Zoeken zonder model: trigram-tolerant op trefwoorden (Oostrum vindt ook Oostrom en Van
 * Oostrum), jaren als bereik, en de volledige tekst als vangnet voor wat de extractie miste, met
 * het fragment rond de treffer. Titeltreffers en records met documenttekst wegen zwaarder, zodat
 * een artikel niet onder de foto's zakt. Levert gerangschikte kaarten tot een plafond.
 */
@Service
open class KeywordSearchService(private val jdbc: JdbcTemplate) {

    open fun search(queries: List<ResearchQuery>, exclude: Set<ResearchRef>, limit: Int = DEFAULT_LIMIT): SearchResult {
        val hits = mutableMapOf<ResearchRef, Hit>()
        val reports = mutableListOf<TermReport>()
        val seenTerms = mutableSetOf<String>()
        for (query in queries) {
            val filter = Filter(query)
            for (raw in query.terms) {
                val term = raw.trim().replace(Regex("\\s+"), " ")
                if (term.length < 2 || !seenTerms.add(term.lowercase() + filter.key)) continue
                val year = term.toIntOrNull()?.takeIf { it in 1500..2100 }
                reports += if (year != null) searchYear(year, filter, term, hits) else searchTerm(term, filter, hits)
            }
        }
        val scored = hits.entries.filter { it.key !in exclude }
        val ranked = scored
            .map { (ref, hit) -> ref to hit.total() }
            .sortedWith(compareByDescending<Pair<ResearchRef, Double>> { it.second }.thenBy { it.first.toString() })
            .take(limit)
        val cards = loadCards(ranked.map { it.first })
        var candidates = ranked.mapNotNull { (ref, score) ->
            val hit = hits.getValue(ref)
            cards[ref]?.copy(matchedTerms = hit.perTerm.keys, score = Math.round(score * 100) / 100.0, fragments = hit.fragments.take(MAX_FRAGMENTS))
        }
        val sort = queries.firstNotNullOfOrNull { it.sortByYear }
        if (sort != null) {
            candidates = candidates.sortedWith(
                compareBy<CandidateCard> { it.year == null }
                    .thenBy { if (sort == YearSort.ASC) (it.year ?: 0) else -(it.year ?: 0) }
                    .thenByDescending { it.score },
            )
        }
        return SearchResult(candidates, reports, scored.size)
    }

    /**
     * De definitieve selectie voor de schrijver: de vaste records vooraan, daarna de treffers van
     * de termen in rangorde (of op jaar). Zonder termen alleen de vaste records.
     */
    open fun select(query: ResearchQuery, limit: Int = DEFAULT_LIMIT): SearchResult {
        val included = cards(query.includeRecords.distinct())
        val found = if (query.terms.isEmpty()) SearchResult(emptyList(), emptyList(), 0) else search(listOf(query), exclude = included.map { it.ref }.toSet(), limit = limit)
        return SearchResult(included + found.candidates, found.terms, included.size + found.totalFound)
    }

    /** Kaarten voor opgegeven records (bijvoorbeeld de bronnen van een eerder antwoord). */
    open fun cards(refs: List<ResearchRef>): List<CandidateCard> {
        val loaded = loadCards(refs)
        return refs.mapNotNull { loaded[it] }
    }

    private fun searchTerm(term: String, filter: Filter, hits: MutableMap<ResearchRef, Hit>): TermReport {
        val titlePattern = "%" + escapeLike(term) + "%"
        val variants = jdbc.query(
            """
            SELECT k.id, k.normalized, GREATEST(word_similarity(?, k.normalized), word_similarity(k.normalized, ?)) AS s
            FROM keyword k
            WHERE ? <% k.normalized OR k.normalized <% ? OR k.normalized ILIKE ? ESCAPE '!'
            ORDER BY s DESC, length(k.normalized), k.normalized
            LIMIT ?
            """.trimIndent(),
            { rs, _ -> Variant(rs.getLong("id"), rs.getString("normalized"), rs.getDouble("s")) },
            term, term, term, term, titlePattern, MAX_VARIANTS,
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
                SELECT m.collection, m.ident, MAX(CASE m.keyword_id $similarity ELSE 0 END) AS s,
                       bool_or(i.title ILIKE ? ESCAPE '!') AS t, bool_or(coalesce(length(i.document_text), 0) > 0) AS d
                $base
                GROUP BY m.collection, m.ident
                ORDER BY s DESC, m.collection, m.ident
                LIMIT $MAX_PER_TERM
                """.trimIndent(),
                { rs, _ -> record(hits, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, rs.getDouble("s"), rs.getBoolean("t"), rs.getBoolean("d"), null) },
                *(listOf<Any>(titlePattern) + filter.args).toTypedArray(),
            )
        }
        // Vangnet: volledige tekst (titel, beschrijving, velden en documenttekst), met het fragment rond de treffer.
        val textBase = "FROM collection_item i, websearch_to_tsquery('dutch', ?) q WHERE i.search_vector @@ q ${filter.sql}"
        val textArgs = listOf<Any>(term) + filter.args
        val textHits = jdbc.queryForObject("SELECT COUNT(*) $textBase", Long::class.java, *textArgs.toTypedArray()) ?: 0
        jdbc.query(
            """
            SELECT s.collection, s.ident, s.r, s.t, s.d,
                   CASE WHEN s.d THEN ts_headline('dutch', left(s.document_text, $HEADLINE_CHARS), q, '$HEADLINE_OPTIONS') END AS frag
            FROM (
                SELECT i.collection, i.ident, i.document_text, ts_rank(i.search_vector, q) AS r,
                       (i.title ILIKE ? ESCAPE '!') AS t, (coalesce(length(i.document_text), 0) > 0) AS d
                $textBase
                ORDER BY r DESC, i.collection, i.ident
                LIMIT $MAX_TEXT_PER_TERM
            ) s, websearch_to_tsquery('dutch', ?) q
            """.trimIndent(),
            { rs, _ ->
                val fragment = rs.getString("frag")?.takeIf { it.contains('«') }?.replace(Regex("\\s+"), " ")?.trim()
                record(hits, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, TEXT_SCORE + minOf(rs.getDouble("r"), 0.2), rs.getBoolean("t"), rs.getBoolean("d"), fragment)
            },
            *(listOf<Any>(titlePattern) + textArgs + listOf<Any>(term)).toTypedArray(),
        )
        return TermReport(term, variants.map { it.normalized }.distinct().take(12), keywordHits, textHits)
    }

    /** Een los jaartal als term: records uit die periode (±2 jaar) via jaarveld of jaartrefwoord. */
    private fun searchYear(year: Int, filter: Filter, term: String, hits: MutableMap<ResearchRef, Hit>): TermReport {
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
        val count = jdbc.queryForObject("SELECT COUNT(*) $base", Long::class.java, *args.toTypedArray()) ?: 0
        jdbc.query(
            "SELECT i.collection, i.ident, (coalesce(length(i.document_text), 0) > 0) AS d $base ORDER BY abs(coalesce(i.year, ?) - ?), i.collection, i.ident LIMIT $MAX_PER_TERM",
            { rs, _ -> record(hits, ResearchRef(rs.getString("collection"), rs.getString("ident")), term, YEAR_SCORE, false, rs.getBoolean("d"), null) },
            *(args + listOf<Any>(year, year)).toTypedArray(),
        )
        return TermReport(term, listOf("$from-$to"), count, 0)
    }

    private fun record(hits: MutableMap<ResearchRef, Hit>, ref: ResearchRef, term: String, score: Double, titleHit: Boolean, hasText: Boolean, fragment: String?) {
        val hit = hits.getOrPut(ref) { Hit() }
        hit.perTerm.merge(term, score, ::maxOf)
        if (titleHit) hit.titleHit = true
        if (hasText) hit.hasText = true
        if (fragment != null && fragment !in hit.fragments) hit.fragments += fragment
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
            SELECT i.collection, i.ident, i.title, i.year, i.image_url, i.description, c.summary,
                   (coalesce(length(i.document_text), 0) > 0) AS has_text
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
                    matchedTerms = emptySet(), score = 0.0, hasText = rs.getBoolean("has_text"),
                )
            },
            *args,
        )
        return cards.associateBy { it.ref }
    }

    private class Variant(val id: Long, val normalized: String, val similarity: Double)

    /** Score per term plus de bonussen: meerdere termen, titeltreffer en documenttekst. */
    private class Hit {
        val perTerm = mutableMapOf<String, Double>()
        var titleHit = false
        var hasText = false
        val fragments = mutableListOf<String>()

        fun total(): Double = perTerm.values.sum() + 0.5 * (perTerm.size - 1) + (if (titleHit) TITLE_BONUS else 0.0) + (if (hasText) TEXT_BONUS else 0.0)
    }

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

    companion object {
        const val DEFAULT_LIMIT = 300
        const val MAX_VARIANTS = 25
        const val MAX_PER_TERM = 200
        const val MAX_TEXT_PER_TERM = 60
        const val MAX_KEYWORDS_PER_CARD = 25
        const val MAX_FRAGMENTS = 2
        const val TEXT_SCORE = 0.45
        const val YEAR_SCORE = 0.4
        const val TITLE_BONUS = 0.6
        const val TEXT_BONUS = 0.3
        const val HEADLINE_CHARS = 50_000
        const val HEADLINE_OPTIONS = "MaxFragments=2, MinWords=12, MaxWords=30, StartSel=«, StopSel=», FragmentDelimiter=…"
    }
}
