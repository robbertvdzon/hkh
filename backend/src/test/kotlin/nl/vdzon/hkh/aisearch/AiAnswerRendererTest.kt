package nl.vdzon.hkh.aisearch

import java.time.Instant
import org.jsoup.Jsoup
import kotlin.test.assertTrue
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import nl.vdzon.hkh.collection.CollectionLinks
import nl.vdzon.hkh.collection.CollectionCount
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.CollectionSearchService
import nl.vdzon.hkh.collection.ListSummary
import nl.vdzon.hkh.collection.ScrapedRecord
import tools.jackson.databind.ObjectMapper

class AiAnswerRendererTest {
    @Test
    fun `verifieert bronnen en verwijdert onveilige html en links`() {
        val item = CollectionItem(
            id = 1,
            collection = "beeldbank",
            ident = "42",
            title = "Kerklaan 10",
            description = "Een straatbeeld.",
            year = 1950,
            imageUrl = "https://www.historischekringheemskerk.nl/foto.jpg",
            pdfUrl = null,
            detailUrl = "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=42",
            fields = emptyMap(),
            isComplete = true,
            scrapedAt = Instant.EPOCH,
        )
        val renderer = AiAnswerRenderer(CollectionSearchService(FakeStore(item)))
        val result = ObjectMapper().readTree(
            """
            {
              "title":"Onderzoek",
              "answerHtml":"<h2>Verhaal</h2><script>alert(1)</script><a href='https://evil.test' data-hkh-source='beeldbank/42'>bron</a><a href='https://evil.test'>fout</a>",
              "sources":[{"collection":"beeldbank","ident":"42"},{"collection":"beeldbank","ident":"bestaat-niet"}],
              "suggestedFollowUps":["Meer?", "Meer?"]
            }
            """.trimIndent(),
        )

        val rendered = renderer.render(result)

        assertEquals(listOf(AiSourceRef("beeldbank", "42")), rendered.sources)
        assertEquals(listOf("Meer?"), rendered.suggestedFollowUps)
        assertFalse(rendered.html.contains("script"))
        assertFalse(rendered.html.contains("evil.test"))
        assertContains(rendered.html, CollectionLinks.detail(item.collection, item.ident))
        assertFalse(rendered.html.contains("historischekringheemskerk", ignoreCase = true))
        assertContains(rendered.html, CollectionLinks.media(item.imageUrl)!!)
        assertContains(rendered.html, "Bekijk dit object in de collectie")
    }
    @Test
    fun `plaatst een gecontroleerde foto tussen alinea's met bijschrift en bron zonder dubbel beeld`() {
        val item = imageRecord()
        val html = renderHtml(item, """
            <p>Voor de foto.</p>
            <figure data-hkh-source="beeldbank/42" onclick="evil()">
              <img src="https://evil.test/image.jpg">
              <figcaption>Kerklaan rond 1950 <a href="https://evil.test">in beeld</a></figcaption>
            </figure>
            <p>Na de foto.</p>
        """.trimIndent())
        val document = Jsoup.parseBodyFragment(html)
        assertEquals(listOf("p", "figure", "p", "section"), document.body().children().map { it.tagName() })
        assertEquals(1, document.select("img").size)
        val figure = document.selectFirst("figure")!!
        assertEquals(CollectionLinks.media(item.imageUrl), figure.selectFirst("img")!!.attr("src"))
        assertEquals("Kerklaan rond 1950 in beeld", figure.selectFirst("img")!!.attr("alt"))
        assertContains(figure.selectFirst("figcaption")!!.text(), "Kerklaan rond 1950 in beeld — beeldbank · 42")
        assertEquals(CollectionLinks.detail("beeldbank", "42"), figure.selectFirst("figcaption a")!!.attr("href"))
        assertTrue(document.select("section img").isEmpty())
        assertContains(document.selectFirst("section")!!.text(), "Bekijk dit object in de collectie")
        assertFalse(html.contains("evil"))
        assertFalse(html.contains("data-hkh-source"))
    }

