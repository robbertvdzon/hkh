package nl.vdzon.hkh.dossier.api

import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import nl.vdzon.hkh.aisearch.api.AiAnswerExportApiIntegrationTest.SwitchableRenderer
import nl.vdzon.hkh.aisearch.api.AiAnswerExportApiIntegrationTest.SwitchableRendererConfiguration
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.hamcrest.Matchers.containsString
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Import
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.web.servlet.MockHttpServletRequestDsl
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

/**
 * Het HTTP-contract van de artikel-PDF-export tegen een echte database. De foutstatus voor
 * 'geen toegang' wordt niet hard gecodeerd maar vergeleken met het bestaande artikel-endpoint.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(properties = ["hkh.auth.google-client-id=test-client"])
@AutoConfigureMockMvc
@Import(DossierApiIntegrationTest.FakeGoogle::class, SwitchableRendererConfiguration::class)
class ArticleExportApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val objectMapper: ObjectMapper,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val renderer: SwitchableRenderer,
) {
    @AfterEach
    fun resetRenderer() {
        renderer.failing = false
    }

    @Test
    fun `an authorised user downloads the current article version as a pdf`() {
        val owner = login("auteur@example.com")
        seedCollectionItem()
        val (dossierId, articleId) = createArticle(owner)

        val body = mockMvc.get("/api/dossiers/$dossierId/articles/$articleId/export/pdf") { auth(owner) }
            .andExpect {
                status { isOk() }
                header { string(HttpHeaders.CONTENT_TYPE, "application/pdf") }
                header {
                    string(HttpHeaders.CONTENT_DISPOSITION, containsString("attachment; filename=\"artikel-$articleId.pdf\""))
                }
            }.andReturn().response.contentAsByteArray

        assertTrue(body.size > 4, "De PDF-body is leeg")
        assertEquals("%PDF", body.decodeToString(0, 4))
        val text = Loader.loadPDF(body).use { PDFTextStripper().getText(it) }
        assertContains(text, "De Kerklaan")
        assertContains(text, "Jansen")
        assertContains(text, "Bronnen")
        assertContains(text, "Kerklaan 12 in 1932")
        assertContains(text, "beeldbank/42")
    }

    @Test
    fun `a user without dossier access gets the same status as on the existing article endpoint`() {
        val owner = login("eigenaar@example.com")
        val stranger = login("vreemde@example.com")
        seedCollectionItem()
        val (dossierId, articleId) = createArticle(owner)

        val existing = mockMvc.get("/api/articles/$articleId") { auth(stranger) }.andReturn().response.status
        val export = mockMvc.get("/api/dossiers/$dossierId/articles/$articleId/export/pdf") { auth(stranger) }
            .andReturn().response

        assertEquals(existing, export.status, "De export moet dezelfde foutstatus geven als het bestaande endpoint")
        assertEquals(0, export.contentAsByteArray.size, "Een geweigerde export mag geen PDF-lichaam teruggeven")

        // Zonder sessie geldt hetzelfde: dezelfde status als op het bestaande endpoint.
        val anonymousExisting = mockMvc.get("/api/articles/$articleId").andReturn().response.status
        mockMvc.get("/api/dossiers/$dossierId/articles/$articleId/export/pdf")
            .andExpect { status { isEqualTo(anonymousExisting) } }
    }

    @Test
    fun `a render failure gives an error status without a body`() {
        val owner = login("mislukt@example.com")
        seedCollectionItem()
        val (dossierId, articleId) = createArticle(owner)
        renderer.failing = true

        val response = mockMvc.get("/api/dossiers/$dossierId/articles/$articleId/export/pdf") { auth(owner) }
            .andExpect { status { isInternalServerError() } }.andReturn().response

        assertEquals(0, response.contentAsByteArray.size, "Een mislukte export mag geen lichaam teruggeven")
    }

    private fun createArticle(token: String): Pair<String, String> {
        val dossier = objectMapper.readTree(
            mockMvc.post("/api/dossiers") {
                auth(token); contentType = MediaType.APPLICATION_JSON
                content = """{"title":"Dossier","goal":""}"""
            }.andExpect { status { isEqualTo(HttpStatus.CREATED.value()) } }.andReturn().response.contentAsString,
        )
        val dossierId = dossier.path("id").asText()
        val article = objectMapper.readTree(
            mockMvc.post("/api/dossiers/$dossierId/articles") {
                auth(token); contentType = MediaType.APPLICATION_JSON
                content = """{"title":"De Kerklaan","contentMarkdown":"## Bewoners\n\nJansen woonde op [Kerklaan 12 in 1932](hkh:beeldbank/42)."}"""
            }.andExpect { status { isEqualTo(HttpStatus.CREATED.value()) } }.andReturn().response.contentAsString,
        )
        return dossierId to article.path("id").asText()
    }

    private fun seedCollectionItem() {
        jdbc.update(
            """
            INSERT INTO collection_item (collection, ident, title, description, detail_url, search_text)
            VALUES ('beeldbank', '42', 'Kerklaan 12 in 1932', 'Beschrijving', ?, 'Kerklaan 12 in 1932')
            ON CONFLICT (collection, ident) DO NOTHING
            """.trimIndent(),
            "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=42",
        )
    }

    private fun login(email: String): String {
        val body = mockMvc.post("/api/auth/google") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"idToken":"$email"}"""
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        return objectMapper.readTree(body).path("token").asText()
    }

    private fun MockHttpServletRequestDsl.auth(token: String) = header(HttpHeaders.AUTHORIZATION, "Bearer $token")

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
