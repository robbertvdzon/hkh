package nl.vdzon.hkh.previewdata.api

import kotlin.test.assertEquals
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(
    properties = [
        "hkh.preview.enabled=true",
        "hkh.preview.marker=hkh-pr-preview",
        "hkh.preview.pr-number=314",
        "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh",
    ],
)
class PreviewDataApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val jdbcTemplate: JdbcTemplate,
) {
    @Test
    fun `startup creates deterministic data and ensure remains idempotent`() {
        mockMvc.get("/api/news").andExpect {
            status { isOk() }
            jsonPath("$.length()") { value(5) }
            jsonPath("$[0].id") { value(-1) }
            jsonPath("$[0].title") { value("Nieuwe foto's van de Kerkweg beschreven") }
            jsonPath("$[4].id") { value(-5) }
        }

        jdbcTemplate.update(
            "INSERT INTO latest_news (title, message, created_by) VALUES (?, ?, ?)",
            "Handmatig previewbericht",
            "Dit record moet behouden blijven.",
            "tester@example.com",
        )

        mockMvc.post("/api/admin/preview/test-data/ensure")
            .andExpect { status { isServiceUnavailable() } }

        mockMvc.post("/api/admin/preview/test-data/ensure") {
            header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE)
        }.andExpect {
            status { isOk() }
            jsonPath("$.applied.length()") { value(0) }
            jsonPath("$.alreadyPresent[0]") { value("latest-news-v1") }
        }

        assertEquals(6L, jdbcTemplate.queryForObject("SELECT COUNT(*) FROM latest_news", Long::class.java))
        assertEquals(1L, jdbcTemplate.queryForObject("SELECT COUNT(*) FROM preview_seed_history", Long::class.java))
        assertEquals(314, jdbcTemplate.queryForObject("SELECT pr_number FROM preview_seed_history", Int::class.java))
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
