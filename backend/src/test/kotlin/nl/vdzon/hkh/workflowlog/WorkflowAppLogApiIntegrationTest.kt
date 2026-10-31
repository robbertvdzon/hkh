package nl.vdzon.hkh.workflowlog

import java.time.Duration
import java.time.Instant
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

/** De workflow-app meldt zijn logregels zonder inlog; beheer leest ze terug. Elke test gebruikt een eigen bron, zodat de tests elkaar niet storen. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class WorkflowAppLogApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val service: WorkflowAppLogService,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val mapper: ObjectMapper,
) {
    private val key = WorkflowLogIngestController.INGEST_KEY

    private fun line(time: Instant, level: String = "INFO", message: String = "gestart", logger: String = "nl.vdzon.hkhworkflow.Main") =
        mapOf("time" to time.toString(), "level" to level, "logger" to logger, "message" to message)

    private fun chunk(source: String, lines: List<Map<String, String>>, chunkId: String = UUID.randomUUID().toString(), version: String? = "0.0.1+20261031.1405", computer: String = "SERVER") =
        mapper.writeValueAsString(buildMap {
            put("source", source); put("computer", computer); put("chunkId", chunkId); put("lines", lines)
            version?.let { put("appVersion", it) }
        })

    private fun post(json: String, ip: String, withKey: Boolean = true) = mockMvc.post("/api/workflow-log/app-logs") {
        contentType = MediaType.APPLICATION_JSON; content = json
        if (withKey) header(WorkflowLogIngestController.INGEST_KEY_HEADER, key)
        header("X-Forwarded-For", "6.6.6.6, $ip, 10.0.0.1")
    }

    private fun admin(path: String) = mockMvc.get(path) { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }

    private fun count(source: String) = jdbc.queryForObject("SELECT count(*) FROM workflow_app_log WHERE source = ?", Int::class.java, source)!!

    @Test
    fun `een pakketje wordt bewaard, geheimen worden gemaskeerd en beheer leest het terug`() {
        val source = "bron-${UUID.randomUUID()}"
        val now = Instant.now()
        post(
            chunk(source, listOf(
                line(now.minusSeconds(30), message = "Inloggen bij ZCBS gelukt"),
                line(now.minusSeconds(20), "WARN", "Map K:\\scans ria niet gevonden"),
                line(now.minusSeconds(10), "ERROR", "FTP mislukt: password=hunter2 voor ftp://ZCBS:geheim123@host\n\tat nl.vdzon.Foo.bar(Foo.kt:12)"),
            )),
            "203.0.113.10",
        ).andExpect { status { isNoContent() } }

        assertEquals(3, count(source))
        val body = admin("/api/admin/workflow-log/app-logs?source=$source").andExpect {
            status { isOk() }
            jsonPath("$.items.length()") { value(3) }
            jsonPath("$.items[0].level") { value("ERROR") }
            jsonPath("$.items[0].appVersion") { value("0.0.1+20261031.1405") }
            jsonPath("$.items[0].computer") { value("SERVER") }
            jsonPath("$.next") { doesNotExist() }
        }.andReturn().response.contentAsString
        assertTrue("hunter2" !in body && "geheim123" !in body, body)
        assertTrue("password=***" in body && "Foo.kt:12" in body, body)
    }

    @Test
    fun `zonder sleutel of met een ongeldig bericht wordt er niets bewaard`() {
        val source = "bron-${UUID.randomUUID()}"
        val ok = line(Instant.now())
        post(chunk(source, listOf(ok)), "203.0.113.11", withKey = false).andExpect { status { isUnauthorized() } }
        post("geen json", "203.0.113.11").andExpect { status { isBadRequest() } }
        post(chunk(source, listOf(ok + ("level" to "DEBUG"))), "203.0.113.11").andExpect { status { isBadRequest() } }
        post(chunk(source, listOf(ok + ("time" to "gisteren"))), "203.0.113.11").andExpect { status { isBadRequest() } }
        post("""{"source":"$source","computer":"S","chunkId":"x","lines":"geen lijst"}""", "203.0.113.11").andExpect { status { isBadRequest() } }
        post("""{"source":"$source","computer":"S","lines":[]}""", "203.0.113.11").andExpect { status { isBadRequest() } }
        post("""{"computer":"S","chunkId":"x","lines":[]}""", "203.0.113.11").andExpect { status { isBadRequest() } }
        post(chunk(source, List(IngestLimits.MAX_APP_LOG_LINES + 1) { ok }), "203.0.113.11").andExpect { status { isBadRequest() } }
        assertEquals(0, count(source))
        // Een pakketje zonder regels is geen fout, maar er wordt niets bewaard.
        post(chunk(source, emptyList()), "203.0.113.11").andExpect { status { isNoContent() } }
        assertEquals(0, count(source))
    }

    @Test
    fun `een pakketje met hetzelfde chunkId wordt niet nog eens bewaard`() {
        val source = "bron-${UUID.randomUUID()}"
        val json = chunk(source, listOf(line(Instant.now()), line(Instant.now().minusSeconds(1))), chunkId = "bestand-1#0")
        post(json, "203.0.113.12").andExpect { status { isNoContent() } }
        post(json, "203.0.113.12").andExpect { status { isNoContent() } }
        assertEquals(2, count(source))
        // Op een andere computer is hetzelfde chunkId een ander pakketje.
        post(chunk(source, listOf(line(Instant.now())), chunkId = "bestand-1#0", computer = "ANDERE-PC"), "203.0.113.12").andExpect { status { isNoContent() } }
        assertEquals(3, count(source))
    }

    @Test
    fun `een adres dat te veel pakketjes stuurt krijgt 429 met Retry-After`() {
        val ip = "198.51.100.90"
        val source = "bron-${UUID.randomUUID()}"
        repeat(IngestLimits.APP_LOGS_PER_IP_BURST) { post(chunk(source, listOf(line(Instant.now()))), ip).andExpect { status { isNoContent() } } }
        post(chunk(source, listOf(line(Instant.now()))), ip).andExpect { status { isTooManyRequests() }; header { string("Retry-After", "60") } }
        post(chunk(source, listOf(line(Instant.now()))), "198.51.100.91").andExpect { status { isNoContent() } }
    }

    @Test
    fun `regels van te lang geleden of uit de toekomst worden weggegooid`() {
        val source = "bron-${UUID.randomUUID()}"
        val now = Instant.now()
        post(
            chunk(source, listOf(
                line(now.minus(Duration.ofDays(40)), message = "te oud"),
                line(now.plus(Duration.ofDays(3)), message = "toekomst"),
                line(now.minusSeconds(5), message = "goed"),
            )),
            "203.0.113.13",
        ).andExpect { status { isNoContent() } }
        assertEquals(1, count(source))
    }

    @Test
    fun `filters op niveau, versie en tekst en het bladeren met de cursor`() {
        val source = "bron-${UUID.randomUUID()}"
        val now = Instant.now()
        post(chunk(source, listOf(
            line(now.minusSeconds(50), "INFO", "eerste_regel 100% klaar", "nl.vdzon.A"),
            line(now.minusSeconds(40), "WARN", "tweede regel", "nl.vdzon.B"),
            line(now.minusSeconds(30), "ERROR", "derde regel", "nl.vdzon.C"),
        ), version = "1.0"), "203.0.113.14").andExpect { status { isNoContent() } }
        post(chunk(source, listOf(line(now.minusSeconds(20), "INFO", "vierde regel", "nl.vdzon.D"), line(now.minusSeconds(10), "WARN", "vijfde regel")), version = "2.0", computer = "ANDERE"), "203.0.113.14")
            .andExpect { status { isNoContent() } }
        val base = "/api/admin/workflow-log/app-logs?source=$source"

        admin("$base&level=WARN").andExpect { jsonPath("$.items.length()") { value(3) } }
        admin("$base&level=ERROR").andExpect { jsonPath("$.items.length()") { value(1) }; jsonPath("$.items[0].message") { value("derde regel") } }
        admin("$base&version=1.0").andExpect { jsonPath("$.items.length()") { value(3) } }
        admin("$base&computer=ANDERE").andExpect { jsonPath("$.items.length()") { value(2) } }
        admin("$base&q=NL.VDZON.b").andExpect { jsonPath("$.items.length()") { value(1) }; jsonPath("$.items[0].message") { value("tweede regel") } }
        // % en _ in de zoektekst zijn gewone tekens.
        admin("$base&q=100%").andExpect { jsonPath("$.items.length()") { value(1) } }
        admin("$base&q=%").andExpect { jsonPath("$.items.length()") { value(1) } }
        admin("$base&q=eerste_regel").andExpect { jsonPath("$.items.length()") { value(1) } }
        admin("$base&q=eerste-regel").andExpect { jsonPath("$.items.length()") { value(0) } }

        // Bladeren: twee per pagina, nieuwste eerst.
        val first = admin("$base&limit=2").andExpect { jsonPath("$.items.length()") { value(2) }; jsonPath("$.items[0].message") { value("vijfde regel") } }
            .andReturn().response.contentAsString
        val cursor = mapper.readTree(first).path("next").asString("")
        assertTrue(cursor.isNotEmpty())
        val second = admin("$base&limit=2&before=$cursor").andExpect { jsonPath("$.items.length()") { value(2) }; jsonPath("$.items[0].message") { value("derde regel") } }
            .andReturn().response.contentAsString
        val cursor2 = mapper.readTree(second).path("next").asString("")
        admin("$base&limit=2&before=$cursor2").andExpect { jsonPath("$.items.length()") { value(1) }; jsonPath("$.items[0].message") { value("eerste_regel 100% klaar") }; jsonPath("$.next") { doesNotExist() } }
        admin("$base&before=geen-cursor").andExpect { status { isBadRequest() } }
    }

    @Test
    fun `het overzicht toont per computer de versie van de nieuwste regel en de aantallen van de laatste 24 uur`() {
        val source = "bron-${UUID.randomUUID()}"
        val now = Instant.now()
        post(chunk(source, listOf(line(now.minusSeconds(100), "INFO"), line(now.minusSeconds(90), "WARN"), line(now.minus(Duration.ofHours(30)), "ERROR", "oude fout")), version = "$source-1.0"), "203.0.113.15")
            .andExpect { status { isNoContent() } }
        post(chunk(source, listOf(line(now.minusSeconds(10), "ERROR", "nieuwe fout")), version = "$source-1.1"), "203.0.113.15").andExpect { status { isNoContent() } }

        val rows = mapper.readTree(admin("/api/admin/workflow-log/app-logs/overview").andExpect { status { isOk() } }.andReturn().response.contentAsString)
        val row = rows.first { it.path("source").asString("") == source }
        assertEquals("SERVER", row.path("computer").asString(""))
        assertEquals("$source-1.1", row.path("appVersion").asString(""))
        assertEquals(3, row.path("lines24h").asInt())
        assertEquals(1, row.path("warnings24h").asInt())
        assertEquals(1, row.path("errors24h").asInt())
        assertTrue(Instant.parse(row.path("lastSeen").asString("")).isAfter(now.minusSeconds(60)))

        val versions = mapper.readTree(admin("/api/admin/workflow-log/app-logs/versions").andExpect { status { isOk() } }.andReturn().response.contentAsString)
        val names = (0 until versions.size()).map { versions.get(it).asString("") }
        assertTrue(names.indexOf("$source-1.1") in 0 until names.indexOf("$source-1.0"), names.toString())
        // De bron komt ook in de lijst voor het bronfilter.
        admin("/api/admin/workflow-log/sources").andExpect { jsonPath("$") { value(org.hamcrest.Matchers.hasItem(source)) } }
    }

    @Test
    fun `beheer vraagt een inlog`() {
        mockMvc.get("/api/admin/workflow-log/app-logs").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/workflow-log/app-logs/overview").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/workflow-log/app-logs/versions").andExpect { status { isServiceUnavailable() } }
    }

    @Test
    fun `de opruiming verwijdert regels en pakketnamen ouder dan de bewaartermijn`() {
        val source = "bron-${UUID.randomUUID()}"
        val now = Instant.now()
        val chunk = AppLogChunk(source, "SERVER", "retentie", "oud-1", listOf(AppLogLine(now.minusSeconds(60), "INFO", "x", "oude regel")))
        assertEquals(1, service.record(chunk, now))
        assertEquals(0, service.record(chunk, now))
        // Dertig dagen en een uur later is alles over de termijn; een regel van "nu" blijft.
        service.record(AppLogChunk(source, "SERVER", "retentie", "nieuw-1", listOf(AppLogLine(now.plus(Duration.ofDays(30)), "INFO", "x", "nieuwe regel"))), now.plus(Duration.ofDays(30)))
        val deleted = service.deleteExpired(now.plus(Duration.ofDays(30)).plus(Duration.ofHours(1)))
        assertTrue(deleted >= 1)
        assertEquals(listOf("nieuwe regel"), service.entries(source = source).items.map { it.message })
        // De pakketnaam van het oude pakketje is ook weg: nu wordt het weer geaccepteerd.
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM workflow_app_log_chunk WHERE source = ?", Int::class.java, source))
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
