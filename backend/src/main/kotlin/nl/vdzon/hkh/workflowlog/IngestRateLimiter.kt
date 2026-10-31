package nl.vdzon.hkh.workflowlog

import java.util.concurrent.ConcurrentHashMap
import java.util.function.LongSupplier
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Component

/** Een emmer die met [perMinute] tokens per minuut bijvult en nooit meer dan [capacity] bevat. */
private class Bucket(val capacity: Double, val perMinute: Double, var tokens: Double, var updatedNanos: Long)

/**
 * Begrenst het open meldpunt van het workflow-logboek (tegen misbruik en overbelasting). Alle tellers zitten
 * in het geheugen van dit ene proces; bij een herstart beginnen ze opnieuw. [nanos] is te vervangen in tests.
 */
@Component
class IngestRateLimiter internal constructor(private val nanos: LongSupplier) {
    @Autowired constructor() : this(LongSupplier { System.nanoTime() })

    private val buckets = ConcurrentHashMap<String, Bucket>()

    /** true als er nog ruimte is voor [key] (en dan telt dit verzoek mee). */
    fun tryAcquire(key: String, capacity: Int, perMinute: Double): Boolean {
        val now = nanos.asLong
        if (buckets.size > MAX_KEYS) purge(now)
        val bucket = buckets.computeIfAbsent(key) { Bucket(capacity.toDouble(), perMinute, capacity.toDouble(), now) }
        synchronized(bucket) {
            val elapsedMinutes = (now - bucket.updatedNanos) / 60_000_000_000.0
            bucket.tokens = minOf(bucket.capacity, bucket.tokens + elapsedMinutes * bucket.perMinute)
            bucket.updatedNanos = now
            if (bucket.tokens < 1.0) return false
            bucket.tokens -= 1.0
            return true
        }
    }

    /** Verwijdert emmers die al lang niet gebruikt zijn, zodat het geheugen niet kan volopen. */
    private fun purge(now: Long) {
        buckets.entries.removeIf { (_, bucket) -> synchronized(bucket) { now - bucket.updatedNanos > STALE_NANOS } }
        if (buckets.size > MAX_KEYS) buckets.clear()
    }

    private companion object {
        const val MAX_KEYS = 20_000
        const val STALE_NANOS = 2L * 60 * 60 * 1_000_000_000
    }
}

/** Welke limieten gelden voor een melding; zie [WorkflowLogIngestGuard]. */
object IngestLimits {
    const val IP_PER_MINUTE = 60
    const val NEW_SESSIONS_PER_IP_PER_HOUR = 30
    const val SESSION_PER_MINUTE = 20
    const val LOGINS_PER_IP_PER_MINUTE = 20
    const val GLOBAL_PER_MINUTE = 600

    /** Alle nieuwe sessies samen, ook als iemand per verzoek een ander adres verzint. */
    const val GLOBAL_NEW_SESSIONS_PER_HOUR = 200

    /** Zoveel sessies bewaart het logboek hooguit; daarna worden nieuwe sessies geweigerd tot er ruimte is gemaakt. */
    const val MAX_SESSIONS = 20_000
    const val MAX_BODY_BYTES = 1_000_000
}
