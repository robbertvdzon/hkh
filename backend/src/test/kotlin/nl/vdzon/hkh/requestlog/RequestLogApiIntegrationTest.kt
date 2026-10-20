package nl.vdzon.hkh.requestlog

import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.ScrapedRecord
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** Elke zoekopdracht en AI-vraag komt met adres, gebruiker en tijden in het logboek; beheer leest het nieuwste eerst. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class RequestLogApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val items: CollectionItemStore,
    @param:Autowired private val log: RequestLogService,
) {
    @Test
    fun `a collection search is logged with the forwarded address and the admin reads the log`() {
        items.upsert(ScrapedRecord("beeldbank", "rl-1", "Kerklaan 13a", "De dames Oostrum voor hun huis.", 1952, null, null, "https://example.org/rl-1", emptyMap()))
        mockMvc.get("/api/collections/search?q=Oostrum&collection=beeldbank") { header("X-Forwarded-For", "203.0.113.7, 10.0.0.1") }
            .andExpect { status { isOk() } }
        // Bladeren naar een volgende pagina hoort niet in het logboek.
        mockMvc.get("/api/collections/search?q=Oostrum&page=1").andExpect { status { isOk() } }

        mockMvc.get("/api/admin/requests").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/requests?limit=5") { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }
            .andExpect {
                status { isOk() }
                jsonPath("$[0].kind") { value("COLLECTION_SEARCH") }
                jsonPath("$[0].question") { value("Oostrum") }
                jsonPath("$[0].collection") { value("beeldbank") }
                jsonPath("$[0].ip") { value("203.0.113.7") }
                jsonPath("$[0].status") { value("SUCCEEDED") }
                jsonPath("$[0].expansion") { value(false) }
            }
        val entries = log.recent(10)
        assertTrue(entries.count { it.kind == RequestKind.COLLECTION_SEARCH && it.question == "Oostrum" } == 1, entries.toString())
        assertNotNull(entries.first().answerMs)
    }

    @Test
    fun `an AI question is opened on request and closed with status, model and times`() {
        val id = log.open(RequestKind.AI_QUESTION, "wie was burgemeester nielen?", "robbert@example.com", reference = "turn-rl-1", expansion = true)
        assertNotNull(id)
        log.firstFeedback("turn-rl-1")
        log.firstFeedback("turn-rl-1")
        log.finish("turn-rl-1", "SUCCEEDED", "anthropic/claude-sonnet-5-5", java.math.BigDecimal("0.3200"))
        val entry = log.recent(20).first { it.reference == "turn-rl-1" }
        assertEquals("SUCCEEDED", entry.status)
        assertEquals("anthropic/claude-sonnet-5-5", entry.model)
        assertEquals(0, java.math.BigDecimal("0.32").compareTo(entry.costUsd))
        assertEquals("robbert@example.com", entry.userEmail)
        assertTrue(entry.expansion)
        assertNotNull(entry.firstFeedbackMs)
        assertNotNull(entry.answerMs)
        assertTrue(entry.firstFeedbackMs!! <= entry.answerMs!!)
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
