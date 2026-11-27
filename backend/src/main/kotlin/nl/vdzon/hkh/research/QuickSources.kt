package nl.vdzon.hkh.research

/**
 * De genummerde stukken zoals het korte antwoord ze te lezen krijgt. De best gerangschikte gaan
 * uitgebreid mee tot het budget op is: de kaart, en bij documenten de fragmenten rond de treffers
 * of de hele tekst; de rest alleen als kopregel, zodat het model ze nog kan aanwijzen voor een
 * artikel. Gebruikt door de korte stand (in de instructie) en door de zoekfunctie waarmee het
 * model zelf zoekt (als antwoord op zijn zoekactie).
 */
object QuickSources {
    const val WHOLE_TOTAL_CHARS = 25_000
    const val HEAD_CHARS = 2_500
    const val PASSAGES = 4
    const val PASSAGES_SUBJECT = 8
    const val MIN_BLOCK_CHARS = 1_200
    const val COMPACT_SUMMARY_CHARS = 300
    const val COMPACT_PASSAGES = 2
    const val COMPACT_WINDOW_CHARS = 220

    /**
     * De woorden uit een vraag of zoekdoel waarop fragmenten extra scoren: alles van vier letters of
     * meer dat geen vulwoord is en niet al een zoekterm is.
     */
    fun focusWords(text: String, terms: Collection<String>): List<String> {
        val covered = terms.joinToString(" ").lowercase()
        return Regex("[\\p{L}]{4,}").findAll(text.lowercase()).map { it.value }
            .filter { it !in FILLER && !covered.contains(it) }.distinct().take(12).toList()
    }

    /** Vraagt de tekst naar een moment (wanneer, sinds, welk jaar, hoe oud)? */
    fun asksWhen(text: String): Boolean = WHEN.containsMatchIn(text)

    /** Hoe goed een stuk bij de vraag past: het beste fragment van de tekst, of anders titel en samenvatting. */
    fun relevance(card: CandidateCard, document: ResearchDocument?, terms: List<TermReport>, focus: List<String>, wantsYear: Boolean): Int {
        val searchTerms = terms.flatMap { listOf(it.term) + it.variants }.distinct()
        val own = Passages.score(card.title + " " + card.summary, searchTerms, focus, wantsYear)
        val text = document?.documentText.orEmpty()
        if (text.isBlank()) return own
        val best = Passages.best(text, searchTerms, focus, wantsYear, 1, COMPACT_WINDOW_CHARS).firstOrNull()?.let { Passages.score(it.text, searchTerms, focus, wantsYear) } ?: 0
        return maxOf(own, best)
    }

    private val WHEN = Regex("""\b(wanneer|sinds|jaar|jaartal|bouwjaar|datum|hoe oud|hoelang|hoe lang|oudste|eerste|laatste)\b""", RegexOption.IGNORE_CASE)
    private val FILLER = setOf(
        "wanneer", "sinds", "welke", "welk", "waar", "waarom", "hoeveel", "over", "naar", "voor", "door", "zijn", "haar", "deze", "dit", "die", "dat",
        "heeft", "hebben", "werd", "werden", "wordt", "worden", "staat", "staan", "stond", "stonden", "heemskerk", "heemskerkse", "archief", "foto", "foto's",
        "fotos", "artikel", "artikelen", "stukken", "informatie", "geschiedenis", "jaar", "jaren", "jaartal", "ongeveer", "rond", "tijdens", "vanaf", "tussen",
        "zoals", "zoek", "zoeken", "vinden", "weten", "vertel", "vertellen", "meer", "veel", "alle", "alles", "iets", "niet", "geen", "ook", "nog", "maar",
    )

