package nl.vdzon.hkh.news.api

import kotlin.test.assertTrue
import nl.vdzon.hkh.news.LatestNewsService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

/** Het nieuws is alleen nog openbaar leesbaar; berichten plaatsen via beheer bestaat niet meer. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class LatestNewsApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val service: LatestNewsService,
) {
    @Test
    fun `the public API returns news newest first`() {
        service.create("Eerste bericht", "Dit is het eerste nieuwsbericht.", "test")
        service.create("Tweede bericht", "Dit is het nieuwste nieuwsbericht.", "test")

        mockMvc.get("/api/news")
            .andExpect {
                status { isOk() }
                jsonPath("$[0].title") { value("Tweede bericht") }
                jsonPath("$[1].title") { value("Eerste bericht") }
                jsonPath("$[0].publishedAt") { exists() }
            }
    }

    @Test
    fun `publishing news through the admin API no longer exists`() {
        val status = mockMvc.post("/api/admin/news") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"Niet meer mogelijk","message":"Geen beheerroute"}"""
        }.andReturn().response.status
        assertTrue(status >= 400, "geen succesvol antwoord meer: $status")
        assertTrue(service.findAll().none { it.title == "Niet meer mogelijk" })
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
