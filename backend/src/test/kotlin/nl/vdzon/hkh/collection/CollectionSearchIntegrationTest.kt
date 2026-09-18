package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class CollectionSearchIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val store: CollectionItemStore,
    @param:Autowired private val service: CollectionSearchService,
    @param:Autowired private val jdbc: org.springframework.jdbc.core.JdbcTemplate,
) {
    @Test
    fun `empty search does not enumerate the collection even when a tab is selected`() {
        store.upsert(fullRecord("empty-search", "Een willekeurig object"))
        for (collection in listOf(null, "artikelen")) {
            val result = service.search("  ", collection, emptyMap(), 0, 20)
            assertEquals(0, result.total)
            assertTrue(result.items.isEmpty())
            assertTrue(result.collectionCounts.isEmpty())
        }
    }

    @Test
    fun `collection counts match the query across all tabs and all pages`() {
        store.upsert(fullRecord("counts-a", "Telkerk uniek").copy(collection = "archief"))
        store.upsert(fullRecord("counts-b", "Telkerk uniek").copy(collection = "archief"))
        store.upsert(fullRecord("counts-c", "Telkerk uniek").copy(collection = "beeldbank"))
        store.upsert(fullRecord("counts-d", "Ander onderwerp").copy(collection = "beeldbank"))
        val counts = mapOf("archief" to 2L, "beeldbank" to 1L)
        val all = service.search("Telkerk", null, emptyMap(), 0, 1)
        assertEquals(3, all.total)
        assertEquals(1, all.items.size)
        assertEquals(counts, all.collectionCounts.associate { it.collection to it.count })
        for ((collection, count) in counts) {
            val tab = service.search("Telkerk", collection, emptyMap(), 0, 20)
            assertEquals(count, tab.total)
            assertEquals(count.toInt(), tab.items.size)
            assertEquals(counts, tab.collectionCounts.associate { it.collection to it.count })
        }
        mockMvc.get("/api/collections/search?q=Telkerk&collection=beeldbank").andExpect {
            status { isOk() }
            jsonPath("$.total") { value(1) }
            jsonPath("$.collectionCounts[0].count") { value(2) }
        }
    }

    @Test
    fun `equal search scores have stable ordering across pages`() {
        val idents = (1..25).map { "stable-%02d".format(it) }
        idents.reversed().forEach { ident ->
            store.upsert(fullRecord(ident = ident, title = "Paginavaste treffers", description = "Dezelfde zoekscore"))
        }
        val pages = (0..2).flatMap { page ->
            service.search("Paginavaste", null, emptyMap(), page, 10).items.map { it.ident }
        }
        assertEquals(idents, pages)
    }

    @Test
    fun `media endpoint rejects invalid tokens and hosts outside the import site`() {
        mockMvc.get("/api/collection-media/not-valid!").andExpect { status { isBadRequest() } }
        for (url in listOf("http://127.0.0.1/private", "https://example.org/image.jpg", "https://historischekringheemskerk.nl.evil.test/image.jpg")) {
            val token = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(url.toByteArray())
            mockMvc.get("/api/collection-media/$token").andExpect { status { isNotFound() } }
        }
    }

    @Test
    fun `ordinary detail and search output keep object and media links on our site`() {
        val origin = "https://www.historischekringheemskerk.nl"
        store.upsert(fullRecord(ident = "local-links", title = "Unieke linkcontrole", description = "Bron $origin").copy(
            detailUrl = "$origin/cgi-bin/artikelen.pl?ident=local-links",
            imageUrl = "$origin/objecten/foto.jpg", pdfUrl = "$origin/objecten/artikel.pdf",
            fields = mapOf("Bron" to "$origin/cgi-bin/artikelen.pl?ident=local-links"),
        ))
        val detail = mockMvc.get("/api/collections/artikelen/local-links").andExpect {
            status { isOk() }
            jsonPath("$.detailUrl") { value(CollectionLinks.detail("artikelen", "local-links")) }
            jsonPath("$.imageUrl") { value(CollectionLinks.media("$origin/objecten/foto.jpg")) }
            jsonPath("$.pdfUrl") { value(CollectionLinks.media("$origin/objecten/artikel.pdf")) }
        }.andReturn().response.contentAsString
        assertFalse(detail.contains("historischekringheemskerk", true))
        val result = mockMvc.get("/api/collections/search?q=Unieke%20linkcontrole")
            .andExpect { status { isOk() } }.andReturn().response.contentAsString
        assertFalse(result.contains("historischekringheemskerk", true))
    }

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

    @Test
    fun `literal modes distinguish AND OR phrase partial and whole words`() {
        store.upsert(fullRecord("literal-a", "kerk plein", "literal-set"))
        store.upsert(fullRecord("literal-b", "kerk met een plein", "literal-set"))
        store.upsert(fullRecord("literal-c", "kerkplein", "literal-set"))
        fun find(query: String, mode: String, partial: Boolean) = service.search(query, null,
            mapOf("description" to "literal-set"), 0, 20,
            options = CollectionSearchOptions(mode = mode, partial = partial, field = "title")).items.map { it.ident }.toSet()
        assertEquals(setOf("literal-a", "literal-b"), find("kerk plein", "and", false))
        assertEquals(setOf("literal-a"), find("kerk plein", "phrase", false))
        assertEquals(setOf("literal-a", "literal-b", "literal-c"), find("kerk", "and", true))
        assertEquals(setOf("literal-a", "literal-b"), find("kerk onbekend", "or", false))
        assertEquals(emptySet(), find("kerk onbekend", "and", false))
    }

    @Test
    fun `substring queries escape SQL wildcard characters and regex punctuation`() {
        store.upsert(fullRecord("literal-percent", "100%_juist", "special-set"))
        store.upsert(fullRecord("literal-other", "1000 onjuist", "special-set"))
        val result = service.search("%_", null, mapOf("description" to "special-set"), 0, 20,
            options = CollectionSearchOptions(mode = "and", partial = true))
        assertEquals(listOf("literal-percent"), result.items.map { it.ident })
        val regex = service.search("kerk|plein", null, emptyMap(), 0, 20,
            options = CollectionSearchOptions(mode = "and", partial = false))
        assertEquals(0, regex.total)
    }

    @Test
    fun `exact facets combine alternatives with OR and different facets with AND`() {
        listOf("facet-a" to "Kaart", "facet-b" to "Krantenartikel", "facet-c" to "Kaartboek").forEach { (id, type) ->
            store.upsert(fullRecord(id, "Facettoets", fields = mapOf("Type publicatie" to type, "Thema" to "Kastelen")).copy(collection = "archief"))
        }
        store.upsert(fullRecord("facet-d", "Facettoets", fields = mapOf("Type publicatie" to "Kaart", "Thema" to "Sport")).copy(collection = "archief"))
        val options = CollectionSearchOptions(filters = mapOf("Type publicatie" to listOf("Kaart", "Krantenartikel"), "Thema" to listOf("Kastelen")))
        val result = service.search("Facettoets", "archief", emptyMap(), 0, 20, options = options)
        assertEquals(setOf("facet-a", "facet-b"), result.items.map { it.ident }.toSet())
        val facet = service.facet("Facettoets", "archief", emptyMap(), null, options, "Type publicatie", "")
        assertEquals(mapOf("Kaart" to 1L, "Kaartboek" to 1L, "Krantenartikel" to 1L), facet.values.associate { it.value to it.count })
    }

    @Test
    fun `facet value search reaches values beyond the first hundred`() {
        (0..109).forEach { n -> store.upsert(fullRecord("facet-many-$n", "Facetpaginatoets", fields = mapOf("Auteur(s)" to "Auteur %03d".format(n)))) }
        val first = service.facet("Facetpaginatoets", "artikelen", emptyMap(), null, CollectionSearchOptions(), "Auteur(s)", "")
        assertEquals(110, first.totalValues)
        assertEquals(100, first.values.size)
        val last = service.facet("Facetpaginatoets", "artikelen", emptyMap(), null, CollectionSearchOptions(), "Auteur(s)", "109")
        assertEquals(listOf("Auteur 109"), last.values.map { it.value })
    }

    @Test
    fun `birth period uses birth date and never death or publication year`() {
        store.upsert(fullRecord("birth-a", "Geboortetoets", year = 1970, fields = mapOf("Geboren op" to "03-02-1890")).copy(collection = "bidprent"))
        store.upsert(fullRecord("birth-b", "Geboortetoets", year = 1890, fields = mapOf("Geboren op" to "onbekend")).copy(collection = "bidprent"))
        store.upsert(fullRecord("birth-c", "Geboortetoets", year = 1960, fields = mapOf("Geboren op" to "1900-05-10")).copy(collection = "bidprent"))
        val result = service.search("Geboortetoets", "bidprent", emptyMap(), 0, 20,
            options = CollectionSearchOptions(yearFrom = 1890, yearTo = 1900, sort = "oldest"))
        assertEquals(listOf("birth-a", "birth-c"), result.items.map { it.ident })
    }

    @Test
    fun `document text can be included separately and is omitted from result metadata`() {
        store.upsert(fullRecord("ocr-only", "Uniek OCR document", fields = mapOf("OCR-tekst" to "documenttekstmatch", "Auteur(s)" to "Auteur")))
        assertTrue(service.documentTextAvailable())
        assertEquals(1, service.search("documenttekstmatch", null, emptyMap(), 0, 20,
            options = CollectionSearchOptions(mode = "and", partial = true, documentText = true)).total)
        assertEquals(0, service.search("documenttekstmatch", null, emptyMap(), 0, 20,
            options = CollectionSearchOptions(mode = "and", partial = true, documentText = false)).total)
        mockMvc.get("/api/collections/search") { param("q", "documenttekstmatch") }.andExpect {
            status { isOk() }
            jsonPath("$.items[0].fields['Auteur(s)']") { value("Auteur") }
            jsonPath("$.items[0].fields['OCR-tekst']") { doesNotExist() }
            jsonPath("$.documentTextAvailable") { value(true) }
        }
    }

    @Test
    fun `recent means first import and excludes rows whose arrival is unknown`() {
        val record = fullRecord("recent-old", "Recentheidstoets")
        store.upsert(record)
        jdbc.update("UPDATE collection_item SET added_at = CURRENT_TIMESTAMP - INTERVAL '400 days' WHERE ident = ?", record.ident)
        store.upsert(record.copy(description = "Opnieuw geïmporteerd"))
        store.upsert(fullRecord("recent-unknown", "Recentheidstoets"))
        jdbc.update("UPDATE collection_item SET added_at = NULL WHERE ident = 'recent-unknown'")
        store.upsert(fullRecord("recent-new", "Recentheidstoets"))
        val result = service.search("Recentheidstoets", null, emptyMap(), 0, 20, options = CollectionSearchOptions(recentDays = 7))
        assertEquals(listOf("recent-new"), result.items.map { it.ident })
    }

    @Test
    fun `explicit title and number sorts stay stable across pages`() {
        listOf("sort-20", "sort-2", "sort-1").forEach { store.upsert(fullRecord(it, "Sorteertoets")) }
        val options = CollectionSearchOptions(sort = "number")
        val items = (0..2).flatMap { service.search("Sorteertoets", null, emptyMap(), it, 1, options = options).items }
        assertEquals(listOf("sort-1", "sort-2", "sort-20"), items.map { it.ident })
    }

    @Test
    fun `API rejects malformed ranges and collection mismatched filters`() {
        for (params in listOf(mapOf("from" to "2000", "to" to "1900"), mapOf("from" to "abc"), mapOf("mode" to "sql"), mapOf("sort" to "drop"), mapOf("partial" to "maybe"), mapOf("filter" to "Onbekend:Hout", "collection" to "bidprent"))) {
            mockMvc.get("/api/collections/search") { params.forEach { (k, v) -> param(k, v) } }.andExpect { status { isBadRequest() } }
        }
        mockMvc.get("/api/collections/facets") { param("collection", "archief"); param("facet", "password") }.andExpect { status { isBadRequest() } }
    }

    @Test
    fun `document matches include bounded excerpts without exposing the full OCR field`() {
        store.upsert(fullRecord("ocr-excerpt", "Bijzondere dorpskroniek", fields = mapOf(
            "OCR-tekst" to "In deze kroniek staat dat de fragmenttoetsschool aan de Kerklaan werd geopend. " + "Overige tekst. ".repeat(100),
        )))
        val documentOnly = service.search("fragmenttoetsschool", null, emptyMap(), 0, 20).items.single()
        assertTrue(documentOnly.documentSnippet!!.contains("fragmenttoetsschool"))
        assertTrue(documentOnly.documentSnippet.length <= 500)
        assertFalse(documentOnly.documentSnippet.contains("HKHMATCH"))
        val mixed = service.search("dorpskroniek fragmenttoetsschool", null, emptyMap(), 0, 20).items.single()
        assertTrue(mixed.documentSnippet!!.contains("fragmenttoetsschool"))
        val partial = service.search("fragmenttoets", null, emptyMap(), 0, 20,
            options = CollectionSearchOptions(mode = "and", partial = true)).items.single()
        assertTrue(partial.documentSnippet!!.contains("fragmenttoetsschool"))
        val metadataOnly = service.search("dorpskroniek", null, emptyMap(), 0, 20).items.single()
        assertEquals(null, metadataOnly.documentSnippet)
        assertTrue(service.search("fragmenttoetsschool", null, emptyMap(), 0, 20,
            options = CollectionSearchOptions(documentText = false)).items.isEmpty())
        assertTrue(service.search(null, null, mapOf("description" to "fragmenttoetsschool"), 0, 20).items.isEmpty())
        mockMvc.get("/api/collections/search") { param("q", "fragmenttoetsschool") }.andExpect {
            status { isOk() }
            jsonPath("$.items[0].documentSnippet") { isNotEmpty() }
            jsonPath("$.items[0].fields['OCR-tekst']") { doesNotExist() }
        }
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
