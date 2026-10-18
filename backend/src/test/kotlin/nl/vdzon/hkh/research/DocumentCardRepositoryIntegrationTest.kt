package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.ScrapedRecord
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.jdbc.core.JdbcTemplate
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
class DocumentCardRepositoryIntegrationTest(
    @param:Autowired private val items: CollectionItemStore,
    @param:Autowired private val cards: DocumentCardStore,
    @param:Autowired private val jdbc: JdbcTemplate,
) {
    private fun record(ident: String, description: String) = ScrapedRecord(
        collection = "beeldbank", ident = ident, title = "Straten Kerklaan", description = description, year = 1950,
        imageUrl = "https://www.historischekringheemskerk.nl/beeldbank/large/$ident.jpg", pdfUrl = null,
        detailUrl = "https://example.org/$ident", fields = mapOf("Straatnaam" to "Kerklaan"),
    )

    @Test
    fun `pending follows version and input changes, and keywords are searchable with tolerance`() {
        items.upsert(record("card-1", "De dames Oostrum voor hun huis aan de Kerklaan 13a."))
        items.upsert(record("card-2", "Grard Oostrom in de pastorie."))
        val pending = cards.pending("beeldbank", CARD_EXTRACTION_VERSION, includeFailed = false, limit = 100)
        val first = pending.single { it.ident == "card-1" }
        assertTrue(first.hasImage)
        assertEquals("Kerklaan", first.fields["Straatnaam"])

        cards.save(DocumentCard("beeldbank", "card-1", "Toos en Cis Oostrum wonen aan de Kerklaan 13a.", true, listOf(
            CardKeyword(KeywordType.PERSON, "dames Oostrum", "Toos Oostrum"),
            CardKeyword(KeywordType.PERSON, "dames Oostrum", "Cis Oostrum"),
            CardKeyword(KeywordType.ADDRESS, "Kerklaan 13a", "Kerklaan 13a"),
            CardKeyword(KeywordType.STREET, "Kerklaan", "Kerklaan", source = KeywordSource.FIELD),
            CardKeyword(KeywordType.YEAR, "1950", "1950", 1950, 1950, KeywordSource.FIELD),
        ), CARD_EXTRACTION_VERSION, "test/model", first.sourceHash))
        cards.save(DocumentCard("beeldbank", "card-2", "Grard Oostrom, huishoudster.", true, listOf(
            CardKeyword(KeywordType.PERSON, "Grard Oostrom", "Grard Oostrom"),
        ), CARD_EXTRACTION_VERSION, "test/model", pending.single { it.ident == "card-2" }.sourceHash))

        assertTrue(cards.pending("beeldbank", CARD_EXTRACTION_VERSION, false, 100).none { it.ident.startsWith("card-") })
        val stored = assertNotNull(cards.find("beeldbank", "card-1"))
        assertEquals(5, stored.keywords.size)
        assertEquals("Toos en Cis Oostrum wonen aan de Kerklaan 13a.", stored.summary)

        // Spellingtolerantie (woordniveau): Oostrom en Toos Oostrum liggen vlak bij Oostrum.
        val near = jdbc.queryForList(
            "SELECT normalized FROM keyword WHERE type = 'PERSON' AND 'Oostrum' <% normalized ORDER BY word_similarity('Oostrum', normalized) DESC",
            String::class.java,
        )
        assertTrue("Grard Oostrom" in near, near.toString())
        assertTrue("Toos Oostrum" in near, near.toString())

        // Gewijzigde invoer of een nieuwe extractieversie zet de kaart opnieuw op de lijst.
        items.upsert(record("card-1", "De dames Oostrum voor hun huis aan de Kerklaan 13a, met de buurvrouw."))
        assertTrue(cards.pending("beeldbank", CARD_EXTRACTION_VERSION, false, 100).any { it.ident == "card-1" })
        assertTrue(cards.pending("beeldbank", "card-v99", false, 100).any { it.ident == "card-2" })

        // Een mislukte extractie telt alleen mee als mislukte expliciet worden meegenomen.
        cards.saveError("beeldbank", "card-2", CARD_EXTRACTION_VERSION, "test/model", pending.single { it.ident == "card-2" }.sourceHash, "Geen kaart")
        assertTrue(cards.pending("beeldbank", CARD_EXTRACTION_VERSION, false, 100).none { it.ident == "card-2" })
        assertTrue(cards.pending("beeldbank", CARD_EXTRACTION_VERSION, true, 100).any { it.ident == "card-2" })
        val stats = cards.stats(CARD_EXTRACTION_VERSION)
        assertTrue(stats.failed >= 1)
        assertTrue(stats.keywords >= 5)
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
