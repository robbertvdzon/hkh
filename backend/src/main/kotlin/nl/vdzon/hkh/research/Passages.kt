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
