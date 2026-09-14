package nl.vdzon.hkh.aisearch

import java.time.Instant
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
    override fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, limit: Int, offset: Int, year: Int?) = emptyList<CollectionItem>()
    override fun searchCount(query: String?, collection: String?, fieldQueries: Map<String, String>, year: Int?) = 0L
}
