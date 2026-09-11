package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers
@SpringBootTest
class CollectionSearchIntegrationTest(
    @param:Autowired private val store: CollectionItemStore,
    @param:Autowired private val service: CollectionSearchService,
) {
    @Test
    fun `websearch syntax supports quoted phrases and loose words`() {
        store.upsert(fullRecord(ident = "1", title = "De brand in de kerk en de toren", description = "Grote schade na de brand"))
        store.upsert(fullRecord(ident = "2", title = "De toren en de kerk", description = "Twee losse woorden, geen brand"))

        val phrase = service.search("\"brand in de kerk\"", null, emptyMap(), 0, 20)
        assertEquals(listOf("1"), phrase.items.map { it.ident })

        val looseWords = service.search("kerk toren", null, emptyMap(), 0, 20)
        assertEquals(setOf("1", "2"), looseWords.items.map { it.ident }.toSet())
    }

    @Test
    fun `a fast summary never downgrades an already complete record`() {
        store.upsert(fullRecord(ident = "10", title = "Volledig record", description = "Alle velden"))

        store.upsertSummary(
            ListSummary(
                collection = "artikelen",
                ident = "10",
                title = "Overschreven titel",
                description = "Samenvatting",
                year = null,
                imageUrl = null,
                detailUrl = "https://example.org/10",
                fields = emptyMap(),
            ),
        )

        val stored = store.find("artikelen", "10")
        assertEquals("Volledig record", stored?.title)
        assertTrue(stored?.isComplete == true)
    }

    @Test
    fun `a fast summary is searchable but marked incomplete until fully scraped`() {
        store.upsertSummary(
            ListSummary(
                collection = "artikelen",
                ident = "11",
                title = "Snel gevonden titel",
                description = "Korte beschrijving uit de lijstpagina",
                year = null,
                imageUrl = null,
                detailUrl = "https://example.org/11",
                fields = emptyMap(),
            ),
        )

        val found = store.find("artikelen", "11")
        assertFalse(found!!.isComplete)

        val result = service.search("Snel gevonden", null, emptyMap(), 0, 20)
        assertTrue(result.items.any { it.ident == "11" })
    }

    @Test
    fun `search can be scoped to a single dynamic field`() {
        store.upsert(
            fullRecord(
                ident = "20",
                title = "Portret van een dorpsgenoot",
                description = "Onbekende inhoud",
                fields = mapOf("Auteur(s)" to "Jansen, Piet"),
            ),
        )
        store.upsert(
            fullRecord(
                ident = "21",
                title = "Jansen op de foto",
                description = "Onbekende inhoud",
                fields = mapOf("Auteur(s)" to "Bakker, Klaas"),
            ),
        )

        val byAuthor = service.search(null, null, mapOf("Auteur(s)" to "Jansen"), 0, 20)
        assertEquals(listOf("20"), byAuthor.items.map { it.ident })

        val byTitle = service.search(null, null, mapOf("title" to "Jansen"), 0, 20)
        assertEquals(listOf("21"), byTitle.items.map { it.ident })
    }

    @Test
    fun `multiple field filters combine with AND`() {
        store.upsert(
            fullRecord(
                ident = "40",
                title = "Sporttoernooi 1987",
                fields = mapOf("Rubriek" to "Sport, recreatie en ontspanning", "Auteur(s)" to "Jansen, Piet"),
            ),
        )
        store.upsert(
            fullRecord(
                ident = "41",
                title = "Sportdag school",
                fields = mapOf("Rubriek" to "Sport, recreatie en ontspanning", "Auteur(s)" to "Bakker, Klaas"),
            ),
        )

        val both = service.search(null, null, mapOf("Rubriek" to "Sport", "Auteur(s)" to "Jansen"), 0, 20)
        assertEquals(listOf("40"), both.items.map { it.ident })

        val rubriekOnly = service.search(null, null, mapOf("Rubriek" to "Sport"), 0, 20)
        assertEquals(setOf("40", "41"), rubriekOnly.items.map { it.ident }.toSet())
    }

    @Test
    fun `year is an exact match, not a text search`() {
        store.upsert(fullRecord(ident = "50", title = "Kroniek", year = 1954))
        store.upsert(fullRecord(ident = "51", title = "Andere kroniek", year = 1961))

        val result = service.search(null, null, emptyMap(), 0, 20, year = 1954)

        assertEquals(listOf("50"), result.items.map { it.ident })
    }

    private fun fullRecord(
        ident: String,
        title: String = "Titel $ident",
        description: String = "Beschrijving $ident",
        year: Int? = null,
        fields: Map<String, String> = emptyMap(),
    ) = ScrapedRecord(
        collection = "artikelen",
        ident = ident,
        title = title,
        description = description,
        year = year,
        imageUrl = null,
        pdfUrl = null,
        detailUrl = "https://example.org/$ident",
        fields = fields,
    )

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
