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
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

/** De workflow-app meldt elke wijziging van zijn instellingen zonder inlog; beheer leest ze terug. Elke test gebruikt een eigen bron. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class WorkflowSettingsChangeApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val mapper: ObjectMapper,
) {
    private val key = WorkflowLogIngestController.INGEST_KEY

    private fun change(field: String, old: String?, new: String?) = mapOf("field" to field, "old" to old, "new" to new)

    private fun body(
        source: String,
        changes: Any? = listOf(change("testFolder", "C:\\oud", "C:\\nieuw")),
        settings: Any? = mapOf("testFolder" to "C:\\nieuw", "sourceFolders" to "Ria=K:\\ria"),
        user: String? = "carla",
        extra: Map<String, Any?> = emptyMap(),
    ): String = mapper.writeValueAsString(buildMap {
        put("source", source); put("computer", "SERVER"); put("appVersion", "0.0.1+20261031.1405")
        put("reason", "Instellingen opgeslagen"); put("address", "10.0.0.5")
        user?.let { put("user", it) }
        changes?.let { put("changes", it) }
        settings?.let { put("settings", it) }
        putAll(extra)
    })

    private fun post(json: String, ip: String, withKey: Boolean = true) = mockMvc.post("/api/workflow-log/settings-changes") {
        contentType = MediaType.APPLICATION_JSON; content = json
        if (withKey) header(WorkflowLogIngestController.INGEST_KEY_HEADER, key)
        header("X-Forwarded-For", "6.6.6.6, $ip, 10.0.0.1")
    }

    private fun admin(path: String) = mockMvc.get(path) { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }

    private fun count(source: String) = jdbc.queryForObject("SELECT count(*) FROM workflow_settings_change WHERE source = ?", Int::class.java, source)!!

    @Test
    fun `een wijziging wordt bewaard en beheer leest lijst en detail terug`() {
        val source = "bron-${UUID.randomUUID()}"
        post(
            body(source, changes = listOf(change("testFolder", "C:\\oud", "C:\\nieuw"), change("collections.beeldbank.imagesResolution", null, "2"))),
            "203.0.113.20",
        ).andExpect { status { isNoContent() } }

        assertEquals(1, count(source))
        val list = admin("/api/admin/workflow-log/settings-changes?source=$source").andExpect {
            status { isOk() }
            jsonPath("$.length()") { value(1) }
            jsonPath("$[0].source") { value(source) }
            jsonPath("$[0].computer") { value("SERVER") }
            jsonPath("$[0].appVersion") { value("0.0.1+20261031.1405") }
            jsonPath("$[0].user") { value("carla") }
            jsonPath("$[0].address") { value("10.0.0.5") }
            jsonPath("$[0].reason") { value("Instellingen opgeslagen") }
            jsonPath("$[0].changeCount") { value(2) }
            jsonPath("$[0].changes[0].field") { value("testFolder") }
            jsonPath("$[0].changes[0].old") { value("C:\\oud") }
            jsonPath("$[0].changes[0].new") { value("C:\\nieuw") }
            jsonPath("$[0].changes[1].old") { value(null) }
            jsonPath("$[0].settings") { doesNotExist() }
        }.andReturn().response.contentAsString
        val id = mapper.readTree(list).get(0).path("id").asLong()

        admin("/api/admin/workflow-log/settings-changes/$id").andExpect {
            status { isOk() }
            jsonPath("$.id") { value(id) }
            jsonPath("$.changeCount") { value(2) }
            jsonPath("$.settings.testFolder") { value("C:\\nieuw") }
            jsonPath("$.settings.sourceFolders") { value("Ria=K:\\ria") }
        }
        admin("/api/admin/workflow-log/settings-changes/999999999").andExpect { status { isNotFound() } }
    }

    @Test
    fun `geheimen in de wijzigingen en in de instellingen worden vervangen, het ftp-wachtwoord blijft leesbaar zolang dat aan staat`() {
        val source = "bron-${UUID.randomUUID()}"
        post(
            body(
                source,
                changes = listOf(
                    change("adminPassword", "oud-admin-geheim", "nieuw-admin-geheim"),
                    change("ftpPassword", "oud-ftp", "nieuw-ftp"),
                    change("sourceFolders", "a=b", "login ftp://ZCBS:hunter2@host"),
                ),
                settings = mapOf("adminPassword" to "nieuw-admin-geheim", "ftpPassword" to "nieuw-ftp", "nested" to mapOf("apiKey" to "sleutel-123")),
            ),
            "203.0.113.21",
        ).andExpect { status { isNoContent() } }

        val text = admin("/api/admin/workflow-log/settings-changes?source=$source").andExpect { status { isOk() } }.andReturn().response.contentAsString
        val id = mapper.readTree(text).get(0).path("id").asLong()
        val detail = admin("/api/admin/workflow-log/settings-changes/$id").andReturn().response.contentAsString
        for (output in listOf(text, detail)) {
            assertTrue("oud-admin-geheim" !in output && "nieuw-admin-geheim" !in output && "hunter2" !in output && "sleutel-123" !in output, output)
        }
        assertTrue("ftp://ZCBS:***@host" in text, text)
        assertTrue("nieuw-ftp" in detail && "oud-ftp" in text, "het ftp-wachtwoord blijft leesbaar bij keep-ftp-password: $text")
        assertEquals(WorkflowLogSanitizer.REDACTED, mapper.readTree(detail).path("settings").path("adminPassword").asString())
    }

    @Test
    fun `zonder sleutel of met een ongeldig bericht wordt er niets bewaard`() {
        val source = "bron-${UUID.randomUUID()}"
        // Elk verzoek telt mee voor de limiet per adres, ook een ongeldig: elk een eigen adres.
        var n = 0
        fun ip() = "192.0.2.${100 + n++}"
        post(body(source), ip(), withKey = false).andExpect { status { isUnauthorized() } }
        post("geen json", ip()).andExpect { status { isBadRequest() } }
        post(body(source, extra = mapOf("source" to null)), ip()).andExpect { status { isBadRequest() } }
        post(body(source, extra = mapOf("computer" to " ")), ip()).andExpect { status { isBadRequest() } }
        post(body(source, extra = mapOf("reason" to null)), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = null), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = emptyList<Any>()), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = "geen lijst"), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = listOf("geen object")), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = listOf(mapOf("old" to "a", "new" to "b"))), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = listOf(mapOf("field" to "x", "old" to 1, "new" to "b"))), ip()).andExpect { status { isBadRequest() } }
        post(body(source, changes = List(IngestLimits.MAX_SETTING_CHANGES + 1) { change("veld$it", "a", "b") }), ip()).andExpect { status { isBadRequest() } }
        post(body(source, settings = null), ip()).andExpect { status { isBadRequest() } }
        post(body(source, settings = "geen object"), ip()).andExpect { status { isBadRequest() } }
        assertEquals(0, count(source))
    }

    @Test
    fun `lange waarden worden afgekapt en een wijziging zonder gebruiker mag`() {
        val source = "bron-${UUID.randomUUID()}"
        post(body(source, user = null, changes = listOf(change("sourceFolders", "x".repeat(5000), "y"))), "203.0.113.23").andExpect { status { isNoContent() } }
        val item = mapper.readTree(admin("/api/admin/workflow-log/settings-changes?source=$source").andReturn().response.contentAsString).get(0)
        assertEquals(2000, item.path("changes").get(0).path("old").asString().length)
        assertTrue(item.path("user").isNull)
    }

    @Test
    fun `de lijst is nieuwste eerst, kent een limiet en het bronfilter, en de bron staat in de lijst met bronnen`() {
        val source = "bron-${UUID.randomUUID()}"
        val other = "bron-${UUID.randomUUID()}"
        post(body(source, changes = listOf(change("a", "1", "2"))), "203.0.113.24").andExpect { status { isNoContent() } }
        post(body(source, changes = listOf(change("b", "1", "2"))), "203.0.113.24").andExpect { status { isNoContent() } }
        post(body(other, changes = listOf(change("c", "1", "2"))), "203.0.113.24").andExpect { status { isNoContent() } }

        admin("/api/admin/workflow-log/settings-changes?source=$source").andExpect {
            jsonPath("$.length()") { value(2) }
            jsonPath("$[0].changes[0].field") { value("b") }
            jsonPath("$[1].changes[0].field") { value("a") }
        }
        admin("/api/admin/workflow-log/settings-changes?source=$source&limit=1").andExpect { jsonPath("$.length()") { value(1) } }
        admin("/api/admin/workflow-log/settings-changes?source=$other").andExpect { jsonPath("$.length()") { value(1) } }
        admin("/api/admin/workflow-log/sources").andExpect { jsonPath("$") { value(org.hamcrest.Matchers.hasItem(source)) } }
    }

    @Test
    fun `een adres dat te veel meldingen stuurt krijgt 429 met Retry-After`() {
        val ip = "198.51.100.95"
        val source = "bron-${UUID.randomUUID()}"
        repeat(IngestLimits.SETTINGS_CHANGES_PER_IP_BURST) { post(body(source), ip).andExpect { status { isNoContent() } } }
        post(body(source), ip).andExpect { status { isTooManyRequests() }; header { string("Retry-After", "60") } }
        post(body(source), "198.51.100.96").andExpect { status { isNoContent() } }
    }

    @Test
    fun `beheer vraagt een inlog`() {
        mockMvc.get("/api/admin/workflow-log/settings-changes").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/workflow-log/settings-changes/1").andExpect { status { isServiceUnavailable() } }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
