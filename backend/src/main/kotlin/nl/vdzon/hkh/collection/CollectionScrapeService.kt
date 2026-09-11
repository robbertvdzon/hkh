package nl.vdzon.hkh.collection

import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

/**
 * Start en bewaakt het scrapen van alle ZCBS-collecties. Draait op een
 * achtergrondthread, is rate-limited en hervatbaar (bestaande records worden
 * overgeslagen tenzij force=true).
 */
@Service
class CollectionScrapeService(
    private val client: ZcbsClient,
    private val items: CollectionItemStore,
    private val runs: ScrapeRunStore,
    private val properties: ZcbsProperties,
) {
    private val logger = LoggerFactory.getLogger(javaClass)
    private val running = AtomicBoolean(false)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "zcbs-scraper").apply { isDaemon = true }
    }

    /** Start een scrape. Gooit [ScrapeAlreadyRunningException] als er al één loopt. */
    fun start(startedBy: String, force: Boolean): ScrapeRun {
        if (!running.compareAndSet(false, true)) {
            throw ScrapeAlreadyRunningException()
        }
        val runId = runs.start(startedBy, force)
        executor.submit {
            try {
                scrapeAll(runId, force)
            } finally {
                running.set(false)
            }
        }
        return runs.latest()!!
    }

    fun status(): ScrapeRun? = runs.latest()

    fun isRunning(): Boolean = running.get()

    private fun scrapeAll(runId: Long, force: Boolean) {
        val progress = RunProgress(id = runId)
        try {
            logger.info("Scrape {} gestart (force={})", runId, force)
            for (collection in properties.collections) {
                progress.currentCollection = collection
                runs.update(progress)
                scrapeCollection(collection, force, progress)
            }
            runs.update(progress)
            runs.finish(runId, ScrapeStatus.COMPLETED, "Klaar: ${progress.processed} opgehaald, ${progress.skipped} overgeslagen, ${progress.failed} mislukt")
            logger.info("Scrape {} voltooid: {}", runId, progress)
        } catch (ex: Exception) {
            logger.error("Scrape {} mislukt", runId, ex)
            runs.update(progress)
            runs.finish(runId, ScrapeStatus.FAILED, "Mislukt: ${ex.message}")
        }
    }

    private fun scrapeCollection(collection: String, force: Boolean, progress: RunProgress) {
        val idents = client.listIdents(collection)
        progress.total += idents.size
        progress.perCollection.putIfAbsent(collection, 0)
        runs.update(progress)

        val existing = if (force) emptySet() else items.existingIdents(collection)
        for (ident in idents) {
            if (!force && ident in existing) {
                progress.skipped++
                continue
            }
            try {
                val record = client.fetchRecord(collection, ident)
                items.upsert(record)
                progress.processed++
                progress.perCollection.merge(collection, 1, Int::plus)
            } catch (ex: Exception) {
                progress.failed++
                logger.warn("Record {}/{} mislukt: {}", collection, ident, ex.message)
            }
            if (progress.processed % 25 == 0) runs.update(progress)
            sleep()
        }
        runs.update(progress)
    }

    private fun sleep() {
        val delay = properties.requestDelayMs
        if (delay > 0) {
            try {
                Thread.sleep(delay)
            } catch (ex: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }
}

class ScrapeAlreadyRunningException : RuntimeException("Er loopt al een scrape.")
