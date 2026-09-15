package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import nl.vdzon.hkh.docexport.HtmlToPdfRenderer
import nl.vdzon.hkh.docexport.PdfRenderException
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@Import(AiAnswerExportApiIntegrationTest.SwitchableRendererConfiguration::class)
class AiAnswerExportApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val renderer: SwitchableRenderer,
) {
    @AfterEach
    fun resetRenderer() {
        renderer.failing = false
    }

    @Test
    fun `an anonymous visitor downloads their answer as a pdf`() {
        val visitor = UUID.randomUUID()
        val answerId = createCompletedAnswer(visitor)

        val response = mockMvc.get("/api/ai-search/$answerId/export/pdf") {
            cookie(Cookie(VISITOR_COOKIE, visitor.toString()))
        }.andExpect {
            status { isOk() }
            header { string(HttpHeaders.CONTENT_TYPE, "application/pdf") }
            header {
                string(
                    HttpHeaders.CONTENT_DISPOSITION,
                    org.hamcrest.Matchers.containsString("attachment; filename=\"antwoord-$answerId.pdf\""),
                )
            }
        }.andReturn().response.contentAsByteArray

        assertTrue(response.size > 4, "De PDF-body is leeg")
        assertEquals("%PDF", response.decodeToString(0, 4))
        val text = Loader.loadPDF(response).use { PDFTextStripper().getText(it) }
        assertContains(text, "De geschiedenis van de Kerklaan")
        assertContains(text, "schepen en molenaar")
        assertContains(text, "Resolutieboek ambachtsheerlijkheid")
        assertContains(text, "beeldbank")
        assertContains(text, "https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42")
    }

    @Test
    fun `another visitor and an unknown answer get a not found without a body`() {
        val visitor = UUID.randomUUID()
        val answerId = createCompletedAnswer(visitor)

        mockMvc.get("/api/ai-search/$answerId/export/pdf") {
            cookie(Cookie(VISITOR_COOKIE, UUID.randomUUID().toString()))
        }.andExpect { status { isNotFound() } }

        mockMvc.get("/api/ai-search/$answerId/export/pdf")
            .andExpect { status { isNotFound() } }

        mockMvc.get("/api/ai-search/${UUID.randomUUID()}/export/pdf") {
            cookie(Cookie(VISITOR_COOKIE, visitor.toString()))
        }.andExpect { status { isNotFound() } }

        mockMvc.get("/api/ai-search/geen-uuid/export/pdf") {
            cookie(Cookie(VISITOR_COOKIE, visitor.toString()))
        }.andExpect { status { isNotFound() } }
    }

    @Test
    fun `a render failure gives an error status without a body`() {
        val visitor = UUID.randomUUID()
        val answerId = createCompletedAnswer(visitor)
        renderer.failing = true

        val response = mockMvc.get("/api/ai-search/$answerId/export/pdf") {
            cookie(Cookie(VISITOR_COOKIE, visitor.toString()))
        }.andExpect { status { isInternalServerError() } }.andReturn().response

        assertEquals(0, response.contentAsByteArray.size, "Een mislukte export mag geen lichaam teruggeven")
    }

    private fun createCompletedAnswer(visitorId: UUID): UUID {
        val sessionId = UUID.randomUUID()
        val answerId = UUID.randomUUID()
        jdbc.update("INSERT INTO ai_search_session (id, visitor_id) VALUES (?, ?)", sessionId, visitorId)
        jdbc.update(
            """
            INSERT INTO ai_search_turn (
                id, session_id, turn_number, question, status, progress_percent,
                progress_message, title, answer_html, sources, created_at, updated_at, completed_at
            ) VALUES (?, ?, 1, ?, 'SUCCEEDED', 100, 'Onderzoek afgerond', ?, ?, ?::jsonb,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """.trimIndent(),
            answerId,
            sessionId,
            "Wie was Jan Klaasz. Beemster?",
            "De geschiedenis van de Kerklaan",
            ANSWER_HTML,
            """[{"collection":"beeldbank","ident":"42"}]""",
        )
        return answerId
    }

    /** Laat het echte renderpad draaien, maar kan een renderfout simuleren. */
    class SwitchableRenderer : HtmlToPdfRenderer() {
        @Volatile
        var failing = false

        override fun render(title: String, bodyHtml: String, sources: List<String>): ByteArray {
            if (failing) throw PdfRenderException("Gesimuleerde renderfout")
            return super.render(title, bodyHtml, sources)
        }
    }

    @TestConfiguration
    class SwitchableRendererConfiguration {
        @Bean
        @Primary
        fun switchableRenderer() = SwitchableRenderer()
    }

    companion object {
        private val ANSWER_HTML = """
            <p>Jan Klaasz. Beemster was een <strong>schepen en molenaar</strong> in Heemskerk.</p>
            <section><hr><h2>Bronnen en afbeeldingen</h2>
            <article><h3><a href="https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42">Resolutieboek ambachtsheerlijkheid Heemskerk</a></h3>
            <p>Notulen van de schepenbank met vermelding van onderhoudswerk aan de dijk.</p></article></section>
        """.trimIndent()

        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
