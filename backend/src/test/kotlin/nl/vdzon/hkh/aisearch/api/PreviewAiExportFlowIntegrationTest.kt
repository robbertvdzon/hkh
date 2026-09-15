package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.*
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance",
    "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh", "hkh.ai-search.fixture-enabled=true", "hkh.public-origin=https://hkh-acceptance.vdzonsoftware.nl"])
class PreviewAiExportFlowIntegrationTest(
    @param:Autowired private val mvc: MockMvc,
    @param:Autowired private val mapper: ObjectMapper,
) {
    @Test
    fun `isolated search completes through the real session source and PDF pipeline`() {
        val visitor = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val start = mvc.post("/api/ai-search/sessions") {
            cookie(visitor); contentType = MediaType.APPLICATION_JSON
            content = """{"question":"Maak een synthetisch testantwoord voor PDF-export"}"""
        }.andExpect { status { isAccepted() } }.andReturn().response
        val id = mapper.readTree(start.contentAsString).path("id").asText()
        var session = mapper.readTree(start.contentAsString)
        val deadline = System.nanoTime() + 10_000_000_000L
        while (session.path("turns")[0].path("status").asText() !in setOf("SUCCEEDED", "FAILED") && System.nanoTime() < deadline) {
            Thread.sleep(50)
            session = mapper.readTree(mvc.get("/api/ai-search/sessions/$id") { cookie(visitor) }.andReturn().response.contentAsString)
        }
        val turn = session.path("turns")[0]
        assertEquals("SUCCEEDED", turn.path("status").asText(), session.toString())
        val answerId = turn.path("id").asText()
        val pdf = mvc.get("/api/ai-search/$answerId/export/pdf") { cookie(visitor) }
            .andExpect { status { isOk() } }.andReturn().response.contentAsByteArray
        val text = Loader.loadPDF(pdf).use { PDFTextStripper().getText(it) }
        assertContains(text, "Testantwoord (synthetisch)")
        assertContains(text, "Synthetische bron voor PDF-export")
        assertContains(text.replace("\n", ""), "https://hkh-acceptance.vdzonsoftware.nl/#/objecten/beeldbank/test-pdf-001")
        assertFalse(text.contains("https://hkh.vdzonsoftware.nl"))
        mvc.get("/api/ai-search/$answerId/export/pdf") { cookie(Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())) }
            .andExpect { status { isNotFound() } }
    }
    companion object {
        @Container @ServiceConnection @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
