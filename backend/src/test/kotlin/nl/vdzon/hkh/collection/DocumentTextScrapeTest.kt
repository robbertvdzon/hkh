package nl.vdzon.hkh.collection

import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.http.client.ClientHttpRequestInterceptor
import org.springframework.mock.http.client.MockClientHttpResponse
import org.springframework.web.client.RestClient

/**
 * De backfill (TEXT) en de tekstextractie tijdens een volledige scrape werken tegen een
 * nagebootste ZCBS-site: een recordpagina met PDF-link en de PDF zelf.
 */
class DocumentTextScrapeTest {
    private val pdf = PdfTextExtractorTest.pdfWithPages(listOf("Notaris Bremmers verklaart dat de boerderij is verkocht"))

    private fun client(requests: MutableList<String> = mutableListOf()): ZcbsClient {
        val interceptor = ClientHttpRequestInterceptor { request, _, _ ->
            val url = request.uri.toString()
            requests += url
            when {
                url.endsWith("/archief/pdf/10983.pdf") -> MockClientHttpResponse(pdf, HttpStatus.OK)
                url.endsWith("/archief/pdf/broken.pdf") -> MockClientHttpResponse("<!DOCTYPE html><html><body>viewer</body></html>".toByteArray(), HttpStatus.OK)
                url.contains("archief.pl") && url.contains("ident=10983") -> MockClientHttpResponse(RECORD_PAGE.toByteArray(Charsets.ISO_8859_1), HttpStatus.OK)
                url.contains("archief.pl") && url.contains("search=ALL") -> MockClientHttpResponse(LIST_PAGE.toByteArray(Charsets.ISO_8859_1), HttpStatus.OK)
                else -> MockClientHttpResponse(ByteArray(0), HttpStatus.NOT_FOUND)
            }
        }
        return ZcbsClient(properties, RestClient.builder().requestInterceptor(interceptor).build())
    }

    private val properties = ZcbsProperties(collections = listOf("archief"), requestDelayMs = 0)

    @Test
    fun `backfill extracts text for pending records and records failures per item`() {
        val items = InMemoryItems()
        // Oudere records verwijzen naar de pdf.js-viewer; de extractie haalt dan het bestand uit de file-parameter.
        items.upsert(record("10983", pdfUrl = "$BASE/pdfjs3/web/viewer.html?file=/archief/pdf/10983.pdf#search=&phrase=true"))
        items.upsert(record("11000", pdfUrl = "$BASE/archief/pdf/broken.pdf"))
        items.upsert(record("11001", pdfUrl = null))
        val runs = InMemoryRuns()
        val service = CollectionScrapeService(client(), items, runs, properties, DocumentTextService(client(), items))

        service.start("test@example.org", ScrapeMode.TEXT, force = false)
        val run = runs.awaitFinished()

        assertEquals(ScrapeStatus.COMPLETED, run.status)
        assertEquals(2, run.total)
        assertEquals(1, run.processed)
        assertEquals(1, run.failed)
        assertEquals(1, run.documents)
        assertEquals(1, run.documentsFailed)
        assertTrue(items.find("archief", "10983")!!.documentText!!.contains("Notaris Bremmers"))
        assertNotNull(items.find("archief", "10983")!!.documentPdfHash)
        assertTrue(items.find("archief", "11000")!!.documentTextError!!.contains("HTML-pagina"), items.find("archief", "11000")!!.documentTextError)
        assertNull(items.find("archief", "11001")!!.documentText)
        assertTrue(run.message!!.contains("1 documentteksten"), run.message)

        // Een volgende backfill probeert alleen de mislukte opnieuw.
        service.start("test@example.org", ScrapeMode.TEXT, force = false)
        assertEquals(1, runs.awaitFinished().total)
        // Met force ook de al opgehaalde, maar een ongewijzigde PDF telt als overgeslagen.
        service.start("test@example.org", ScrapeMode.TEXT, force = true)
        val forced = runs.awaitFinished()
        assertEquals(2, forced.total)
        assertEquals(1, forced.skipped)
        assertEquals(1, forced.failed)
    }

    @Test
    fun `a full scrape extracts the text right after storing a record with a pdf`() {
        val items = InMemoryItems()
        val runs = InMemoryRuns()
        val requests = mutableListOf<String>()
        val zcbs = client(requests)
        val service = CollectionScrapeService(zcbs, items, runs, properties, DocumentTextService(zcbs, items))

        service.start("test@example.org", ScrapeMode.FULL, force = false)
        val run = runs.awaitFinished()

        assertEquals(ScrapeStatus.COMPLETED, run.status)
        assertEquals(1, run.processed)
        assertEquals(1, run.documents)
        val item = items.find("archief", "10983")!!
        assertEquals("$BASE/archief/pdf/10983.pdf", item.pdfUrl)
        assertTrue(item.documentText!!.contains("Notaris Bremmers"))

        // Een tweede volledige scrape slaat complete records over en downloadt de PDF niet opnieuw.
        requests.clear()
        service.start("test@example.org", ScrapeMode.FULL, force = false)
        runs.awaitFinished()
        assertTrue(requests.none { it.endsWith(".pdf") }, requests.toString())

        // Met force wordt de PDF wel opgehaald, maar bij een ongewijzigde hash niet opnieuw geëxtraheerd.
        requests.clear()
        service.start("test@example.org", ScrapeMode.FULL, force = true)
        val forced = runs.awaitFinished()
        assertEquals(1, requests.count { it.endsWith(".pdf") })
        assertEquals(0, forced.documents)
        assertEquals(0, forced.documentsFailed)
    }

