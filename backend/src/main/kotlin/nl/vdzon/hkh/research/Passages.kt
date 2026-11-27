package nl.vdzon.hkh.research

/** Een stuk documenttekst rond een treffer, met de plek in de tekst. */
data class Passage(val offset: Int, val text: String)

/**
 * Fragmenten uit de documenttekst rond de zoektermen, zonder model: per treffer een venster,
 * overlappende vensters samengevoegd, gelijk verspreid over de tekst als er meer treffers zijn dan
 * er fragmenten mogen meegaan. Zo krijgt het model ook de tekst rond een treffer diep in een lang
 * stuk te zien, voorbij wat de kaart heeft gelezen.
 */
object Passages {
    const val WINDOW_CHARS = 350

    fun around(text: String, terms: Collection<String>, max: Int, window: Int = WINDOW_CHARS): List<Passage> {
        if (text.isBlank() || max <= 0) return emptyList()
        val lower = text.lowercase()
        val positions = sortedSetOf<Int>()
        for (term in terms.map { it.trim().lowercase() }.filter { it.length >= 3 }.distinct()) {
            var index = lower.indexOf(term)
            while (index >= 0 && positions.size < MAX_POSITIONS) {
                positions += index
                index = lower.indexOf(term, index + term.length)
            }
        }
        if (positions.isEmpty()) return emptyList()
        // Vensters rond de treffers, overlappende samengevoegd.
        val ranges = mutableListOf<IntRange>()
        for (position in positions) {
            val from = maxOf(0, position - window)
            val to = minOf(text.length, position + window)
            val last = ranges.lastOrNull()
            if (last != null && from <= last.last) ranges[ranges.size - 1] = last.first..maxOf(last.last, to) else ranges += from..to
        }
        val chosen = if (ranges.size <= max) ranges else List(max) { ranges[it * ranges.size / max] }
        return chosen.map { range -> Passage(range.first, clean(text, range)) }
    }

    /**
     * De fragmenten die het best bij de vraag passen, in plaats van gelijk verspreid: een venster rond
     * een treffer scoort op het aantal verschillende zoektermen erin, op de woorden uit de vraag zelf
     * ([focus], bijvoorbeeld "gebouwd") en, als de vraag naar een moment vraagt ([wantsYear]), op een
     * jaartal. Zo wint "werd in 1891 gebouwd" van een passage die alleen de naam noemt. Bij gelijke
     * score blijven de fragmenten verspreid over de tekst.
     */
    fun best(text: String, terms: Collection<String>, focus: Collection<String>, wantsYear: Boolean, max: Int, window: Int = WINDOW_CHARS): List<Passage> {
        val candidates = around(text, terms, MAX_CANDIDATES, window)
        if (candidates.size <= 1 || max <= 0) return candidates.take(max.coerceAtLeast(0))
        val scored = candidates.map { it to score(it.text, terms, focus, wantsYear) }
        val chosen = mutableListOf<Passage>()
        for (level in scored.map { it.second }.distinct().sortedDescending()) {
            val group = scored.filter { it.second == level }.map { it.first }
            val room = max - chosen.size
            if (room <= 0) break
            chosen += if (group.size <= room) group else List(room) { group[it * group.size / room] }
        }
        return chosen.sortedBy { it.offset }
    }

    /** Hoe goed een stuk tekst bij de vraag past; ook bruikbaar voor een titel of samenvatting. */
    fun score(text: String, terms: Collection<String>, focus: Collection<String>, wantsYear: Boolean): Int {
        val lower = text.lowercase()
        val termHits = terms.map { it.trim().lowercase() }.filter { it.length >= 3 }.distinct().count { lower.contains(it) }
        val focusHits = focus.map(::stem).filter { it.length >= 4 }.distinct().count { lower.contains(it) }
        return termHits * 3 + focusHits * 2 + (if (wantsYear && YEAR.containsMatchIn(text)) 2 else 0)
    }

    /** Ruwe stam van een woord, zodat "gebouwd" ook "gebouw" raakt: de eerste vijf letters van langere woorden. */
    private fun stem(word: String): String = word.trim().lowercase().let { if (it.length > 5) it.take(5) else it }

    private val YEAR = Regex("""\b1[0-9]{3}\b|\b20[0-2][0-9]\b""")
    private const val MAX_CANDIDATES = 60

    /** Het venster op woordgrenzen afgesneden en witruimte samengevoegd. */
    private fun clean(text: String, range: IntRange): String {
        var from = range.first
        var to = range.last
        if (from > 0) text.indexOf(' ', from).takeIf { it in from until from + 40 }?.let { from = it + 1 }
        if (to < text.length) text.lastIndexOf(' ', to).takeIf { it > to - 40 && it > from }?.let { to = it }
        return text.substring(from, minOf(to, text.length)).replace(Regex("\\s+"), " ").trim()
    }

    private const val MAX_POSITIONS = 400
}
