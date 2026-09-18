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
import org.jsoup.Jsoup

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
        assertTrue(rendered.html.contains("href=\"https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/12345\""))
        assertFalse(rendered.html.contains("historischekringheemskerk", ignoreCase = true))
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

    @Test
    fun `collection images render in the article with caption source link and deduplicated reference`() {
        val result = renderer.render("Voor het beeld.\n\n![Het huis aan de Kerklaan](hkh:beeldbank/12345)\n\nNa het beeld: [bron](hkh:beeldbank/12345).")
        val html = Jsoup.parseBodyFragment(result.html)
        val image = html.selectFirst("figure img")!!
        assertTrue(image.attr("src").startsWith("https://hkh.vdzonsoftware.nl/api/collection-media/"))
        assertEquals("Het huis aan de Kerklaan", image.attr("alt"))
        assertEquals("https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/12345", image.parent()!!.attr("href"))
        assertEquals("Het huis aan de Kerklaan — beeldbank 12345", html.selectFirst("figcaption")!!.text())
        assertEquals(1, result.sources.size)
        assertTrue(result.html.indexOf("Voor het beeld") < result.html.indexOf("<figure"))
        assertTrue(result.html.indexOf("</figure>") < result.html.indexOf("Na het beeld"))
        assertEquals(listOf("beeldbank" to "12345"), renderer.sourceRefs("![Huis](hkh:beeldbank/12345)"))
    }

    @Test
    fun `missing image references and records without usable images produce readable fallbacks`() {
        val unsafe = known.copy(ident = "2", imageUrl = "https://example.com/tracker.png")
        val absent = known.copy(ident = "3", imageUrl = null)
        val localRenderer = MarkdownRenderer(CollectionSearchService(FakeStore(mapOf("beeldbank/2" to unsafe, "beeldbank/3" to absent))))
        val result = localRenderer.render("![Onbekend](hkh:beeldbank/404)\n\n![Geen foto](hkh:beeldbank/3)\n\n![Extern](hkh:beeldbank/2)")
        assertFalse(result.html.contains("<img"))
        assertTrue(result.html.contains("Afbeelding niet gevonden: Onbekend"))
        assertTrue(result.html.contains("Afbeelding niet beschikbaar: Geen foto"))
        assertFalse(result.html.contains("example.com"))
        assertEquals(listOf("beeldbank/404"), result.unknownSources)
        assertEquals(2, result.sources.size)
    }

    @Test
    fun `image captions cannot introduce html and nested image links stay valid`() {
        val result = renderer.render("[![Een &lt;script&gt; in het bijschrift](hkh:beeldbank/12345)](hkh:beeldbank/12345)")
        val html = Jsoup.parseBodyFragment(result.html)
        assertEquals(1, html.select("img").size)
        assertTrue(html.select("a a, script").isEmpty())
        assertTrue(html.selectFirst("figcaption")!!.text().contains("<script>"))
    }

    private class FakeStore(private val items: Map<String, CollectionItem>) : CollectionItemStore {
        override fun upsert(record: ScrapedRecord) = error("unused")
        override fun upsertSummary(summary: ListSummary) = error("unused")
        override fun existingIdents(collection: String): Set<String> = emptySet()
        override fun completeIdents(collection: String): Set<String> = emptySet()
        override fun counts(): List<CollectionCount> = emptyList()
        override fun totalCount(): Long = items.size.toLong()
        override fun find(collection: String, ident: String): CollectionItem? = items["$collection/$ident"]
        override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?, options: nl.vdzon.hkh.collection.CollectionSearchOptions): List<CollectionItem> = emptyList()
        override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?, options: nl.vdzon.hkh.collection.CollectionSearchOptions): Long = 0
    }
}