    /**
     * @param numbered de stukken met hun bronnummer, in rangorde
     * @param detailedCount hoeveel daarvan hoogstens uitgebreid meegaan
     * @param detailBudget tekens voor de uitgebreide stukken
     * @param totalBudget tekens voor alles samen, inclusief de koppen van de overige stukken
     */
    fun build(
        numbered: List<Pair<Int, CandidateCard>>, detailedCount: Int, texts: Map<ResearchRef, ResearchDocument>, terms: List<TermReport>,
        detailBudget: Int, totalBudget: Int,
        /** Woorden uit de vraag zelf, waarop fragmenten en stukken extra scoren; en of de vraag naar een moment vraagt. */
        focus: List<String> = emptyList(), wantsYear: Boolean = false,
        /**
         * Compact: per stuk een korte samenvatting en de twee best passende, kortere fragmenten, zonder
         * het begin of de hele tekst van onderwerpstukken. Er passen dan veel meer stukken in het budget;
         * bedoeld voor de zoekfunctie van het model, dat zo nodig nog een keer zoekt.
         */
        compact: Boolean = false,
    ): String = buildString {
        // Fragmenten zoeken op de termen en hun varianten, en ook op de losse woorden ervan: "Henk Nielen" vindt ook "burgemeester Nielen".
        val searchTerms = terms.flatMap { listOf(it.term) + it.variants }.flatMap { term -> listOf(term) + term.split(Regex("\\s+")).filter { it.length >= 4 } }.distinct()
        val lowerTerms = terms.map { it.term.trim().lowercase() }.filter { it.length >= 3 }
        var remaining = detailBudget
        var wholeLeft = if (compact) 0 else minOf(WHOLE_TOTAL_CHARS, remaining / 2)
        val summaryChars = if (compact) COMPACT_SUMMARY_CHARS else 800
        val keywordCount = if (compact) 8 else 15
        val brief = mutableListOf<String>()
        var blocks = 0
        numbered.forEachIndexed { index, (number, card) ->
            val document = texts[card.ref]
            val header = header(number, card, document)
            if (index >= detailedCount || remaining < MIN_BLOCK_CHARS) { brief += header; return@forEachIndexed }
            var wholeUsed = 0
            val block = buildString {
                appendLine(header)
                if (card.summary.isNotBlank()) appendLine("Samenvatting: ${card.summary.take(summaryChars)}")
                if (card.keywords.isNotEmpty()) appendLine("Trefwoorden: ${card.keywords.take(keywordCount).joinToString("; ")}")
                val text = document?.documentText.orEmpty()
                val titleHit = lowerTerms.any { card.title.lowercase().contains(it) }
                when {
                    text.isBlank() -> card.fragments.forEach { appendLine("Fragment: $it") }
                    text.length <= ResearchPipelineService.SHORT_DOCUMENT_CHARS -> appendLine("Volledige tekst: $text")
                    titleHit && text.length <= wholeLeft -> { appendLine("Volledige tekst: $text"); wholeUsed = text.length }
                    else -> {
                        // Een stuk over het onderwerp zelf dat te lang is om helemaal mee te gaan: het begin, en meer fragmenten.
                        if (titleHit && !compact) appendLine("Begin van de tekst: ${text.take(HEAD_CHARS).replace(Regex("\\s+"), " ")}…")
                        val passages = if (compact) Passages.best(text, searchTerms, focus, wantsYear, COMPACT_PASSAGES, COMPACT_WINDOW_CHARS)
                            else Passages.best(text, searchTerms, focus, wantsYear, if (titleHit) PASSAGES_SUBJECT else PASSAGES)
                        if (passages.isEmpty()) card.fragments.forEach { appendLine("Fragment: $it") }
                        else passages.forEach { appendLine("Fragment (vanaf teken ${it.offset} van ${text.length}): …${it.text}…") }
                    }
                }
            }.trimEnd()
            if (block.length > remaining) { brief += header; return@forEachIndexed }
            if (blocks++ > 0) appendLine()
            appendLine(block)
            remaining -= block.length
            wholeLeft -= wholeUsed
        }
        // De koppen van de overige stukken, zolang ze nog passen.
        val fitting = mutableListOf<String>()
        var used = length + 260
        for (header in brief) {
            if (used + header.length + 1 > totalBudget) break
            fitting += header
            used += header.length + 1
        }
        if (fitting.isNotEmpty()) {
            appendLine()
            appendLine("Ook gevonden, alleen de kop (${fitting.size}; je kent de inhoud niet, gebruik ze niet als bron, maar je mag ze opnemen in query.includeRecords als de titel bij de vraag past):")
            fitting.forEach(::appendLine)
        }
    }.trimEnd()

    /** Kopregel van een stuk: nummer, record, titel, soort en datum, en waarop het gevonden is. */
    fun header(number: Int, card: CandidateCard, document: ResearchDocument?): String {
        val fields = document?.fields.orEmpty()
        val kind = listOf("Type publicatie", "Medium", "Uitgever").firstNotNullOfOrNull { fields[it]?.takeIf(String::isNotBlank) }
        val date = fields["Datum"]?.takeIf { it.isNotBlank() } ?: card.year?.toString() ?: "ongedateerd"
        val flags = listOfNotNull(kind, date, if (card.hasImage) "foto" else null, if (card.hasText) "document" else null)
        return "[$number] ${card.ref.collection} ${card.ref.ident} \"${card.title}\" | ${flags.joinToString(" | ")}" +
            (card.matchedTerms.takeIf { it.isNotEmpty() }?.let { " | gevonden op: ${it.joinToString(", ")}" } ?: "")
    }
}