    @Test
    fun `onbekende of niet opgegeven beelden en losse image urls worden niet ingevoegd`() {
        val html = renderHtml(imageRecord(), """
            <p>Het verhaal blijft staan.</p>
            <figure data-hkh-source="beeldbank/onbekend"><figcaption>Onbekend</figcaption></figure>
            <figure data-hkh-source="beeldbank/42"><figcaption>Niet opgegeven</figcaption></figure>
            <img src="https://evil.test/tracker.jpg" onerror="evil()">
        """.trimIndent(), sources = "[]")
        val document = Jsoup.parseBodyFragment(html)
        assertTrue(document.select("figure, img").isEmpty())
        assertEquals("Het verhaal blijft staan.", document.body().text())
    }

    @Test
    fun `bron zonder veilig beschikbaar beeld krijgt een bronlink in plaats van een kapotte foto`() {
        for (url in listOf(null, "https://evil.test/image.jpg")) {
            val html = renderHtml(imageRecord(url), """
                <p>Voor.</p><figure data-hkh-source="beeldbank/42"><figcaption>De Kerklaan</figcaption></figure><p>Na.</p>
            """.trimIndent())
            val document = Jsoup.parseBodyFragment(html)
            assertTrue(document.select("img").isEmpty())
            assertEquals("Afbeelding niet beschikbaar: De Kerklaan", document.selectFirst("figure a")!!.text())
            assertEquals(CollectionLinks.detail("beeldbank", "42"), document.selectFirst("figure a")!!.attr("href"))
            assertFalse(html.contains("evil.test"))
        }
    }

    @Test
    fun `herhaalde fotoplaatsing toont het beeld een keer en gebruikt de titel zonder bijschrift`() {
        val html = renderHtml(imageRecord(), """
            <figure data-hkh-source="beeldbank/42"></figure>
            <p>Vervolg.</p><figure data-hkh-source="beeldbank/42"></figure>
        """.trimIndent())
        val document = Jsoup.parseBodyFragment(html)
        assertEquals(1, document.select("img").size)
        assertEquals("Kerklaan 10", document.selectFirst("img")!!.attr("alt"))
        assertContains(document.body().text(), "Vervolg.")
    }

    private fun renderHtml(
        item: CollectionItem,
        html: String,
        sources: String = """[{"collection":"beeldbank","ident":"42"}]""",
    ): String {
        val mapper = ObjectMapper()
        val result = mapper.createObjectNode().put("title", "Onderzoek").put("answerHtml", html)
        result.set("sources", mapper.readTree(sources))
        return AiAnswerRenderer(CollectionSearchService(FakeStore(item))).render(result).html
    }

    private fun imageRecord(imageUrl: String? = "https://www.historischekringheemskerk.nl/foto.jpg") = CollectionItem(
        id = 1, collection = "beeldbank", ident = "42", title = "Kerklaan 10", description = "Een straatbeeld.",
        year = 1950, imageUrl = imageUrl, pdfUrl = null,
        detailUrl = "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=42",
        fields = emptyMap(), isComplete = true, scrapedAt = Instant.EPOCH,
    )

}

private class FakeStore(private val item: CollectionItem) : CollectionItemStore {
    override fun find(collection: String, ident: String): CollectionItem? =
        item.takeIf { it.collection == collection && it.ident == ident }

    override fun upsert(record: ScrapedRecord) = Unit
    override fun upsertSummary(summary: ListSummary) = Unit
    override fun existingIdents(collection: String) = emptySet<String>()
    override fun completeIdents(collection: String) = emptySet<String>()
    override fun counts() = emptyList<CollectionCount>()
    override fun totalCount() = 0L
    override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?, options: nl.vdzon.hkh.collection.CollectionSearchOptions) = emptyList<CollectionItem>()
    override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?, options: nl.vdzon.hkh.collection.CollectionSearchOptions) = 0L
}