    private fun record(ident: String, pdfUrl: String?) = ScrapedRecord(
        collection = "archief", ident = ident, title = "Titel $ident", description = "Beschrijving", year = null,
        imageUrl = null, pdfUrl = pdfUrl, detailUrl = "$BASE/cgi-bin/archief.pl?ident=$ident", fields = emptyMap(),
    )

    private class InMemoryItems : CollectionItemStore {
        private val rows = linkedMapOf<String, CollectionItem>()
        private fun key(collection: String, ident: String) = "$collection/$ident"

        override fun upsert(record: ScrapedRecord) {
            val existing = rows[key(record.collection, record.ident)]
            rows[key(record.collection, record.ident)] = CollectionItem(
                id = existing?.id ?: (rows.size + 1).toLong(), collection = record.collection, ident = record.ident,
                title = record.title, description = record.description, year = record.year, imageUrl = record.imageUrl,
                pdfUrl = record.pdfUrl, detailUrl = record.detailUrl, fields = record.fields, isComplete = true,
                scrapedAt = Instant.now(), documentText = existing?.documentText, documentPdfHash = existing?.documentPdfHash,
                documentTextError = existing?.documentTextError,
            )
        }

        override fun upsertSummary(summary: ListSummary) = error("niet gebruikt")
        override fun existingIdents(collection: String) = rows.values.filter { it.collection == collection }.map { it.ident }.toSet()
        override fun completeIdents(collection: String) = rows.values.filter { it.collection == collection && it.isComplete }.map { it.ident }.toSet()
        override fun counts() = emptyList<CollectionCount>()
        override fun totalCount() = rows.size.toLong()
        override fun find(collection: String, ident: String) = rows[key(collection, ident)]
        override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?, options: CollectionSearchOptions) = emptyList<CollectionItem>()
        override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions) = 0L
        override fun documentTextIdents(collection: String) = rows.values.filter { it.collection == collection && it.documentText != null }.map { it.ident }.toSet()
        override fun pendingDocuments(collection: String, includeExtracted: Boolean) = rows.values
            .filter { it.collection == collection && it.pdfUrl != null && (includeExtracted || it.documentText == null) }
            .map { PendingDocument(it.collection, it.ident, it.pdfUrl!!, it.documentPdfHash) }

        override fun saveDocumentText(collection: String, ident: String, text: String, pdfHash: String) {
            rows.computeIfPresent(key(collection, ident)) { _, item -> item.copy(documentText = text, documentPdfHash = pdfHash, documentTextError = null) }
        }

        override fun saveDocumentTextError(collection: String, ident: String, error: String) {
            rows.computeIfPresent(key(collection, ident)) { _, item -> item.copy(documentTextError = error) }
        }
    }

    private class InMemoryRuns : ScrapeRunStore {
        private val runs = mutableListOf<ScrapeRun>()

        override fun start(startedBy: String, mode: ScrapeMode, force: Boolean): Long {
            val id = runs.size + 1L
            runs += ScrapeRun(id, ScrapeStatus.RUNNING, startedBy, mode, force, Instant.now(), null, 0, 0, 0, 0, null, null, emptyMap())
            return id
        }

        override fun update(run: RunProgress) = replace(run.id) {
            it.copy(total = run.total, processed = run.processed, skipped = run.skipped, failed = run.failed,
                currentCollection = run.currentCollection, perCollection = run.perCollection.toMap(),
                documents = run.documents, documentsFailed = run.documentsFailed)
        }

        override fun finish(id: Long, status: ScrapeStatus, message: String?) = replace(id) {
            it.copy(status = status, message = message, finishedAt = Instant.now(), currentCollection = null)
        }

        @Synchronized
        override fun latest(): ScrapeRun? = runs.lastOrNull()
        override fun anyRunning() = runs.any { it.status == ScrapeStatus.RUNNING }

        @Synchronized
        private fun replace(id: Long, change: (ScrapeRun) -> ScrapeRun) {
            val index = runs.indexOfFirst { it.id == id }
            runs[index] = change(runs[index])
        }

        fun awaitFinished(): ScrapeRun {
            val deadline = System.currentTimeMillis() + 10_000
            while (System.currentTimeMillis() < deadline) {
                val run = latest()
                if (run != null && run.status != ScrapeStatus.RUNNING) return run
                Thread.sleep(20)
            }
            error("Scrape-run is niet afgerond")
        }
    }

    companion object {
        const val BASE = "https://www.historischekringheemskerk.nl"
        val LIST_PAGE = """
            <html><body><table>
            <tr><td><a href="/cgi-bin/archief.pl?ident=10983">10983</a></td><td>testament</td></tr>
            </table></body></html>
        """.trimIndent()
        val RECORD_PAGE = """
            <html><head><title>testament</title></head><body>
            <a href="/pdfjs/web/viewer.html?file=/archief/pdf/10983.pdf">PDF</a>
            <table>
            <tr><td>Documentnummer</td><td>:</td><td>10983</td></tr>
            <tr><td>Titel</td><td>:</td><td>testament</td></tr>
            <tr><td>Omschrijving</td><td>:</td><td>Notaris J.H. Bremmers</td></tr>
            <tr><td>Datum</td><td>:</td><td>24-12-1949</td></tr>
            </table></body></html>
        """.trimIndent()
    }
}
