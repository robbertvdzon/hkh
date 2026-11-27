package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class DurationFitTest {
    private fun sample(step: String, chars: Int, seconds: Long, model: String = "anthropic/sonnet") = JobDurationSample(step, model, chars, seconds)

    @Test
    fun `without measurements each step has a starting value`() {
        assertEquals(45, DurationFit.estimate(emptyList(), "kort", "anthropic/sonnet", 30_000))
        assertEquals(170, DurationFit.estimate(emptyList(), "schrijven", "anthropic/sonnet", 300_000))
        assertEquals(90, DurationFit.estimate(emptyList(), "onbekend", null, 0))
    }

    @Test
    fun `with enough sized measurements the estimate grows with the input`() {
        // 20 seconden opstart plus 1 seconde per 2.000 tekens.
        val samples = (1..10).map { sample("schrijven", it * 40_000, 20L + it * 20) }
        assertEquals(70, DurationFit.estimate(samples, "schrijven", "anthropic/sonnet", 100_000))
        assertEquals(220, DurationFit.estimate(samples, "schrijven", "anthropic/sonnet", 400_000))
    }

    @Test
    fun `older measurements without input size give the median, first of the model and then of the step`() {
        val samples = listOf(40L, 50L, 300L).map { sample("richten", 0, it) } + listOf(10L, 12L, 14L).map { sample("richten", 0, it, model = "anthropic/haiku") }
        assertEquals(50, DurationFit.estimate(samples, "richten", "anthropic/sonnet", 80_000))
        assertEquals(12, DurationFit.estimate(samples, "richten", "anthropic/haiku", 80_000))
        assertEquals(27, DurationFit.estimate(samples, "richten", "anthropic/opus", 80_000), "een nieuw model begint op de mediaan van de stap")
    }

    @Test
    fun `a slope that points the wrong way is treated as noise`() {
        val samples = (1..10).map { sample("kort", it * 5_000, 100L - it * 5) }
        val small = DurationFit.estimate(samples, "kort", "anthropic/sonnet", 5_000)
        val large = DurationFit.estimate(samples, "kort", "anthropic/sonnet", 50_000)
        assertEquals(small, large)
    }

    @Test
    fun `the remaining time is told in words`() {
        assertEquals("nog ongeveer 3 minuten", DurationFit.remainingText(170))
        assertEquals("nog ongeveer een minuut", DurationFit.remainingText(60))
        assertEquals("nog ongeveer een halve minuut", DurationFit.remainingText(30))
        assertEquals("bijna klaar", DurationFit.remainingText(5))
        assertTrue(DurationFit.remainingText(-10).contains("langer dan verwacht"))
    }
}
