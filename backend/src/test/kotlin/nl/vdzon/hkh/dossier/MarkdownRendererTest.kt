package nl.vdzon.hkh.dossier

import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import nl.vdzon.hkh.collection.CollectionCount
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.CollectionSearchService
import nl.vdzon.hkh.collection.ListSummary
import nl.vdzon.hkh.collection.ScrapedRecord
import org.junit.jupiter.api.Test

class MarkdownRendererTest {
    private val known = CollectionItem(
        id = 1,
        collection = "beeldbank",
        ident = "12345",
        title = "Kerklaan 12",
        description = "Woonhuis",
        year = 1932,
        imageUrl = "https://www.historischekringheemskerk.nl/objecten/12345.jpg",
        pdfUrl = null,
        detailUrl = "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=12345",
        fields = emptyMap(),
        isComplete = true,
        scrapedAt = Instant.now(),
    )

    private val renderer = MarkdownRenderer(CollectionSearchService(FakeStore(mapOf("beeldbank/12345" to known))))

    @Test
    fun `renders markdown and resolves known hkh sources into safe links`() {
        val rendered = renderer.render("## Bewoners\n\nDe familie Jansen woonde op [Kerklaan 12](hkh:beeldbank/12345).")

        assertTrue(rendered.html.contains("<h2>Bewoners</h2>"))
        assertTrue(rendered.html.contains("href=\"https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=12345\""))
        assertTrue(rendered.html.contains("data-hkh-collection=\"beeldbank\""))
        assertEquals(listOf("beeldbank/12345"), rendered.sources.map { "${it.collection}/${it.ident}" })
        assertEquals("Kerklaan 12", rendered.sources.single().title)
        assertTrue(rendered.unknownSources.isEmpty())
    }

    @Test
    fun `unknown sources, foreign links, images and raw html are neutralised`() {
        val rendered = renderer.render(
            "Zie [onbekend](hkh:beeldbank/999) en [elders](https://example.com) ![foto](https://example.com/x.jpg) <script>alert(1)</script>",
        )

        assertFalse(rendered.html.contains("href="))
        assertFalse(rendered.html.contains("<img"))
        assertFalse(rendered.html.contains("<script"))
        assertTrue(rendered.html.contains("data-hkh-unknown"))
        assertEquals(listOf("beeldbank/999"), rendered.unknownSources)
        assertEquals(listOf("beeldbank" to "999"), renderer.sourceRefs("Zie [x](hkh:beeldbank/999) en nogmaals [y](hkh:beeldbank/999)."))
    }

    private class FakeStore(private val items: Map<String, CollectionItem>) : CollectionItemStore {
        override fun upsert(record: ScrapedRecord) = error("unused")
        override fun upsertSummary(summary: ListSummary) = error("unused")
        override fun existingIdents(collection: String): Set<String> = emptySet()
        override fun completeIdents(collection: String): Set<String> = emptySet()
        override fun counts(): List<CollectionCount> = emptyList()
        override fun totalCount(): Long = items.size.toLong()
        override fun find(collection: String, ident: String): CollectionItem? = items["$collection/$ident"]
        override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?): List<CollectionItem> = emptyList()
        override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?): Long = 0
    }
}
