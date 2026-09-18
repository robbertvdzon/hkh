package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertNull
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.GoogleIdentity
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import nl.vdzon.hkh.aisearch.AgentRuntimeClient
import nl.vdzon.hkh.aisearch.RuntimeJob
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito.doReturn
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean
import tools.jackson.databind.JsonNode
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.MediaType
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
@SpringBootTest(properties = ["hkh.auth.google-client-id=test-client"])
@AutoConfigureMockMvc
@Import(AiSearchAccountApiIntegrationTest.FakeGoogle::class)
class AiSearchAccountApiIntegrationTest(
    @param:Autowired private val mvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val mapper: ObjectMapper,
) {
    @MockitoSpyBean
    lateinit var runtime: AgentRuntimeClient

    @BeforeEach
    fun localRuntime() {
        val job = RuntimeJob("test-job", "SUCCEEDED", "COMPLETED", 100, "Test afgerond", null)
        doReturn(true).`when`(runtime).isConfigured()
        doReturn(job).`when`(runtime).createJob(anyString(), anyString(), schemaMatcher(), anyInt())
        doReturn(job).`when`(runtime).getJob(anyString())
        doReturn(mapper.readTree(
            """{"title":"Synthetisch antwoord","answerHtml":"<p>Testinhoud</p>","sources":[],"suggestedFollowUps":[]}""",
        )).`when`(runtime).getResult(anyString())
        doReturn(nl.vdzon.hkh.aisearch.RuntimeActivity(0, null)).`when`(runtime).getActivity(anyString(), org.mockito.ArgumentMatchers.anyLong())
    }

    private fun schemaMatcher(): JsonNode = org.mockito.ArgumentMatchers.any(JsonNode::class.java) ?: mapper.createObjectNode()

    @Test
    fun `new signed in questions and follow ups are account owned without a visitor cookie`() {
        val email = "${UUID.randomUUID()}@example.com"
        val firstDevice = login(email)
        val secondDevice = login(email)
        val id = mapper.readTree(mvc.post("/api/ai-search/sessions") {
            header("Authorization", "Bearer $firstDevice"); contentType = MediaType.APPLICATION_JSON
            content = """{"question":"Synthetische accountvraag"}"""
        }.andExpect { status { isAccepted() }; header { doesNotExist("Set-Cookie") } }
            .andReturn().response.contentAsString).path("id").asText()
        assertEquals(1, jdbc.queryForObject(
            "SELECT COUNT(*) FROM ai_search_session WHERE id = ?::uuid AND user_id IS NOT NULL AND visitor_id IS NULL AND dossier_id IS NULL",
            Int::class.java, id,
        ))
        // Alleen de externe AI is een lokale fake; opslag, login en autorisatie zijn echt.
        org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(5)).until {
            jdbc.queryForObject("SELECT status FROM ai_search_turn WHERE session_id = ?::uuid", String::class.java, id) == "SUCCEEDED"
        }
        mvc.post("/api/ai-search/sessions/$id/questions") {
            header("Authorization", "Bearer $secondDevice"); contentType = MediaType.APPLICATION_JSON
            content = """{"question":"Een vervolgvraag vanaf de tweede pc"}"""
        }.andExpect { status { isAccepted() }; jsonPath("$.turns.length()") { value(2) } }
        mvc.get("/api/ai-search/sessions/$id") { header("Authorization", "Bearer $firstDevice") }
            .andExpect { status { isOk() }; jsonPath("$.turns[1].question") { value("Een vervolgvraag vanaf de tweede pc") } }
        mvc.get("/api/ai-search/sessions/$id").andExpect { status { isNotFound() } }
    }

    @TestConfiguration
    class FakeGoogle {
        @Bean @Primary
        fun verifier(): GoogleIdTokenVerifier = GoogleIdTokenVerifier { GoogleIdentity(it, true, "Test") }
    }

    @Test
    fun `login merges browser questions and two devices see the same account without cookies`() {
        val browserA = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val browserB = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val (first, _) = seed(browserA)
        val (second, _) = seed(browserB)
        val email = "${UUID.randomUUID()}@example.com"
        val deviceA = login(email)
        val deviceB = login(email)
        repeat(2) {
            mvc.post("/api/ai-search/sessions/claim") {
                cookie(browserA); header("Authorization", "Bearer $deviceA")
            }.andExpect { status { isNoContent() } }
        }
        // Een bestaande ingelogde sessie koppelt ook bij de eerstvolgende gewone aanvraag.
        mvc.get("/api/ai-search/sessions") {
            cookie(browserB); header("Authorization", "Bearer $deviceB")
        }.andExpect { status { isOk() }; jsonPath("$.length()") { value(2) } }
        for (token in listOf(deviceA, deviceB)) {
            mvc.get("/api/ai-search/sessions") { header("Authorization", "Bearer $token") }
                .andExpect { status { isOk() }; jsonPath("$.length()") { value(2) }; header { string("Cache-Control", "no-store") } }
            for (id in listOf(first, second)) {
                mvc.get("/api/ai-search/sessions/$id") { header("Authorization", "Bearer $token") }
                    .andExpect { status { isOk() }; jsonPath("$.id") { value(id) } }
            }
        }
        assertNull(jdbc.queryForObject("SELECT visitor_id FROM ai_search_session WHERE id = ?::uuid", String::class.java, first))
        val (laterAnonymous, _) = seed(browserA)
        mvc.get("/api/ai-search/sessions") { cookie(browserA) }.andExpect {
            status { isOk() }; jsonPath("$.length()") { value(1) }; jsonPath("$[0].id") { value(laterAnonymous) }
        }
    }

    @Test
    fun `logout and a different account cannot read mutate export or reclaim private questions`() {
        val browser = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val (id, answer) = seed(browser)
        val alice = login("${UUID.randomUUID()}@example.com")
        val bob = login("${UUID.randomUUID()}@example.com")
        mvc.post("/api/ai-search/sessions/claim") { cookie(browser); header("Authorization", "Bearer $alice") }
            .andExpect { status { isNoContent() } }
        for (token in listOf(null, bob)) {
            fun auth(request: org.springframework.test.web.servlet.MockHttpServletRequestDsl) {
                request.cookie(browser)
                if (token != null) request.header("Authorization", "Bearer $token")
            }
            mvc.get("/api/ai-search/sessions") { auth(this) }.andExpect { status { isOk() }; content { json("[]") } }
            for (path in listOf("/api/ai-search/sessions/$id", "/api/ai-search/$answer/export/pdf", "/api/ai-search/answers/$answer/share")) {
                mvc.get(path) { auth(this) }.andExpect { status { isNotFound() } }
            }
            for (path in listOf("/api/ai-search/sessions/$id/cancel", "/api/ai-search/answers/$answer/share")) {
                mvc.post(path) { auth(this) }.andExpect { status { isNotFound() } }
            }
            mvc.post("/api/ai-search/sessions/$id/questions") {
                auth(this); contentType = MediaType.APPLICATION_JSON; content = """{"question":"Vervolgvraag"}"""
            }.andExpect { status { isNotFound() } }
            mvc.delete("/api/ai-search/sessions/$id") { auth(this) }.andExpect { status { isNotFound() } }
            mvc.delete("/api/ai-search/answers/$answer/share") { auth(this) }.andExpect { status { isNotFound() } }
        }
        mvc.get("/api/ai-search/sessions/$id") { header("Authorization", "Bearer $alice") }.andExpect { status { isOk() } }
    }

    @Test
    fun `account owns sharing pdf cancellation deletion and dossier adoption on another device`() {
        val browser = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val (id, answer) = seed(browser)
        val shared = mapper.readTree(mvc.post("/api/ai-search/answers/$answer/share") { cookie(browser) }
            .andExpect { status { isOk() } }.andReturn().response.contentAsString).path("token").asText()
        val token = login("${UUID.randomUUID()}@example.com")
        mvc.post("/api/ai-search/sessions/claim") { cookie(browser); header("Authorization", "Bearer $token") }
            .andExpect { status { isNoContent() } }
        mvc.get("/api/shared-answers/$shared").andExpect { status { isOk() } }
        mvc.post("/api/ai-search/answers/$answer/share") { header("Authorization", "Bearer $token") }
            .andExpect { status { isOk() }; jsonPath("$.token") { value(shared) } }
        mvc.get("/api/ai-search/$answer/export/pdf") { header("Authorization", "Bearer $token") }
            .andExpect { status { isOk() }; content { contentType(MediaType.APPLICATION_PDF) } }
        mvc.delete("/api/ai-search/answers/$answer/share") { header("Authorization", "Bearer $token") }
            .andExpect { status { isNoContent() } }
        mvc.get("/api/shared-answers/$shared").andExpect { status { isNotFound() } }
        val dossier = mapper.readTree(mvc.post("/api/dossiers") {
            header("Authorization", "Bearer $token"); contentType = MediaType.APPLICATION_JSON
            content = """{"title":"Accountdossier","goal":"Test"}"""
        }.andExpect { status { isCreated() } }.andReturn().response.contentAsString).path("id").asText()
        mvc.post("/api/dossiers/$dossier/questions/adopt") {
            header("Authorization", "Bearer $token"); contentType = MediaType.APPLICATION_JSON
            content = """{"sessionId":"$id"}"""
        }.andExpect { status { isOk() } }
        // De dossierkopie verschijnt niet nogmaals in persoonlijke vragen.
        mvc.get("/api/ai-search/sessions") { header("Authorization", "Bearer $token") }
            .andExpect { status { isOk() }; jsonPath("$.length()") { value(1) } }
        jdbc.update("UPDATE ai_search_turn SET status = 'RUNNING' WHERE id = ?::uuid", answer)
        mvc.post("/api/ai-search/sessions/$id/cancel") { header("Authorization", "Bearer $token") }
            .andExpect { status { isOk() }; jsonPath("$.turns[0].status") { value("CANCELLED") } }
        mvc.delete("/api/ai-search/sessions/$id") { header("Authorization", "Bearer $token") }
            .andExpect { status { isNoContent() } }
        mvc.get("/api/ai-search/sessions") { header("Authorization", "Bearer $token") }
            .andExpect { status { isOk() }; content { json("[]") } }
    }

    @Test
    fun `invalid authorization does not fall back to anonymous access or claim questions`() {
        val browser = Cookie(VISITOR_COOKIE, UUID.randomUUID().toString())
        val (id, _) = seed(browser)
        for (authorization in listOf("Bearer invalid", "Basic invalid", "Bearer ")) {
            mvc.get("/api/ai-search/sessions/$id") { cookie(browser); header("Authorization", authorization) }
                .andExpect { status { isUnauthorized() } }
            mvc.post("/api/ai-search/sessions/claim") { cookie(browser); header("Authorization", authorization) }
                .andExpect { status { isUnauthorized() } }
        }
        mvc.post("/api/ai-search/sessions/claim") { cookie(browser) }.andExpect { status { isUnauthorized() } }
        assertEquals(browser.value, jdbc.queryForObject("SELECT visitor_id::text FROM ai_search_session WHERE id = ?::uuid", String::class.java, id))
        mvc.get("/api/ai-search/sessions/$id") { cookie(browser) }.andExpect { status { isOk() } }
    }

    private fun login(email: String): String = mapper.readTree(mvc.post("/api/auth/google") {
        contentType = MediaType.APPLICATION_JSON; content = """{"idToken":"$email"}"""
    }.andExpect { status { isOk() } }.andReturn().response.contentAsString).path("token").asText()

    private fun seed(cookie: Cookie): Pair<String, String> {
        val id = UUID.randomUUID().toString()
        val answer = UUID.randomUUID().toString()
        jdbc.update("INSERT INTO ai_search_session (id, visitor_id) VALUES (?::uuid, ?::uuid)", id, cookie.value)
        jdbc.update("""
            INSERT INTO ai_search_turn (id, session_id, turn_number, question, status, title, answer_html, completed_at)
            VALUES (?::uuid, ?::uuid, 1, 'Synthetische vraag', 'SUCCEEDED', 'Testantwoord', '<p>Synthetisch antwoord</p>', CURRENT_TIMESTAMP)
        """.trimIndent(), answer, id)
        return id to answer
    }

    companion object {
        @Container @ServiceConnection @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
