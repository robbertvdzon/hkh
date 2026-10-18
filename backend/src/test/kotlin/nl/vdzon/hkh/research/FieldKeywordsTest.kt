package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class FieldKeywordsTest {
    private fun record(fields: Map<String, String>, year: Int? = null, description: String = "") = PendingCardRecord(
        collection = "beeldbank", ident = "1", title = "t", description = description, year = year, fields = fields,
        documentText = null, hasImage = true, sourceHash = "h",
    )

    @Test
    fun `metadata fields become typed keywords without a model`() {
        val keywords = FieldKeywords.fromRecord(record(mapOf(
            "Straatnaam" to "Kerklaan", "Wijk in Heemskerk" to "Centrum", "Thema" to "Straten dorp; Luchtfoto's; Luchtfoto's",
            "Fotograaf" to "Duin, Piet", "Auteur(s)" to "Diemeer Azn, Piet;Wijk, van, G.J.", "Uitgever" to "Historische Kring Heemskerk",
            "Datum opname" to "24-12-1949", "Beschrijving" to "mag niet als trefwoord",
        ), year = 1950))
        val byType = keywords.groupBy { it.type }.mapValues { (_, v) -> v.map { it.normalized }.toSet() }
        assertEquals(setOf("Kerklaan"), byType[KeywordType.STREET])
        assertEquals(setOf("Centrum", "Straten dorp", "Luchtfoto's"), byType[KeywordType.OTHER])
        assertEquals(setOf("Piet Duin", "Piet Diemeer Azn", "Wijk, van, G.J."), byType[KeywordType.PERSON])
        assertEquals(setOf("Historische Kring Heemskerk"), byType[KeywordType.ORGANISATION])
        assertEquals(setOf("1950", "1949"), byType[KeywordType.YEAR])
        assertTrue(keywords.all { it.source == KeywordSource.FIELD })
        assertTrue(keywords.none { it.literal.contains("trefwoord") })
    }

    @Test
    fun `years and periods in free text become ranges`() {
        val years = FieldKeywords.yearsFromText("Gebouwd ca. 1930, verbouwd in 1987 en gesloopt in de jaren negentig; jaren '50 onbekend.", KeywordSource.MODEL)
        val ranges = years.associate { it.literal to (it.yearFrom to it.yearTo) }
        assertEquals(1925 to 1935, ranges["ca. 1930"])
        assertEquals(1987 to 1987, ranges["1987"])
        assertEquals(1990 to 1999, ranges["jaren negentig"])
        assertEquals(1950 to 1959, ranges["jaren 50"])
        assertEquals("1925-1935", years.first { it.literal == "ca. 1930" }.normalized)
    }
}
