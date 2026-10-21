package nl.vdzon.hkh.requestlog

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.ScrapedRecord
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** Elke zoekopdracht en AI-vraag komt met adres, gebruiker en tijden in het logboek; beheer leest het nieuwste eerst. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = ["hkh.preview.enabled=true", "hkh.preview.marker=hkh-acceptance", "HKH_DATABASE_URL=jdbc:postgresql://database:5432/hkh"])
class RequestLogApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val items: CollectionItemStore,
    @param:Autowired private val log: RequestLogService,
    @param:Autowired private val jdbc: org.springframework.jdbc.core.JdbcTemplate,
) {
    @Test
    fun `a collection search is logged with the forwarded address and the admin reads the log`() {
        items.upsert(ScrapedRecord("beeldbank", "rl-1", "Kerklaan 13a", "De dames Oostrum voor hun huis.", 1952, null, null, "https://example.org/rl-1", emptyMap()))
        mockMvc.get("/api/collections/search?q=Oostrum&collection=beeldbank") { header("X-Forwarded-For", "203.0.113.7, 10.0.0.1") }
            .andExpect { status { isOk() } }
        // Bladeren naar een volgende pagina hoort niet in het logboek.
        mockMvc.get("/api/collections/search?q=Oostrum&page=1").andExpect { status { isOk() } }

        mockMvc.get("/api/admin/requests").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/requests?limit=5") { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }
            .andExpect {
                status { isOk() }
                jsonPath("$[0].kind") { value("COLLECTION_SEARCH") }
                jsonPath("$[0].question") { value("Oostrum") }
                jsonPath("$[0].collection") { value("beeldbank") }
                jsonPath("$[0].ip") { value("203.0.113.7") }
                jsonPath("$[0].status") { value("SUCCEEDED") }
                jsonPath("$[0].expansion") { value(false) }
            }
        val entries = log.recent(10)
        assertTrue(entries.count { it.kind == RequestKind.COLLECTION_SEARCH && it.question == "Oostrum" } == 1, entries.toString())
        assertNotNull(entries.first().answerMs)
    }

    @Test
    fun `an AI question is opened on request and closed with status, model and times`() {
        val id = log.open(RequestKind.AI_QUESTION, "wie was burgemeester nielen?", "robbert@example.com", reference = "turn-rl-1", expansion = true)
        assertNotNull(id)
        log.firstFeedback("turn-rl-1")
        log.firstFeedback("turn-rl-1")
        log.finish("turn-rl-1", "SUCCEEDED", "anthropic/claude-sonnet-5-5", java.math.BigDecimal("0.3200"))
        val entry = log.recent(20).first { it.reference == "turn-rl-1" }
        assertEquals("SUCCEEDED", entry.status)
        assertEquals("anthropic/claude-sonnet-5-5", entry.model)
        assertEquals(0, java.math.BigDecimal("0.32").compareTo(entry.costUsd))
        assertEquals("robbert@example.com", entry.userEmail)
        assertTrue(entry.expansion)
        assertNotNull(entry.firstFeedbackMs)
        assertNotNull(entry.answerMs)
        assertTrue(entry.firstFeedbackMs!! <= entry.answerMs!!)
    }

    @Test
    fun `the Cloudflare address wins, bots and test traffic are marked, visitors get a key`() {
        items.upsert(ScrapedRecord("beeldbank", "rl-2", "Pastorie", "Huishoudster Grard Oostrom.", 1960, null, null, "https://example.org/rl-2", emptyMap()))
        val visitor = UUID.randomUUID()
        val browser = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/130.0 Safari/537.36"
        // Een gewone bezoeker met bezoekerscookie.
        mockMvc.get("/api/collections/search?q=Grard") {
            header("CF-Connecting-IP", "198.51.100.23"); header("X-Forwarded-For", "6.6.6.6, 10.0.0.1"); header("User-Agent", browser)
            cookie(Cookie("hkh_ai_visitor", visitor.toString()))
        }.andExpect { status { isOk() } }
        // Dezelfde bezoeker zonder cookie krijgt een hash van adres en browser.
        mockMvc.get("/api/collections/search?q=Grard") { header("CF-Connecting-IP", "198.51.100.24"); header("User-Agent", browser) }.andExpect { status { isOk() } }
        // Een script en een aanroep die zich als testverkeer meldt.
        mockMvc.get("/api/collections/search?q=Grard") { header("CF-Connecting-IP", "198.51.100.25"); header("User-Agent", "curl/8.7.1") }.andExpect { status { isOk() } }
        mockMvc.get("/api/collections/search?q=Grard") { header("CF-Connecting-IP", "198.51.100.26"); header("User-Agent", "HKH-Test/claude") }.andExpect { status { isOk() } }

        val byIp = log.recent(50).filter { it.question == "Grard" }.associateBy { it.ip }
        val normal = byIp.getValue("198.51.100.23")
        assertEquals("v:$visitor", normal.visitorKey)
        assertFalse(normal.bot)
        assertFalse(normal.test)
        assertEquals(browser, normal.userAgent)
        assertTrue(byIp.getValue("198.51.100.24").visitorKey!!.startsWith("h:"))
        assertTrue(byIp.getValue("198.51.100.25").bot)
        assertFalse(byIp.getValue("198.51.100.25").test)
        assertTrue(byIp.getValue("198.51.100.26").test)
        assertFalse(byIp.getValue("198.51.100.26").bot)
        // Het echte adres komt uit de Cloudflare-kop, niet uit de kop die een client kan invullen.
        assertTrue(byIp.keys.none { it == "6.6.6.6" })
    }

    @Test
    fun `old rows lose the full address and the visitor key, and the statistics count unique visitors without bots`() {
        jdbc.update("DELETE FROM request_log")
        fun insert(ageDays: Int, ip: String?, visitor: String?, bot: Boolean = false, test: Boolean = false, kind: String = "COLLECTION_SEARCH") = jdbc.update(
            "INSERT INTO request_log (created_at, kind, ip, question, visitor_key, bot, test, status) VALUES (CURRENT_TIMESTAMP - make_interval(days => ?), ?, ?, 'x', ?, ?, ?, 'SUCCEEDED')",
            ageDays, kind, ip, visitor, bot, test,
        )
        insert(40, "217.120.100.76", "h:oud")
        insert(1, "198.51.100.1", "h:a")
        insert(1, "198.51.100.1", "h:a")
        insert(0, "198.51.100.2", "v:b")
        insert(0, "198.51.100.3", "h:script", bot = true)
        insert(0, "198.51.100.4", "h:test", test = true)
        insert(0, "198.51.100.5", "u:c", kind = "AI_QUESTION")

        assertEquals(1, log.anonymizeOld())
        val old = log.recent(20).first { it.ipAnonymized }
        assertEquals("217.120.100.0", old.ip)
        assertNull(old.visitorKey)
        assertEquals(0, log.anonymizeOld(), "een tweede keer is er niets meer te doen")

        val week = log.usage(java.time.Instant.now().minusSeconds(7 * 86_400))
        assertEquals(4, week.uniqueVisitors, "a, b, test en c; het script telt niet mee")
        assertEquals(1, week.testVisitors)
        assertEquals(1, week.testRequests)
        assertEquals(1, week.botRequests)
        assertEquals(1, week.aiQuestions)
        assertEquals(4, week.searches)
        val month = log.usage(java.time.Instant.now().minusSeconds(30 * 86_400))
        assertEquals(week.uniqueVisitors, month.uniqueVisitors, "de oude regel is al verwijderd uit de teller")
    }

    @Test
    fun `the dashboard shows status for administrators only`() {
        mockMvc.get("/api/admin/dashboard").andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/admin/dashboard") { header(PreviewRuntimeConfig.ADMIN_HEADER, PreviewRuntimeConfig.ADMIN_HEADER_VALUE) }
            .andExpect {
                status { isOk() }
                jsonPath("$.ai.method") { exists() }
                jsonPath("$.ai.roles.length()") { value(4) }
                jsonPath("$.collection.totalRecords") { exists() }
                jsonPath("$.collection.cards.cards") { exists() }
                jsonPath("$.usage.today.uniqueVisitors") { exists() }
                jsonPath("$.usage.last30Days.costUsd") { exists() }
                jsonPath("$.usage.retentionDays") { value(30) }
            }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
