package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.ScrapedRecord
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
class KeywordSearchServiceIntegrationTest(
    @param:Autowired private val items: CollectionItemStore,
    @param:Autowired private val cards: DocumentCardStore,
    @param:Autowired private val search: KeywordSearchService,
) {
    private fun record(collection: String, ident: String, title: String, description: String, year: Int?, image: Boolean) = ScrapedRecord(
        collection = collection, ident = ident, title = title, description = description, year = year,
        imageUrl = if (image) "https://www.historischekringheemskerk.nl/beeldbank/large/$ident.jpg" else null, pdfUrl = null,
        detailUrl = "https://example.org/$ident", fields = emptyMap(),
    )

    private fun card(collection: String, ident: String, summary: String, vararg keywords: CardKeyword) {
        val pending = cards.pending(collection, CARD_EXTRACTION_VERSION, false, 500).single { it.ident == ident }
        cards.save(DocumentCard(collection, ident, summary, pending.hasImage, keywords.toList(), CARD_EXTRACTION_VERSION, "test", pending.sourceHash))
    }

    @Test
    fun `terms match keywords tolerantly, years as a range, and full text as a fallback`() {
        items.upsert(record("beeldbank", "ks-1", "Kerklaan 13a", "De dames Oostrum voor hun huis.", 1952, image = true))
        items.upsert(record("beeldbank", "ks-2", "Pastorie", "Huishoudster Grard Oostrom.", 1960, image = true))
        items.upsert(record("artikelen", "ks-3", "Heemskerkse bakkers", "Over bakkerij Oosterman aan de Kerkweg.", 1975, image = false))
        items.upsert(record("archief", "ks-4", "Akte", "Verkoop van een huis aan de Kerklaan in 1949 door de weduwe Van Oostrum.", 1949, image = false))
        card("beeldbank", "ks-1", "Toos en Cis Oostrum voor hun huis aan de Kerklaan 13a.",
            CardKeyword(KeywordType.PERSON, "dames Oostrum", "Toos Oostrum"), CardKeyword(KeywordType.PERSON, "dames Oostrum", "Cis Oostrum"),
            CardKeyword(KeywordType.ADDRESS, "Kerklaan 13a", "Kerklaan 13a"), CardKeyword(KeywordType.YEAR, "1952", "1952", 1952, 1952))
        card("beeldbank", "ks-2", "Grard Oostrom, huishoudster van de pastoor.",
            CardKeyword(KeywordType.PERSON, "Grard Oostrom", "Grard Oostrom"), CardKeyword(KeywordType.YEAR, "1960", "1960", 1960, 1960))
        card("artikelen", "ks-3", "Bakkerij Oosterman aan de Kerkweg.",
            CardKeyword(KeywordType.ORGANISATION, "bakkerij Oosterman", "Bakkerij Oosterman"), CardKeyword(KeywordType.STREET, "Kerkweg", "Kerkweg"))
        // ks-4 heeft bewust geen kaart: alleen via de volledige tekst te vinden.

        val result = search.search(listOf(ResearchQuery(terms = listOf("Oostrum"))), exclude = emptySet())
        val idents = result.candidates.map { it.ref.ident }
        assertTrue(idents.indexOf("ks-1") < idents.indexOf("ks-2"), "exacte naam vóór variant: $idents")
        assertTrue("ks-2" in idents, "Oostrom moet als variant meedoen: $idents")
        assertTrue("ks-4" in idents, "vangnet volledige tekst: $idents")
        // Een trefwoordtreffer is sterk, een record dat alleen via de volledige tekst gevonden is niet.
        assertTrue(result.candidates.first { it.ref.ident == "ks-1" }.strong, "exacte naam als trefwoord")
        assertTrue(!result.candidates.first { it.ref.ident == "ks-4" }.strong, "alleen in de tekst")
        val report = result.terms.single()
        assertEquals("Oostrum", report.term)
        assertTrue("Grard Oostrom" in report.variants, report.variants.toString())
        assertTrue(report.keywordHits >= 2)
        val first = result.candidates.first { it.ref.ident == "ks-1" }
        assertTrue(first.hasImage)
        assertEquals(setOf("Oostrum"), first.matchedTerms)
        assertTrue(first.keywords.any { it == "person: Toos Oostrum" }, first.keywords.toString())
        assertEquals("Toos en Cis Oostrum voor hun huis aan de Kerklaan 13a.", first.summary)

        // Twee termen: een record dat beide raakt staat bovenaan.
        val both = search.search(listOf(ResearchQuery(terms = listOf("Oostrum", "Kerklaan"))), exclude = emptySet())
        assertEquals("ks-1", both.candidates.first().ref.ident)
        assertEquals(setOf("Oostrum", "Kerklaan"), both.candidates.first().matchedTerms)

        // Uitsluiten van al geziene records en filters op collectie, periode en beeld.
        val excluded = search.search(listOf(ResearchQuery(terms = listOf("Oostrum"))), exclude = setOf(ResearchRef("beeldbank", "ks-1")))
        assertTrue(excluded.candidates.none { it.ref.ident == "ks-1" })
        val filtered = search.search(listOf(ResearchQuery(terms = listOf("Oostrum"), yearFrom = 1955, yearTo = 1970, collections = listOf("beeldbank"), withImage = true)), exclude = emptySet())
        assertEquals(listOf("ks-2"), filtered.candidates.map { it.ref.ident })

        // Een los jaartal zoekt in de periode eromheen.
        val year = search.search(listOf(ResearchQuery(terms = listOf("1950"))), exclude = emptySet())
        assertTrue(year.candidates.map { it.ref.ident }.containsAll(listOf("ks-1", "ks-4")), year.candidates.map { it.ref.ident }.toString())
        assertTrue(year.candidates.none { it.ref.ident == "ks-3" })

        // Kaarten op aanvraag (bronnen van een eerder antwoord), in opgegeven volgorde.
        assertEquals(listOf("ks-3", "ks-1"), search.cards(listOf(ResearchRef("artikelen", "ks-3"), ResearchRef("beeldbank", "ks-1"))).map { it.ref.ident })
    }

    @Test
    fun `text hits carry the fragment, articles and title hits rank higher, and the final selection sorts by year with fixed records first`() {
        items.upsert(record("beeldbank", "fr-1", "Zeelaan", "Straatbeeld.", 1961, image = true))
        items.upsert(record("beeldbank", "fr-2", "Winkel aan de Zeelaan", "Kruidenier.", 1935, image = true))
        items.upsert(record("artikelen", "fr-3", "Brand in Kerkbeek", "Over de grote brand.", 1972, image = false))
        items.saveDocumentText("artikelen", "fr-3", "Inleiding over de buurt. " + "Tekst. ".repeat(40) + "In de nacht van 3 april 1972 brandde de boerderij aan de Zeelaan volledig af. " + "Slot. ".repeat(40), "hash-fr-3")
        items.upsert(record("beeldbank", "fr-4", "Luchtfoto Fort Veldhuis", "Luchtfoto uit 1922.", 1922, image = true))
        card("beeldbank", "fr-1", "De Zeelaan in 1961.", CardKeyword(KeywordType.STREET, "Zeelaan", "Zeelaan"))
        card("beeldbank", "fr-2", "Kruidenierswinkel aan de Zeelaan, 1935.", CardKeyword(KeywordType.STREET, "Zeelaan", "Zeelaan"))
        card("artikelen", "fr-3", "Artikel over de brand van 1972 in Kerkbeek.", CardKeyword(KeywordType.EVENT, "brand", "Brand 1972"))
        // fr-4 heeft geen kaart en geen trefwoord Zeelaan.

        val result = search.search(listOf(ResearchQuery(terms = listOf("Zeelaan"))), exclude = emptySet())
        val byIdent = result.candidates.associateBy { it.ref.ident }
        val article = byIdent.getValue("fr-3")
        assertTrue(article.hasText)
        assertTrue(article.fragments.single().contains("«Zeelaan»"), article.fragments.toString())
        assertTrue(byIdent.getValue("fr-1").fragments.isEmpty())
        // Titeltreffer en documenttekst wegen mee: het artikel (alleen via tekst) staat niet onder de foto zonder titeltreffer.
        val idents = result.candidates.map { it.ref.ident }
        assertTrue(idents.indexOf("fr-1") < idents.indexOf("fr-3"), "titeltreffer eerst: $idents")
        assertTrue(result.totalFound >= 3)

        // Sorteren op jaar: oudste eerst, records zonder jaar achteraan.
        val oldest = search.search(listOf(ResearchQuery(terms = listOf("Zeelaan"), sortByYear = YearSort.ASC)), exclude = emptySet()).candidates.map { it.ref.ident }
        assertEquals(listOf("fr-2", "fr-1", "fr-3"), oldest.filter { it.startsWith("fr-") })

        // De definitieve selectie: vaste records vooraan, daarna de treffers; zonder termen alleen de vaste records.
        val selected = search.select(ResearchQuery(terms = listOf("Zeelaan"), includeRecords = listOf(ResearchRef("beeldbank", "fr-4"))))
        assertEquals("fr-4", selected.candidates.first().ref.ident)
        assertTrue(selected.candidates.count { it.ref.ident == "fr-4" } == 1)
        assertTrue(selected.candidates.any { it.ref.ident == "fr-3" })
        val onlyIncluded = search.select(ResearchQuery(terms = emptyList(), includeRecords = listOf(ResearchRef("beeldbank", "fr-4"), ResearchRef("beeldbank", "fr-1"))))
        assertEquals(listOf("fr-4", "fr-1"), onlyIncluded.candidates.map { it.ref.ident })
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
