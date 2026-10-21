package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.jdbc.core.JdbcTemplate
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** Het herstel van kapotte tekens (migratie V28) werkt op echte rijen: records, kaarten en trefwoorden. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
class FixMojibakeMigrationIntegrationTest(
    @param:Autowired private val items: CollectionItemStore,
    @param:Autowired private val jdbc: JdbcTemplate,
) {
    private fun record(ident: String, fields: Map<String, String>, title: String = "Akte") = ScrapedRecord(
        collection = "archief", ident = ident, title = title, description = "", year = 1975, imageUrl = null, pdfUrl = null,
        detailUrl = "https://example.org/$ident", fields = fields,
    )

    @Test
    fun `broken accents are repaired in records, cards and keywords while correct rows stay as they are`() {
        items.upsert(record("mj-1", mapOf("Type publicatie" to "NotariÃ«le akte", "Thema" to "Openbare leven (bioscoop, cafÃ©, horeca)")))
        items.upsert(record("mj-2", mapOf("Type publicatie" to "Notariële akte", "Plaats" to "Heemskerk")))
        // Een kaart die actueel was vóór het herstel, en een trefwoord met een kapotte naam.
        jdbc.update(
            "INSERT INTO document_card (collection, ident, summary, has_image, extraction_version, model, source_hash) SELECT collection, ident, 'Samenvatting', false, 'card-v1', 'test', md5(search_text || ' ' || coalesce(document_text, '')) FROM collection_item WHERE ident = 'mj-1'",
        )
        val keywordId = jdbc.queryForObject("INSERT INTO keyword (normalized, type) VALUES ('Openbare leven (bioscoop, cafÃ©, horeca)', 'OTHER') RETURNING id", Long::class.java)!!
        jdbc.update("INSERT INTO keyword_mention (keyword_id, collection, ident, literal, source) VALUES (?, 'archief', 'mj-1', 'Openbare leven (bioscoop, cafÃ©, horeca)', 'FIELD')", keywordId)

        val script = javaClass.getResource("/db/migration/V28__fix_mojibake.sql")!!.readText()
        jdbc.execute(script)

        val fields = jdbc.queryForObject("SELECT fields::text FROM collection_item WHERE ident = 'mj-1'", String::class.java)!!
        assertTrue("Notariële akte" in fields && "café, horeca" in fields, fields)
        assertTrue("Ã" !in fields, fields)
        assertTrue("café" in jdbc.queryForObject("SELECT search_text FROM collection_item WHERE ident = 'mj-1'", String::class.java)!!)
        // Een record dat al goed was blijft ongewijzigd.
        assertEquals("Notariële akte", jdbc.queryForObject("SELECT fields->>'Type publicatie' FROM collection_item WHERE ident = 'mj-2'", String::class.java))
        // De kaart blijft actueel: de bronhash volgt de herstelde tekst.
        val stale = jdbc.queryForObject(
            "SELECT count(*) FROM document_card c JOIN collection_item i ON i.collection = c.collection AND i.ident = c.ident WHERE i.ident = 'mj-1' AND c.source_hash <> md5(i.search_text || ' ' || coalesce(i.document_text, ''))",
            Long::class.java,
        )
        assertEquals(0L, stale)
        assertEquals("Openbare leven (bioscoop, café, horeca)", jdbc.queryForObject("SELECT normalized FROM keyword WHERE id = ?", String::class.java, keywordId))
        assertEquals("Openbare leven (bioscoop, café, horeca)", jdbc.queryForObject("SELECT literal FROM keyword_mention WHERE keyword_id = ?", String::class.java, keywordId))

        // Tweede keer draaien verandert niets meer.
        jdbc.execute(script)
        assertEquals("Notariële akte", jdbc.queryForObject("SELECT fields->>'Type publicatie' FROM collection_item WHERE ident = 'mj-1'", String::class.java))
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
