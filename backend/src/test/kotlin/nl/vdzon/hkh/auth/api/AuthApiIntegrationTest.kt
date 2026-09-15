package nl.vdzon.hkh.auth.api

import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.GoogleIdentity
import org.hamcrest.Matchers.hasSize
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.ObjectMapper

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(properties = ["hkh.auth.google-client-id=test-client", "hkh.auth.admin-allowed-emails=admin@example.com"])
@AutoConfigureMockMvc
@Import(AuthApiIntegrationTest.FakeGoogle::class)
class AuthApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val objectMapper: ObjectMapper,
) {
    @TestConfiguration
    class FakeGoogle {
        @Bean
        @Primary
        fun fakeVerifier(): GoogleIdTokenVerifier = GoogleIdTokenVerifier { idToken ->
            when (idToken) {
                "admin-token" -> GoogleIdentity("admin@example.com", true, "Admin")
                "visitor-token" -> GoogleIdentity("visitor@example.com", true, "Visitor")
                else -> throw org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.UNAUTHORIZED, "Invalid Google ID token",
                )
            }
        }
    }

    @Test
    fun `login returns a session token that keeps working and can be revoked`() {
        val token = login("visitor-token")

        mockMvc.get("/api/auth/me") { header(HttpHeaders.AUTHORIZATION, "Bearer $token") }
            .andExpect {
                status { isOk() }
                jsonPath("$.email") { value("visitor@example.com") }
                jsonPath("$.displayName") { value("Visitor") }
                jsonPath("$.roles") { value(hasSize<Any>(0)) }
            }

        mockMvc.post("/api/auth/logout") { header(HttpHeaders.AUTHORIZATION, "Bearer $token") }
            .andExpect { status { isNoContent() } }

        mockMvc.get("/api/auth/me") { header(HttpHeaders.AUTHORIZATION, "Bearer $token") }
            .andExpect { status { isUnauthorized() } }
    }

    @Test
    fun `administrators get the admin role and reach admin routes with their session`() {
        val token = login("admin-token")

        mockMvc.get("/api/auth/me") { header(HttpHeaders.AUTHORIZATION, "Bearer $token") }
            .andExpect {
                status { isOk() }
                jsonPath("$.roles[0]") { value("ADMIN") }
            }
        mockMvc.get("/api/admin/me") { header(HttpHeaders.AUTHORIZATION, "Bearer $token") }
            .andExpect {
                status { isOk() }
                jsonPath("$.email") { value("admin@example.com") }
            }

        val visitor = login("visitor-token")
        mockMvc.get("/api/admin/me") { header(HttpHeaders.AUTHORIZATION, "Bearer $visitor") }
            .andExpect { status { isForbidden() } }
    }

    @Test
    fun `an invalid Google token is refused and the config endpoint reports login availability`() {
        mockMvc.post("/api/auth/google") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"idToken":"bogus"}"""
        }.andExpect { status { isUnauthorized() } }

        mockMvc.get("/api/auth/config")
            .andExpect {
                status { isOk() }
                jsonPath("$.googleLoginEnabled") { value(true) }
            }
    }

    private fun login(googleToken: String): String {
        val body = mockMvc.post("/api/auth/google") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"idToken":"$googleToken"}"""
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        return objectMapper.readTree(body).path("token").asText()
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
