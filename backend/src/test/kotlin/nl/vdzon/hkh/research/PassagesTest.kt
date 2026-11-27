package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class PassagesTest {
    @Test
    fun `a passage is the text around a hit, wherever it is in the document`() {
        val text = "a ".repeat(5_000) + "In 1973 heropende burgemeester Nielen paviljoen 3. " + "b ".repeat(5_000)
        val passages = Passages.around(text, listOf("Paviljoen"), max = 4)
        assertEquals(1, passages.size)
        assertTrue(passages.single().text.contains("In 1973 heropende burgemeester Nielen paviljoen 3."))
        assertTrue(passages.single().offset in 9_600..10_000)
        assertTrue(passages.single().text.length <= 2 * Passages.WINDOW_CHARS)
    }

    @Test
    fun `hits close together become one passage and many hits are spread over the document`() {
        val near = "x ".repeat(300) + "Bekker en nog eens Bekker en kapper Bekker. " + "y ".repeat(300)
        assertEquals(1, Passages.around(near, listOf("bekker"), max = 4).size)

        val spread = (1..20).joinToString(" ") { "Bekker in deel $it. " + "z ".repeat(600) }
        val passages = Passages.around(spread, listOf("bekker"), max = 4)
        assertEquals(4, passages.size)
        assertTrue(passages.first().text.contains("deel 1."))
        assertTrue(passages.last().offset > spread.length / 2, "ook het tweede deel van de tekst komt aan bod")
    }

    @Test
    fun `without a usable term or a hit there are no passages`() {
        assertTrue(Passages.around("Een tekst over de Zeelaan.", listOf("ab", "Bachstraat"), max = 4).isEmpty())
        assertTrue(Passages.around("", listOf("Zeelaan"), max = 4).isEmpty())
    }
}
