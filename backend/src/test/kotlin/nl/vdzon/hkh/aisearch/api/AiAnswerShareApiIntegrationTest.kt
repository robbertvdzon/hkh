package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertFalse
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AiAnswerShareApiIntegrationTest(
    @param:Autowired private val mvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val mapper: ObjectMapper,
) {
    @Test
    fun `sharing publishes only a fixed answer and owner can revoke and replace the link`() {
        val owner = UUID.randomUUID()
        val (session, answer) = seed(owner)
        val cookie = Cookie(VISITOR_COOKIE, owner.toString())
        val route = "/api/ai-search/answers/$answer/share"
        mvc.get(route) { cookie(cookie) }.andExpect {
            status { isOk() }; jsonPath("$.token") { doesNotExist() }
        }
        val token = publish(answer, cookie)
        assertEquals(token, publish(answer, cookie))
        mvc.get("/api/shared-answers/$answer").andExpect { status { isNotFound() } }
        mvc.get("/api/ai-search/sessions/$session").andExpect { status { isNotFound() } }
        val first = mvc.get("/api/shared-answers/$token").andExpect {
            status { isOk() }
            header { string("Cache-Control", "no-store") }
            header { string("X-Robots-Tag", "noindex, nofollow") }
            jsonPath("$.question") { value("De geschiedenis van de Kerklaan?") }
            jsonPath("$.title") { value("De Kerklaan") }
            jsonPath("$.sources[0].ident") { value("42") }
            jsonPath("$.sessionId") { doesNotExist() }
            jsonPath("$.dossierContext") { doesNotExist() }
        }.andReturn().response.contentAsString
        assertFalse(first.contains("Geheime notitie"))
        jdbc.update("UPDATE ai_search_turn SET question = 'Latere privévraag', answer_html = '<p>Gewijzigd</p>' WHERE id = ?", answer)
        val second = mvc.get("/api/shared-answers/$token").andReturn().response.contentAsString
        assertEquals(first, second)
        mvc.delete(route) { cookie(cookie) }.andExpect { status { isNoContent() } }
        mvc.get("/api/shared-answers/$token").andExpect {
            status { isNotFound() }; header { string("Cache-Control", "no-store") }
        }
        val newToken = publish(answer, cookie)
        assertNotEquals(token, newToken)
        jdbc.update("DELETE FROM ai_search_session WHERE id = ?", session)
        mvc.get("/api/shared-answers/$newToken").andExpect { status { isNotFound() } }
    }

    @Test
    fun `another visitor cannot inspect create or revoke a link and unfinished answers cannot be shared`() {
        val owner = UUID.randomUUID()
        val (_, answer) = seed(owner)
        val ownCookie = Cookie(VISITOR_COOKIE, owner.toString())
        val stranger = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val route = "/api/ai-search/answers/$answer/share"
        mvc.get(route) { cookie(stranger) }.andExpect { status { isNotFound() } }
        mvc.post(route) { cookie(stranger) }.andExpect { status { isNotFound() } }
        val token = publish(answer, ownCookie)
        mvc.delete(route) { cookie(stranger) }.andExpect { status { isNotFound() } }
        mvc.get("/api/shared-answers/$token").andExpect { status { isOk() } }
        val (_, unfinished) = seed(owner, "RUNNING")
        mvc.post("/api/ai-search/answers/$unfinished/share") { cookie(ownCookie) }
            .andExpect { status { isConflict() } }
    }

    private fun publish(answer: UUID, cookie: Cookie): String = mapper.readTree(
        mvc.post("/api/ai-search/answers/$answer/share") { cookie(cookie) }
            .andExpect { status { isOk() } }.andReturn().response.contentAsString,
    ).path("token").asText()

    private fun seed(owner: UUID, status: String = "SUCCEEDED"): Pair<UUID, UUID> {
        val session = UUID.randomUUID()
        val answer = UUID.randomUUID()
        jdbc.update("INSERT INTO ai_search_session (id, visitor_id) VALUES (?, ?)", session, owner)
        jdbc.update(
            """
            INSERT INTO ai_search_turn (id, session_id, turn_number, question, status, title, answer_html, sources, dossier_context, completed_at)
            VALUES (?, ?, 1, 'De geschiedenis van de Kerklaan?', ?, 'De Kerklaan',
                '<p>Een geschiedenis met bronnen.</p>', '[{"collection":"beeldbank","ident":"42"}]'::jsonb,
                'Geheime notitie', CURRENT_TIMESTAMP)
            """.trimIndent(), answer, session, status,
        )
        return session to answer
    }

    companion object {
        @Container @ServiceConnection @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
