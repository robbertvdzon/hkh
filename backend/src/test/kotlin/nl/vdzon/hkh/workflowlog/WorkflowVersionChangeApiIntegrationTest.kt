package nl.vdzon.hkh.workflowlog

import java.util.UUID
import kotlin.test.assertEquals
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.workflowlog.api.WorkflowLogIngestController
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

/** De workflow-app meldt zonder inlog dat hij met een andere versie draait; beheer leest de versiewissels terug. Elke test gebruikt een eigen bron. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class WorkflowVersionChangeApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val mapper: ObjectMapper,
) {
    private fun body(source: String, previous: String? = "build 18 (0.0.1+20261124.1000)", current: String? = "build 19 (0.0.1+20261125.0900)"): String =
        mapper.writeValueAsString(buildMap {
            put("source", source); put("computer", "SERVER"); put("reason", "Nieuwe versie geïnstalleerd")
            previous?.let { put("previous", it) }
            current?.let { put("current", it) }
        })

    private fun post(json: String, ip: String, withKey: Boolean = true) = mockMvc.post("/api/workflow-log/version-changes") {
        contentType = MediaType.APPLICATION_JSON; content = json
        if (withKey) header(WorkflowLogIngestController.INGEST_KEY_HEADER, WorkflowLogIngestController.INGEST_KEY)
        header("X-Forwarded-For", "6.6.6.6, $ip, 10.0.0.1")
    }

    private fun admin(path: String) = mockMvc.get(path) { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }

    private fun count(source: String) = jdbc.queryForObject("SELECT count(*) FROM workflow_version_change WHERE source = ?", Int::class.java, source)!!

    @Test
    fun `een versiewissel wordt bewaard en beheer leest hem terug, nieuwste eerst`() {
        val source = "bron-${UUID.randomUUID()}"
        post(body(source), "203.0.113.40").andExpect { status { isNoContent() } }
        post(body(source, previous = "build 19 (0.0.1+20261125.0900)", current = "build 20 (0.0.1+20261126.0900)"), "203.0.113.40").andExpect { status { isNoContent() } }

        assertEquals(2, count(source))
        admin("/api/admin/workflow-log/version-changes?source=$source").andExpect {
            status { isOk() }
            jsonPath("$.length()") { value(2) }
            jsonPath("$[0].current") { value("build 20 (0.0.1+20261126.0900)") }
            jsonPath("$[0].previous") { value("build 19 (0.0.1+20261125.0900)") }
            jsonPath("$[1].current") { value("build 19 (0.0.1+20261125.0900)") }
            jsonPath("$[1].source") { value(source) }
            jsonPath("$[1].computer") { value("SERVER") }
            jsonPath("$[1].reason") { value("Nieuwe versie geïnstalleerd") }
            jsonPath("$[1].createdAt") { exists() }
        }
        admin("/api/admin/workflow-log/sources").andExpect { jsonPath("$") { value(org.hamcrest.Matchers.hasItem(source)) } }
    }

    @Test
    fun `zonder sleutel of met een onvolledig bericht wordt niets bewaard`() {
        val source = "bron-${UUID.randomUUID()}"
        post(body(source), "203.0.113.41", withKey = false).andExpect { status { isUnauthorized() } }
        post(body(source, previous = null), "203.0.113.41").andExpect { status { isBadRequest() } }
        post(body(source, current = null), "203.0.113.41").andExpect { status { isBadRequest() } }
        post("geen json", "203.0.113.41").andExpect { status { isBadRequest() } }
        assertEquals(0, count(source))
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
