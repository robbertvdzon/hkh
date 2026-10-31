package nl.vdzon.hkh.workflowlog

import java.util.concurrent.atomic.AtomicLong
import java.util.function.LongSupplier
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class IngestRateLimiterTest {
    private val clock = AtomicLong(0)
    private val limiter = IngestRateLimiter(LongSupplier { clock.get() })
    private val minute = 60_000_000_000L

    @Test
    fun `an emmer is leeg na de capaciteit en loopt daarna per minuut vol`() {
        repeat(3) { assertTrue(limiter.tryAcquire("a", 3, 3.0)) }
        assertFalse(limiter.tryAcquire("a", 3, 3.0))
        clock.addAndGet(minute / 3)
        assertTrue(limiter.tryAcquire("a", 3, 3.0))
        assertFalse(limiter.tryAcquire("a", 3, 3.0))
        clock.addAndGet(10 * minute)
        repeat(3) { assertTrue(limiter.tryAcquire("a", 3, 3.0)) }
        assertFalse(limiter.tryAcquire("a", 3, 3.0))
    }

    @Test
    fun `sleutels beperken elkaar niet`() {
        assertTrue(limiter.tryAcquire("a", 1, 1.0))
        assertFalse(limiter.tryAcquire("a", 1, 1.0))
        assertTrue(limiter.tryAcquire("b", 1, 1.0))
    }
}

class RateKeyTest {
    private fun request(forwarded: String?) = org.springframework.mock.web.MockHttpServletRequest().apply {
        remoteAddr = "10.1.1.1"
        forwarded?.let { addHeader("X-Forwarded-For", it) }
    }

    @Test
    fun `de sleutel is het adres dat onze eigen router toevoegde, wat links staat is verzonnen`() {
        val key = nl.vdzon.hkh.workflowlog.api.WorkflowLogIngestController.Companion::rateKey
        // client -> router -> nginx -> backend: de nginx voegt het routeradres toe.
        assertTrue(key(request("6.6.6.6, 203.0.113.9, 10.0.0.1"), 1) == "203.0.113.9")
        assertTrue(key(request("203.0.113.9, 10.0.0.1"), 1) == "203.0.113.9")
        // Rechtstreeks naar de backend: het laatste adres is van de router.
        assertTrue(key(request("6.6.6.6, 203.0.113.9"), 0) == "203.0.113.9")
        // Zonder kop, of een kop die korter is dan verwacht, geldt het adres van de verbinding.
        assertTrue(key(request(null), 1) == "10.1.1.1")
        assertTrue(key(request("203.0.113.9"), 1) == "10.1.1.1")
    }
}
