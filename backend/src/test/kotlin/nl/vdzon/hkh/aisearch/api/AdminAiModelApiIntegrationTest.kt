package nl.vdzon.hkh.aisearch.api

import nl.vdzon.hkh.aisearch.AiModelSettings
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
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
import org.springframework.test.web.servlet.put
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** Het beheerscherm toont de catalogus van de runtime en kiest het model van de digitale onderzoeker. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance",
    "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh", "hkh.ai-search.fixture-enabled=true",
    "hkh.ai-search.vendor-id=anthropic", "hkh.ai-search.model=claude-sonnet-5-5", "hkh.ai-search.mode=SUBSCRIPTION"])
class AdminAiModelApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val settings: AiModelSettings,
) {
    @Test
    fun `an administrator sees the catalog, chooses a model and can return to the configuration`() {
        settings.reset()
        // Zonder preview-header en zonder geconfigureerde Google-login is beheer niet beschikbaar.
        mockMvc.get("/api/admin/ai-search/model").andExpect { status { isServiceUnavailable() } }

        mockMvc.get("/api/admin/ai-search/model") { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }
            .andExpect {
                status { isOk() }
                jsonPath("$.current.model") { value("claude-sonnet-5-5") }
                jsonPath("$.fromSetting") { value(false) }
                jsonPath("$.options[0].execution.model") { value("claude-sonnet-5-5") }
                jsonPath("$.options[0].available") { value(true) }
                jsonPath("$.catalogError") { value(null) }
            }

        // Alleen een model uit de catalogus mag gekozen worden.
        mockMvc.put("/api/admin/ai-search/model") {
            header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE)
            contentType = MediaType.APPLICATION_JSON
            content = """{"vendorId":"anthropic","model":"claude-opus-5","mode":"SUBSCRIPTION"}"""
        }.andExpect { status { isBadRequest() } }
        assertFalse(settings.current().fromSetting)

        mockMvc.put("/api/admin/ai-search/model") {
            header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE)
            contentType = MediaType.APPLICATION_JSON
            content = """{"vendorId":"anthropic","model":"claude-sonnet-5-5","mode":"subscription"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.fromSetting") { value(true) }
            jsonPath("$.current.mode") { value("SUBSCRIPTION") }
            jsonPath("$.updatedBy") { value(PreviewRuntimeConfig.ADMIN_EMAIL) }
        }
        assertTrue(settings.current().fromSetting)
        assertEquals("claude-sonnet-5-5", settings.execution().model)

        mockMvc.delete("/api/admin/ai-search/model") { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }
            .andExpect {
                status { isOk() }
                jsonPath("$.fromSetting") { value(false) }
            }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
