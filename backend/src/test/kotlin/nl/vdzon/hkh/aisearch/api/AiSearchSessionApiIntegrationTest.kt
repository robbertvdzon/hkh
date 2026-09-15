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
import org.springframework.test.web.servlet.get
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
