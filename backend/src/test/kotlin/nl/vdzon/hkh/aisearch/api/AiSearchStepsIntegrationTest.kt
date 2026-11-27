package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertEquals
import nl.vdzon.hkh.aisearch.AiSearchOwner
import nl.vdzon.hkh.aisearch.AiSearchRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** De stappen van een onderzoek worden op de beurt bewaard en door de sessie-API teruggegeven; de zoekfunctie staat alleen open voor een lopend onderzoek. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AiSearchStepsIntegrationTest(
    @param:Autowired private val repository: AiSearchRepository,
    @param:Autowired private val mockMvc: MockMvc,
) {
    @Test
    fun `steps are stored in order, the same step twice in a row counts once, and the session API returns them`() {
        val visitor = UUID.randomUUID()
        val sessionId = repository.createSession(AiSearchOwner(visitorId = visitor.toString()))
        val turn = repository.createTurn(sessionId, "sinds wanneer staat de laurentius kerk er")
        assertEquals(emptyList(), repository.findTurn(turn.id)!!.steps)

        repository.addStep(turn.id, "De onderzoeker leest uw vraag")
        repository.addStep(turn.id, "Zoekt in het archief naar de bouw van de Laurentiuskerk")
        repository.addStep(turn.id, "Zoekt in het archief naar de bouw van de Laurentiuskerk")
        repository.addStep(turn.id, "42 archiefstukken gevonden; de onderzoeker leest de 25 beste")
        repository.addStep(turn.id, "  ")

        val steps = repository.findTurn(turn.id)!!.steps
        assertEquals(
            listOf("De onderzoeker leest uw vraag", "Zoekt in het archief naar de bouw van de Laurentiuskerk", "42 archiefstukken gevonden; de onderzoeker leest de 25 beste"),
            steps.map { it.text },
        )
        assertEquals(steps.map { it.at }.sorted(), steps.map { it.at })

        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(Cookie("hkh_ai_visitor", visitor.toString())) }.andExpect {
            status { isOk() }
            jsonPath("$.turns[0].steps.length()") { value(3) }
            jsonPath("$.turns[0].steps[1].text") { value("Zoekt in het archief naar de bouw van de Laurentiuskerk") }
        }
    }

    @Test
    fun `the search function answers only for a running research that opened it, and never without the secret`() {
        val sessionId = repository.createSession(AiSearchOwner(visitorId = UUID.randomUUID().toString()))
        val turn = repository.createTurn(sessionId, "wie was burgemeester nielen?")
        val token = repository.findTurn(turn.id)!!.controlToken

        mockMvc.get("/api/ai-search/research/${turn.id}/verkeerd-geheim/search") { param("termen", "Nielen") }.andExpect { status { isNotFound() } }
        // Het juiste geheim, maar er loopt voor deze beurt geen modelaanroep die de zoekfunctie heeft geopend.
        mockMvc.get("/api/ai-search/research/${turn.id}/$token/search") { param("doel", "burgemeester Nielen"); param("termen", "Henk Nielen|Nielen") }.andExpect { status { isNotFound() } }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
