package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AiSearchSessionApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
) {
    @Test
    fun `first visit receives a persistent anonymous cookie`() {
        mockMvc.get("/api/ai-search/sessions") {
            header(HttpHeaders.HOST, "hkh.vdzonsoftware.nl")
        }
            .andExpect {
                status { isOk() }
                header { string(HttpHeaders.SET_COOKIE, org.hamcrest.Matchers.containsString("hkh_ai_visitor=")) }
                header { string(HttpHeaders.SET_COOKIE, org.hamcrest.Matchers.containsString("Max-Age=31536000")) }
                header { string(HttpHeaders.SET_COOKIE, org.hamcrest.Matchers.containsString("HttpOnly")) }
                header { string(HttpHeaders.SET_COOKIE, org.hamcrest.Matchers.containsString("Secure")) }
                content { json("[]") }
            }
    }

    @Test
    fun `visitor sees and deletes only their own persisted searches`() {
        val owner = UUID.randomUUID()
        val otherOwner = UUID.randomUUID()
        val ownSession = createCompletedSearch(owner, "Wat gebeurde er aan de Kerklaan?")
        val otherSession = createCompletedSearch(otherOwner, "Niet zichtbaar")
        val cookie = Cookie("hkh_ai_visitor", owner.toString())

        mockMvc.get("/api/ai-search/sessions") { cookie(cookie) }
            .andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].id") { value(ownSession.toString()) }
                jsonPath("$[0].question") { value("Wat gebeurde er aan de Kerklaan?") }
                jsonPath("$[0].status") { value("SUCCEEDED") }
                jsonPath("$[0].durationSeconds") { value(org.hamcrest.Matchers.greaterThanOrEqualTo(60)) }
            }

        mockMvc.get("/api/ai-search/sessions/$otherSession") { cookie(cookie) }
            .andExpect { status { isNotFound() } }

        mockMvc.delete("/api/ai-search/sessions/$ownSession") { cookie(cookie) }
            .andExpect { status { isNoContent() } }

        mockMvc.get("/api/ai-search/sessions") { cookie(cookie) }
            .andExpect {
                status { isOk() }
                content { json("[]") }
            }
    }

    @Test
    fun `previously saved answers never expose the import domain`() {
        val visitor = UUID.randomUUID()
        val sessionId = createCompletedSearch(visitor, "Bron op www.historischekringheemskerk.nl")
        val legacy = "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?ident=42"
        jdbc.update("UPDATE ai_search_turn SET answer_html = ? WHERE session_id = ?",
            "<p><a href=\"$legacy\">$legacy</a></p>", sessionId)
        val response = mockMvc.get("/api/ai-search/sessions/$sessionId") {
            cookie(Cookie("hkh_ai_visitor", visitor.toString()))
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        kotlin.test.assertFalse(response.contains("historischekringheemskerk", ignoreCase = true))
        kotlin.test.assertTrue(response.contains("https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42"))
        val overview = mockMvc.get("/api/ai-search/sessions") {
            cookie(Cookie("hkh_ai_visitor", visitor.toString()))
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        kotlin.test.assertFalse(overview.contains("historischekringheemskerk", ignoreCase = true))
    }

    @Test
    fun `answers expose their research depth and the separate source list`() {
        val visitor = UUID.randomUUID()
        val sessionId = createCompletedSearch(visitor, "Alles over Slot Assumburg")
        jdbc.update(
            "UPDATE ai_search_turn SET research_depth = 'THOROUGH', answer_html = '<p>Het slot.</p>', sources_html = '<article><h3>Leenbrief</h3></article>' WHERE session_id = ?",
            sessionId,
        )
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(Cookie("hkh_ai_visitor", visitor.toString())) }
            .andExpect {
                status { isOk() }
                jsonPath("$.turns[0].depth") { value("THOROUGH") }
                jsonPath("$.turns[0].answerHtml") { value("<p>Het slot.</p>") }
                jsonPath("$.turns[0].sourcesHtml") { value("<article><h3>Leenbrief</h3></article>") }
            }
    }

    @Test
    fun `an unknown depth in a request falls back to fast instead of failing`() {
        // Zonder runtime is de dienst niet beschikbaar (503); de aanvraag zelf is wel geldig (geen 400).
        mockMvc.post("/api/ai-search/sessions") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"question":"Wie woonde er op de Kerkweg?","depth":"onbekend"}"""
        }.andExpect { status { isServiceUnavailable() } }
    }

    @Test
    fun `the agent reports rounds and receives the owner's steering exactly once`() {
        val visitor = UUID.randomUUID()
        val cookie = Cookie("hkh_ai_visitor", visitor.toString())
        val sessionId = createCompletedSearch(visitor, "Alles over de wijk Commandeurs")
        val turnId = jdbc.queryForObject("SELECT id FROM ai_search_turn WHERE session_id = ?", UUID::class.java, sessionId)!!
        jdbc.update(
            "UPDATE ai_search_turn SET status = 'RUNNING', completed_at = NULL, research_depth = 'EXTENDED', control_token = 'geheim-token' WHERE id = ?",
            turnId,
        )
        val controlPath = "/api/ai-search/research/$turnId/geheim-token/rounds"

        // Ronde 1 gemeld: nog geen bijsturing.
        mockMvc.post(controlPath) {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ronde":1,"bronnen":12,"gevonden":"Bouw vanaf 1987.","volgende":["Oosterstreng","Commandeurslaan"]}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.stop") { value(false) }
            jsonPath("$.hint") { value(null) }
        }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect {
            status { isOk() }
            jsonPath("$.turns[0].steerable") { value(true) }
            jsonPath("$.turns[0].researchLog[0].round") { value(1) }
            jsonPath("$.turns[0].researchLog[0].sources") { value(12) }
            jsonPath("$.turns[0].researchLog[0].next[1]") { value("Commandeurslaan") }
            jsonPath("$.turns[0].progressMessage") { value(org.hamcrest.Matchers.containsString("Oosterstreng")) }
        }

        // De eigenaar stuurt bij; een ander mag dat niet.
        mockMvc.post("/api/ai-search/sessions/$sessionId/turns/$turnId/steer") {
            cookie(Cookie("hkh_ai_visitor", UUID.randomUUID().toString()))
            contentType = MediaType.APPLICATION_JSON
            content = """{"stop":true}"""
        }.andExpect { status { isNotFound() } }
        mockMvc.post("/api/ai-search/sessions/$sessionId/turns/$turnId/steer") {
            cookie(cookie)
            contentType = MediaType.APPLICATION_JSON
            content = """{"hint":"Sla de nertsenfarm over"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.turns[0].steering.hint") { value("Sla de nertsenfarm over") }
            jsonPath("$.turns[0].steering.delivered") { value(false) }
        }
        mockMvc.post("/api/ai-search/sessions/$sessionId/turns/$turnId/steer") {
            cookie(cookie)
            contentType = MediaType.APPLICATION_JSON
            content = """{"stop":true}"""
        }.andExpect { status { isOk() } }

        // De volgende melding levert de bijsturing af; daarna niet nog eens.
        mockMvc.post(controlPath) {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ronde":2,"bronnen":20,"gevonden":"Meer over de bouw.","volgende":[]}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.stop") { value(true) }
            jsonPath("$.hint") { value("Sla de nertsenfarm over") }
        }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect {
            jsonPath("$.turns[0].steering.delivered") { value(true) }
            jsonPath("$.turns[0].researchLog.length()") { value(2) }
        }
        mockMvc.post(controlPath) {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ronde":2,"bronnen":21,"gevonden":"Herhaald.","volgende":[]}"""
        }.andExpect {
            jsonPath("$.stop") { value(false) }
            jsonPath("$.hint") { value(null) }
        }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect {
            jsonPath("$.turns[0].researchLog.length()") { value(2) }
            jsonPath("$.turns[0].researchLog[1].sources") { value(21) }
        }

        // Verkeerd geheim of afgerond onderzoek: geen toegang.
        mockMvc.post("/api/ai-search/research/$turnId/fout-token/rounds") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ronde":3,"bronnen":0,"gevonden":"","volgende":[]}"""
        }.andExpect { status { isNotFound() } }
        jdbc.update("UPDATE ai_search_turn SET status = 'SUCCEEDED' WHERE id = ?", turnId)
        mockMvc.post("/api/ai-search/sessions/$sessionId/turns/$turnId/steer") {
            cookie(cookie)
            contentType = MediaType.APPLICATION_JSON
            content = """{"stop":true}"""
        }.andExpect { status { isConflict() } }
    }

    @Test
    fun `a fast search cannot be steered`() {
        val visitor = UUID.randomUUID()
        val sessionId = createCompletedSearch(visitor, "Wie was Piet Duin?")
        val turnId = jdbc.queryForObject("SELECT id FROM ai_search_turn WHERE session_id = ?", UUID::class.java, sessionId)!!
        jdbc.update("UPDATE ai_search_turn SET status = 'RUNNING', research_depth = 'FAST' WHERE id = ?", turnId)
        mockMvc.post("/api/ai-search/sessions/$sessionId/turns/$turnId/steer") {
            cookie(Cookie("hkh_ai_visitor", visitor.toString()))
            contentType = MediaType.APPLICATION_JSON
            content = """{"stop":true}"""
        }.andExpect { status { isBadRequest() } }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(Cookie("hkh_ai_visitor", visitor.toString())) }
            .andExpect { jsonPath("$.turns[0].steerable") { value(false) } }
    }

    private fun createCompletedSearch(visitorId: UUID, question: String): UUID {
        val sessionId = UUID.randomUUID()
        val turnId = UUID.randomUUID()
        jdbc.update(
            "INSERT INTO ai_search_session (id, visitor_id) VALUES (?, ?)",
            sessionId,
            visitorId,
        )
        jdbc.update(
            """
            INSERT INTO ai_search_turn (
                id, session_id, turn_number, question, status, progress_percent,
                progress_message, title, created_at, updated_at, completed_at
            ) VALUES (?, ?, 1, ?, 'SUCCEEDED', 100, 'Onderzoek afgerond', ?,
                CURRENT_TIMESTAMP - INTERVAL '65 seconds', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """.trimIndent(),
            turnId,
            sessionId,
            question,
            "Afgerond onderzoek",
        )
        return sessionId
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
