package nl.vdzon.hkh.news.api

import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.GoogleIdentity
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.http.MediaType
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(
    properties = [
        "hkh.auth.google-client-id=test-client",
        "hkh.auth.admin-allowed-emails=admin@example.com",
    ],
)
@Import(LatestNewsApiIntegrationTest.AuthTestConfiguration::class)
class LatestNewsApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val objectMapper: tools.jackson.databind.ObjectMapper,
) {
    /** Beheerroutes accepteren alleen het eigen sessietoken; wissel het (nep-)Google-token eerst in. */
    private val sessionToken: String by lazy {
        val body = mockMvc.post("/api/auth/google") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"idToken":"valid-token"}"""
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        objectMapper.readTree(body).path("token").asText()
    }

    @Test
    fun `administrator creates news and public API returns it newest first`() {
        create("Eerste bericht", "Dit is het eerste nieuwsbericht.")
        create("Tweede bericht", "Dit is het nieuwste nieuwsbericht.")

        mockMvc.get("/api/news")
            .andExpect {
                status { isOk() }
                jsonPath("$[0].title") { value("Tweede bericht") }
                jsonPath("$[1].title") { value("Eerste bericht") }
                jsonPath("$[0].publishedAt") { exists() }
            }
    }

    @Test
    fun `admin API rejects missing preview credentials and invalid input`() {
        mockMvc.post("/api/admin/news") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"Niet toegestaan","message":"Geen credentials"}"""
        }.andExpect { status { isUnauthorized() } }

        mockMvc.post("/api/admin/news") {
            header("Authorization", "Bearer valid-token")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"Ruw Google-token","message":"Wordt niet meer geaccepteerd"}"""
        }.andExpect { status { isUnauthorized() } }

        mockMvc.post("/api/admin/news") {
            header("Authorization", "Bearer $sessionToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"  ","message":"Geldig bericht"}"""
        }.andExpect { status { isBadRequest() } }
    }

    private fun create(title: String, message: String) {
        mockMvc.post("/api/admin/news") {
            header("Authorization", "Bearer $sessionToken")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"$title","message":"$message"}"""
        }.andExpect {
            status { isCreated() }
            jsonPath("$.title") { value(title) }
        }
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }

    @TestConfiguration
    class AuthTestConfiguration {
        @Bean
        @Primary
        fun testGoogleIdTokenVerifier(): GoogleIdTokenVerifier =
            GoogleIdTokenVerifier { GoogleIdentity("admin@example.com", true) }
    }
}
