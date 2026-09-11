package nl.vdzon.hkh.collection

import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

/**
 * FAST: leest alleen de lijstpagina's (30/pagina) - snel, maar zonder PDF-link en een paar
 * velden die alleen op de detailpagina staan. FULL: haalt elk record apart op - langzaam
 * (rate-limited), maar met alle velden. Beide zijn hervatbaar: bestaande records worden
 * overgeslagen tenzij force=true.
 */
enum class ScrapeMode { FAST, FULL }

/**
 * Start en bewaakt het scrapen van alle ZCBS-collecties. Draait op een
 * achtergrondthread.
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
    fun start(startedBy: String, mode: ScrapeMode, force: Boolean): ScrapeRun {
        if (!running.compareAndSet(false, true)) {
            throw ScrapeAlreadyRunningException()
        }
        val runId = runs.start(startedBy, mode, force)
        executor.submit {
            try {
                scrapeAll(runId, mode, force)
            } finally {
                running.set(false)
            }
        }
        return runs.latest()!!
    }

    fun status(): ScrapeRun? = runs.latest()

    fun isRunning(): Boolean = running.get()

    private fun scrapeAll(runId: Long, mode: ScrapeMode, force: Boolean) {
        val progress = RunProgress(id = runId)
        try {
            logger.info("Scrape {} gestart (mode={}, force={})", runId, mode, force)
            for (collection in properties.collections) {
                progress.currentCollection = collection
                runs.update(progress)
                when (mode) {
                    ScrapeMode.FAST -> scrapeCollectionFast(collection, force, progress)
                    ScrapeMode.FULL -> scrapeCollectionFull(collection, force, progress)
                }
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

    /** Snel: alleen de lijstpagina's. Slaat idents over die al bekend zijn (samenvatting of volledig), tenzij force. */
    private fun scrapeCollectionFast(collection: String, force: Boolean, progress: RunProgress) {
        val summaries = client.listSummaries(collection)
        progress.total += summaries.size
        progress.perCollection.putIfAbsent(collection, 0)
        runs.update(progress)

        val existing = if (force) emptySet() else items.existingIdents(collection)
        for (summary in summaries) {
            if (!force && summary.ident in existing) {
                progress.skipped++
                continue
            }
            try {
                items.upsertSummary(summary)
                progress.processed++
                progress.perCollection.merge(collection, 1, Int::plus)
            } catch (ex: Exception) {
                progress.failed++
                logger.warn("Samenvatting {}/{} mislukt: {}", collection, summary.ident, ex.message)
            }
            if (progress.processed % 100 == 0) runs.update(progress)
        }
        runs.update(progress)
    }

    /** Volledig: elk record apart, rate-limited. Slaat alleen idents over die al compleet zijn, tenzij force. */
    private fun scrapeCollectionFull(collection: String, force: Boolean, progress: RunProgress) {
        val idents = client.listIdents(collection)
        progress.total += idents.size
        progress.perCollection.putIfAbsent(collection, 0)
        runs.update(progress)

        val complete = if (force) emptySet() else items.completeIdents(collection)
        for (ident in idents) {
            if (!force && ident in complete) {
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
