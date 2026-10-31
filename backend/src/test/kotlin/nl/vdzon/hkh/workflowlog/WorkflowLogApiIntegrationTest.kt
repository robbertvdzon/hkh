package nl.vdzon.hkh.workflowlog

import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.workflowlog.api.WorkflowLogIngestController
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
import org.springframework.test.web.servlet.put
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** De workflow-app meldt zonder inlog; beheer leest de sessies en inlogpogingen terug. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class WorkflowLogApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val service: WorkflowLogService,
    @param:Autowired private val jdbc: org.springframework.jdbc.core.JdbcTemplate,
) {
    private val key = WorkflowLogIngestController.INGEST_KEY
    private val secret = "geheim-van-de-sessie-0123456789"

    private fun body(status: String = "RUNNING", phase: Int = 2, event: String? = null, secret: String = this.secret, extra: String = "") =
        """{"kind":"NEW_FILES","secret":"$secret","user":"carla","collection":"archief","appVersion":"1.2.3","computer":"PC-CARLA",
            "phase":$phase,"phaseCount":7,"phaseLabel":"Bestanden kiezen","status":"$status","fileCount":12,
            ${event?.let { """"event":"$it",""" } ?: ""}
            "snapshot":{"settings":{"ftpHost":"ftp.example.org","ftpPassword":"nooit-zichtbaar"},"bestanden":["a.pdf","b.pdf"],"consoles":{"images":"regel 1\nregel 2"}}$extra}"""

    private fun put(id: UUID, json: String, withKey: Boolean = true, ip: String = "203.0.113.50") =
        mockMvc.put("/api/workflow-log/sessions/$id") {
            contentType = MediaType.APPLICATION_JSON; content = json
            if (withKey) header(WorkflowLogIngestController.INGEST_KEY_HEADER, key)
            header("X-Forwarded-For", "6.6.6.6, $ip, 10.0.0.1")
        }

    private fun admin(path: String) = mockMvc.get(path) { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }

    @Test
    fun `een sessie wordt bij elke stap vervangen, krijgt een tijdlijn en toont geen geheimen`() {
        val id = UUID.randomUUID()
        put(id, body()).andExpect { status { isNoContent() } }
        put(id, body(phase = 5, event = "images.exe gestart")).andExpect { status { isNoContent() } }
        put(id, body(status = "FINISHED", phase = 8)).andExpect { status { isNoContent() } }

        mockMvc.get("/api/admin/workflow-log/sessions?kind=NEW_FILES").andExpect { status { isServiceUnavailable() } }
        admin("/api/admin/workflow-log/sessions?kind=NEW_FILES").andExpect {
            status { isOk() }
            jsonPath("$[?(@.id == '$id')].user") { value("carla") }
            jsonPath("$[?(@.id == '$id')].status") { value("FINISHED") }
            jsonPath("$[?(@.id == '$id')].phase") { value(8) }
            jsonPath("$[?(@.id == '$id')].fileCount") { value(12) }
            jsonPath("$[?(@.id == '$id')].updates") { value(3) }
        }
        val detail = admin("/api/admin/workflow-log/sessions/$id").andExpect { status { isOk() } }.andReturn().response.contentAsString
        assertTrue("regel 1" in detail && "ftp.example.org" in detail, detail)
        assertTrue("nooit-zichtbaar" !in detail, detail)
        val events = service.session(id)!!.events
        assertEquals(listOf("Sessie gestart", "images.exe gestart", "Klaar"), events.map { it.message })
        // Een geldige sessie kan met een andere kind-lijst niet worden opgevraagd.
        admin("/api/admin/workflow-log/sessions?kind=EDIT").andExpect { jsonPath("$[?(@.id == '$id')]") { isEmpty() } }
    }

    @Test
    fun `zonder sleutel, met een verkeerd geheim of een ongeldig bericht wordt er niets bewaard`() {
        val id = UUID.randomUUID()
        put(id, body(), withKey = false).andExpect { status { isUnauthorized() } }
        put(id, "geen json").andExpect { status { isBadRequest() } }
        put(id, body().replace("NEW_FILES", "ANDERS")).andExpect { status { isBadRequest() } }
        put(id, body(secret = "kort")).andExpect { status { isBadRequest() } }
        mockMvc.put("/api/workflow-log/sessions/niet-een-uuid") {
            contentType = MediaType.APPLICATION_JSON; content = body(); header(WorkflowLogIngestController.INGEST_KEY_HEADER, key)
        }.andExpect { status { isBadRequest() } }
        assertEquals(false, service.sessionExists(id))

        put(id, body()).andExpect { status { isNoContent() } }
        // Wie het sessiegeheim niet kent, kan de sessie niet overschrijven.
        put(id, body(secret = "ander-geheim-0123456789abcdef", phase = 7)).andExpect { status { isForbidden() } }
        assertEquals(2, service.session(id)!!.summary.phase)
    }

    @Test
    fun `een te groot bericht wordt geweigerd`() {
        val id = UUID.randomUUID()
        val big = "x".repeat(IngestLimits.MAX_BODY_BYTES)
        put(id, body(extra = ""","grootte":"$big"""")).andExpect { status { isBadRequest() } }
        assertEquals(false, service.sessionExists(id))
    }

    @Test
    fun `een adres dat te veel nieuwe sessies maakt krijgt 429 met Retry-After`() {
        val ip = "198.51.100.77"
        repeat(IngestLimits.NEW_SESSIONS_PER_IP_PER_HOUR) { put(UUID.randomUUID(), body(), ip = ip).andExpect { status { isNoContent() } } }
        put(UUID.randomUUID(), body(), ip = ip).andExpect { status { isTooManyRequests() }; header { string("Retry-After", "60") } }
        // Een ander adres heeft er geen last van.
        put(UUID.randomUUID(), body(), ip = "198.51.100.78").andExpect { status { isNoContent() } }
    }

    @Test
    fun `een sessie die lang stil ligt zonder af te ronden geldt als verlaten`() {
        val id = UUID.randomUUID()
        put(id, body(), ip = "192.0.2.10").andExpect { status { isNoContent() } }
        jdbc.update("UPDATE workflow_session SET updated_at = CURRENT_TIMESTAMP - interval '2 hours' WHERE id = ?", id)
        assertEquals("ABANDONED", service.session(id)!!.summary.status)
        jdbc.update("UPDATE workflow_session SET status = 'FINISHED' WHERE id = ?", id)
        assertEquals("FINISHED", service.session(id)!!.summary.status)
    }

    @Test
    fun `de bron van een melding wordt bewaard en daarop is te filteren`() {
        val mac = UUID.randomUUID()
        val win = UUID.randomUUID()
        put(mac, body().replace(""""kind":"NEW_FILES",""", """"kind":"NEW_FILES","source":"macbook","""), ip = "192.0.2.31").andExpect { status { isNoContent() } }
        put(win, body().replace(""""kind":"NEW_FILES",""", """"kind":"NEW_FILES","source":"windows-laptop","""), ip = "192.0.2.32").andExpect { status { isNoContent() } }
        mockMvc.post("/api/workflow-log/logins") {
            contentType = MediaType.APPLICATION_JSON; content = """{"user":"bron-gebruiker","success":true,"method":"PASSWORD","source":"windows-laptop"}"""
            header(WorkflowLogIngestController.INGEST_KEY_HEADER, key); header("X-Forwarded-For", "192.0.2.33, 10.0.0.1")
        }.andExpect { status { isNoContent() } }

        admin("/api/admin/workflow-log/sources").andExpect { status { isOk() }; jsonPath("$") { value(org.hamcrest.Matchers.hasItems("macbook", "windows-laptop")) } }
        admin("/api/admin/workflow-log/sessions?kind=NEW_FILES&source=macbook").andExpect {
            status { isOk() }
            jsonPath("$[?(@.id == '$mac')].source") { value("macbook") }
            jsonPath("$[?(@.id == '$win')]") { isEmpty() }
        }
        admin("/api/admin/workflow-log/sessions?kind=NEW_FILES&source=windows-laptop").andExpect {
            jsonPath("$[?(@.id == '$win')].source") { value("windows-laptop") }
            jsonPath("$[?(@.id == '$mac')]") { isEmpty() }
        }
        admin("/api/admin/workflow-log/logins?source=windows-laptop").andExpect { jsonPath("$[0].source") { value("windows-laptop") } }
        admin("/api/admin/workflow-log/logins?source=macbook").andExpect { jsonPath("$[?(@.source != 'macbook')]") { isEmpty() } }
        // Zonder filter komen ze allemaal.
        admin("/api/admin/workflow-log/sessions?kind=NEW_FILES&limit=500").andExpect { jsonPath("$[?(@.id == '$mac')]") { isNotEmpty() } }
    }

    @Test
    fun `inlogpogingen worden vastgelegd, ook mislukte, en nooit met een wachtwoord`() {
        fun login(json: String, ip: String) = mockMvc.post("/api/workflow-log/logins") {
            contentType = MediaType.APPLICATION_JSON; content = json
            header(WorkflowLogIngestController.INGEST_KEY_HEADER, key); header("X-Forwarded-For", "$ip, 10.0.0.1")
        }
        login("""{"user":"carla","success":true,"method":"PASSWORD","appVersion":"1.2.3","computer":"PC-CARLA"}""", "192.0.2.20").andExpect { status { isNoContent() } }
        login("""{"user":"onbekend","success":false,"method":"PASSWORD","detail":"Wachtwoord klopt niet","password":"x"}""", "192.0.2.21").andExpect { status { isNoContent() } }
        login("""{"user":"x","success":true,"method":"IETS"}""", "192.0.2.22").andExpect { status { isBadRequest() } }
        admin("/api/admin/workflow-log/logins?limit=50").andExpect {
            status { isOk() }
            jsonPath("$[?(@.user == 'carla')].success") { value(true) }
            jsonPath("$[?(@.user == 'onbekend')].success") { value(false) }
            jsonPath("$[?(@.user == 'onbekend')].detail") { value("Wachtwoord klopt niet") }
        }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
