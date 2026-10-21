package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import nl.vdzon.hkh.aisearch.AiPreviewHit
import nl.vdzon.hkh.aisearch.AiSearchOwner
import nl.vdzon.hkh.aisearch.AiSearchPreview
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

/** De eerste treffers van de pijplijn worden bewaard op de beurt en door de sessie-API teruggegeven. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AiSearchPreviewIntegrationTest(
    @param:Autowired private val repository: AiSearchRepository,
    @param:Autowired private val mockMvc: MockMvc,
) {
    @Test
    fun `the preview is stored on the turn and returned by the session API`() {
        val visitor = UUID.randomUUID()
        val sessionId = repository.createSession(AiSearchOwner(visitorId = visitor.toString()))
        val turn = repository.createTurn(sessionId, "wie was burgemeester nielen?")
        assertNull(repository.findTurn(turn.id)?.preview)

        repository.savePreview(
            turn.id,
            AiSearchPreview(
                total = 313,
                perCollection = linkedMapOf("beeldbank" to 140, "artikelen" to 90),
                terms = listOf("Henk Nielen", "burgemeester"),
                hits = listOf(
                    AiPreviewHit("artikelen", "64", "Henk Nielen (1912-1977)", 2020, false, null, "https://hkh.vdzonsoftware.nl/#/objecten/artikelen/64"),
                    AiPreviewHit("beeldbank", "10587", "Portret burgemeester Nielen", 1977, true, "https://hkh.vdzonsoftware.nl/api/collection-media/abc", "https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10587"),
                ),
            ),
        )
        val stored = assertNotNull(repository.findTurn(turn.id)?.preview)
        assertEquals(313, stored.total)
        assertEquals(listOf("beeldbank", "artikelen"), stored.perCollection.keys.toList(), "de volgorde blijft behouden")
        assertEquals(2, stored.hits.size)
        assertNull(stored.hits[0].imageUrl)
        assertEquals(1977, stored.hits[1].year)

        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(Cookie("hkh_ai_visitor", visitor.toString())) }.andExpect {
            status { isOk() }
            jsonPath("$.turns[0].preview.total") { value(313) }
            jsonPath("$.turns[0].preview.terms[1]") { value("burgemeester") }
            jsonPath("$.turns[0].preview.perCollection.beeldbank") { value(140) }
            jsonPath("$.turns[0].preview.hits[0].title") { value("Henk Nielen (1912-1977)") }
            jsonPath("$.turns[0].preview.hits[1].url") { value("https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/10587") }
        }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
