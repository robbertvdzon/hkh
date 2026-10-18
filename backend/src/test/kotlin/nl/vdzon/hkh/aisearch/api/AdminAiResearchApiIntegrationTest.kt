package nl.vdzon.hkh.aisearch.api

import kotlin.test.assertEquals
import nl.vdzon.hkh.aisearch.AiBenchmarkRepository
import nl.vdzon.hkh.aisearch.AiBenchmarkService
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** De testset wordt beheerd en gedraaid vanuit het beheerscherm; de beurten komen in het vergelijkingsoverzicht. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance",
    "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh", "hkh.ai-search.fixture-enabled=true"])
class AdminAiResearchApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val questions: AiBenchmarkRepository,
    @param:Autowired private val runner: AiBenchmarkService,
) {
    private val admin = PreviewRuntimeConfig.ADMIN_HEADER to PreviewRuntimeConfig.ADMIN_HEADER_VALUE

    @Test
    fun `an administrator manages the test set, runs it and compares the resulting turns`() {
        questions.list().forEach { questions.delete(it.id) }
        mockMvc.get("/api/admin/ai-search/benchmark").andExpect { status { isServiceUnavailable() } }
        mockMvc.post("/api/admin/ai-search/benchmark/run") { header(admin.first, admin.second) }
            .andExpect { status { isBadRequest() } }

        mockMvc.post("/api/admin/ai-search/benchmark") {
            header(admin.first, admin.second)
            contentType = MediaType.APPLICATION_JSON
            content = """{"question":"Wie waren Toos en Ciska Oostrum?","depth":"extended"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.questions.length()") { value(1) }
            jsonPath("$.questions[0].depth") { value("EXTENDED") }
            jsonPath("$.questions[0].createdBy") { value(PreviewRuntimeConfig.ADMIN_EMAIL) }
            jsonPath("$.running") { value(false) }
        }
        val questionId = questions.list().single().id

        mockMvc.post("/api/admin/ai-search/benchmark/run") { header(admin.first, admin.second) }
            .andExpect { status { isOk() } }
        // De run stelt de vragen op de achtergrond; met de synthetische runtime is een beurt direct klaar.
        val deadline = System.currentTimeMillis() + 30_000
        while (runner.isRunning() && System.currentTimeMillis() < deadline) Thread.sleep(200)
        assertEquals(false, runner.isRunning())

        mockMvc.get("/api/admin/ai-search/turns?benchmarkOnly=true") { header(admin.first, admin.second) }
            .andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].question") { value("Wie waren Toos en Ciska Oostrum?") }
                jsonPath("$[0].benchmarkQuestionId") { value(questionId) }
                jsonPath("$[0].method") { value("AGENT") }
                jsonPath("$[0].depth") { value("EXTENDED") }
                jsonPath("$[0].status") { value("SUCCEEDED") }
                jsonPath("$[0].askedBy") { value("testset:${PreviewRuntimeConfig.ADMIN_EMAIL}") }
                jsonPath("$[0].jobs") { value(1) }
                jsonPath("$[0].models[0]") { value("anthropic/claude-sonnet-5-5") }
            }
        mockMvc.get("/api/admin/ai-search/turns?limit=5") { header(admin.first, admin.second) }
            .andExpect { status { isOk() } }

        mockMvc.delete("/api/admin/ai-search/benchmark/$questionId") { header(admin.first, admin.second) }
            .andExpect {
                status { isOk() }
                jsonPath("$.questions.length()") { value(0) }
            }
        mockMvc.delete("/api/admin/ai-search/benchmark/$questionId") { header(admin.first, admin.second) }
            .andExpect { status { isNotFound() } }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
