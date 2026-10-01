package nl.vdzon.hkh.aisearch

import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class AiResearchDepthTest {
    @Test
    fun `parses api values case-insensitively and falls back to fast`() {
        assertEquals(AiResearchDepth.THOROUGH, AiResearchDepth.parse("thorough"))
        assertEquals(AiResearchDepth.EXTENDED, AiResearchDepth.parse(" EXTENDED "))
        assertEquals(AiResearchDepth.FAST, AiResearchDepth.parse(null))
        assertEquals(AiResearchDepth.FAST, AiResearchDepth.parse("diep"))
    }

    @Test
    fun `deeper research allows more rounds and more time`() {
        val depths = AiResearchDepth.entries
        assertEquals(listOf(1, 5, 15), depths.map { it.maxRounds })
        assertEquals(listOf(1, 3, 6), depths.map { it.minRounds })
        assertTrue(depths.all { it.minRounds <= it.maxRounds })
        assertTrue(depths.zipWithNext().all { (a, b) -> a.executionTimeoutSeconds < b.executionTimeoutSeconds })
    }

    @Test
    fun `a trail line from the agent becomes a progress message`() {
        assertEquals("Spoor wordt gevolgd: Slot Assumburg", RuntimeActivityClassifier.classify("Spoor: Slot Assumburg"))
        assertEquals(
            "Spoor wordt gevolgd: Piet Duin, Kerkweg",
            RuntimeActivityClassifier.classify("Ronde 2 begint.\n**Spoor: Piet Duin, Kerkweg**\ncurl https://hkh.vdzonsoftware.nl/api/collections/search?q=Duin"),
        )
        assertEquals("Een nieuwe zoekpagina uit de collectie wordt opgehaald", RuntimeActivityClassifier.classify("curl .../api/collections/search?q=x"))
        assertNull(RuntimeActivityClassifier.classify("Spoor:   "))
    }
}
