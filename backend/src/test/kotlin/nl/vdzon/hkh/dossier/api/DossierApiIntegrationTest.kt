package nl.vdzon.hkh.dossier.api

import jakarta.servlet.http.Cookie
import java.util.UUID
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.GoogleIdentity
import org.hamcrest.Matchers.containsString
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
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.MockHttpServletRequestDsl
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.put
import org.springframework.web.server.ResponseStatusException
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest(properties = ["hkh.auth.google-client-id=test-client"])
@AutoConfigureMockMvc
@Import(DossierApiIntegrationTest.FakeGoogle::class)
class DossierApiIntegrationTest(
    @param:Autowired private val mockMvc: MockMvc,
    @param:Autowired private val objectMapper: ObjectMapper,
    @param:Autowired private val jdbc: JdbcTemplate,
    @param:Autowired private val aiSearch: nl.vdzon.hkh.aisearch.AiSearchService,
) {
    @TestConfiguration
    class FakeGoogle {
        @Bean
        @Primary
        fun fakeVerifier(): GoogleIdTokenVerifier = GoogleIdTokenVerifier { idToken ->
            if (idToken.endsWith("@example.com")) GoogleIdentity(idToken, true, idToken.substringBefore('@'))
            else throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Google ID token")
        }
    }

    @Test
    fun `owner creates a dossier, shares it with roles and members see it`() {
        val owner = login("owner@example.com")
        val reader = login("reader@example.com")
        val stranger = login("stranger@example.com")

        val dossier = postJson("/api/dossiers", owner, """{"title":"Kerklaan","goal":"Artikel over de bewoners"}""", HttpStatus.CREATED)
        val dossierId = dossier.path("id").asText()
        assertJson(dossier, "role", "OWNER")

        // Een lid mag pas iets zien nadat het is toegevoegd.
        mockMvc.get("/api/dossiers/$dossierId") { auth(reader) }.andExpect { status { isNotFound() } }
        putJson("/api/dossiers/$dossierId/members/Reader@Example.com", owner, """{"role":"READER"}""")
        val asReader = getJson("/api/dossiers/$dossierId", reader)
        assertJson(asReader, "role", "READER")
        assertJson(asReader, "title", "Kerklaan")

        // Lezers mogen niets wijzigen, vreemden zien niets.
        mockMvc.put("/api/dossiers/$dossierId") {
            auth(reader); contentType = MediaType.APPLICATION_JSON; content = """{"title":"Anders","goal":""}"""
        }.andExpect { status { isForbidden() } }
        mockMvc.put("/api/dossiers/$dossierId/fact-sheet") {
            auth(reader); contentType = MediaType.APPLICATION_JSON; content = """{"markdown":"- feit"}"""
        }.andExpect { status { isForbidden() } }
        mockMvc.get("/api/dossiers/$dossierId") { auth(stranger) }.andExpect { status { isNotFound() } }
        mockMvc.get("/api/dossiers").andExpect { status { isUnauthorized() } }

        // Onderzoekers mogen de feitenlijst bewerken maar geen artikelen maken; alleen de eigenaar beheert leden.
        putJson("/api/dossiers/$dossierId/members/reader@example.com", owner, """{"role":"RESEARCHER"}""")
        val updated = putJson("/api/dossiers/$dossierId/fact-sheet", reader, """{"markdown":"## Personen\n- 1932 Jansen"}""")
        assertJson(updated, "factSheet.markdown", "## Personen\n- 1932 Jansen")
        mockMvc.post("/api/dossiers/$dossierId/articles") {
            auth(reader); contentType = MediaType.APPLICATION_JSON; content = """{"title":"Artikel","contentMarkdown":""}"""
        }.andExpect { status { isForbidden() } }
        mockMvc.put("/api/dossiers/$dossierId/members/x@example.com") {
            auth(reader); contentType = MediaType.APPLICATION_JSON; content = """{"role":"READER"}"""
        }.andExpect { status { isForbidden() } }
        mockMvc.delete("/api/dossiers/$dossierId") { auth(reader) }.andExpect { status { isForbidden() } }

        // Beide zien het dossier in hun lijst; een lid mag zichzelf verwijderen.
        mockMvc.get("/api/dossiers") { auth(reader) }.andExpect {
            status { isOk() }
            jsonPath("$[0].id") { value(dossierId) }
            jsonPath("$[0].role") { value("RESEARCHER") }
            jsonPath("$[0].memberCount") { value(1) }
        }
        mockMvc.delete("/api/dossiers/$dossierId/members/reader@example.com") { auth(reader) }.andExpect { status { isNoContent() } }
        mockMvc.get("/api/dossiers") { auth(reader) }.andExpect {
            status { isOk() }
            jsonPath("$") { value(hasSize<Any>(0)) }
        }

        // AI-vragen zijn zonder geconfigureerde runtime niet beschikbaar.
        mockMvc.post("/api/dossiers/$dossierId/questions") {
            auth(owner); contentType = MediaType.APPLICATION_JSON; content = """{"question":"Wie woonde er?"}"""
        }.andExpect { status { isServiceUnavailable() } }

        mockMvc.delete("/api/dossiers/$dossierId") { auth(owner) }.andExpect { status { isNoContent() } }
        mockMvc.get("/api/dossiers/$dossierId") { auth(owner) }.andExpect { status { isNotFound() } }
    }

    @Test
    fun `articles keep a version history with diff, restore and conflict detection`() {
        val owner = login("author@example.com")
        val editor = login("editor@example.com")
        val dossierId = postJson("/api/dossiers", owner, """{"title":"Dossier","goal":""}""", HttpStatus.CREATED).path("id").asText()
        putJson("/api/dossiers/$dossierId/members/editor@example.com", owner, """{"role":"EDITOR"}""")
        seedCollectionItem("beeldbank", "42", "Kerklaan 12")

        val article = postJson(
            "/api/dossiers/$dossierId/articles", owner,
            """{"title":"De Kerklaan","contentMarkdown":"## Begin\n\nZie [Kerklaan 12](hkh:beeldbank/42) en [onbekend](hkh:beeldbank/999)."}""",
            HttpStatus.CREATED,
        )
        val articleId = article.path("id").asText()
        val version1 = article.path("current").path("id").asText()
        assertJson(article, "current.versionNumber", "1")
        assertJson(article, "current.sources[0].title", "Kerklaan 12")
        assertJson(article, "current.unknownSources[0]", "beeldbank/999")
        assert(article.path("current").path("contentHtml").asText().contains("<h2>Begin</h2>"))

        // Een bewerker slaat een nieuwe versie op; opslaan op een verouderde versie geeft 409.
        val saved = putJson(
            "/api/articles/$articleId", editor,
            """{"title":"De Kerklaan","contentMarkdown":"## Begin\n\nZie [Kerklaan 12](hkh:beeldbank/42).\n\n## Bewoners\n\nJansen.","basedOnVersionId":"$version1"}""",
        )
        assertJson(saved, "current.versionNumber", "2")
        assertJson(saved, "current.authorEmail", "editor@example.com")
        mockMvc.put("/api/articles/$articleId") {
            auth(owner); contentType = MediaType.APPLICATION_JSON
            content = """{"title":"De Kerklaan","contentMarkdown":"x","basedOnVersionId":"$version1"}"""
        }.andExpect { status { isConflict() } }

        mockMvc.get("/api/articles/$articleId/versions/2/diff?against=1") { auth(owner) }.andExpect {
            status { isOk() }
            jsonPath("$.fromVersion") { value(1) }
            jsonPath("$.toVersion") { value(2) }
            jsonPath("$.lines[?(@.type=='INSERT')].text") { value(org.hamcrest.Matchers.hasItem("## Bewoners")) }
            jsonPath("$.lines[?(@.type=='DELETE')].text") { value(org.hamcrest.Matchers.hasItem(containsString("onbekend"))) }
        }

        val restored = postJson("/api/articles/$articleId/versions/1/restore", owner, "", HttpStatus.OK)
        assertJson(restored, "current.versionNumber", "3")
        assertJson(restored, "current.changeSummary", "Teruggezet naar versie 1")
        assert(restored.path("current").path("contentMarkdown").asText().contains("onbekend"))

        mockMvc.get("/api/articles/$articleId/versions") { auth(editor) }.andExpect {
            status { isOk() }
            jsonPath("$") { value(hasSize<Any>(3)) }
            jsonPath("$[2].isCurrent") { value(true) }
            jsonPath("$[1].basedOnVersionNumber") { value(1) }
        }

        // AI-voorstellen zijn zonder runtime niet beschikbaar; artikelen verschijnen in het dossier.
        mockMvc.post("/api/articles/$articleId/proposals") {
            auth(owner); contentType = MediaType.APPLICATION_JSON; content = """{"instruction":"Voeg een hoofdstuk toe"}"""
        }.andExpect { status { isServiceUnavailable() } }
        mockMvc.get("/api/dossiers/$dossierId") { auth(owner) }.andExpect {
            status { isOk() }
            jsonPath("$.articles[0].id") { value(articleId) }
            jsonPath("$.articles[0].currentVersionNumber") { value(3) }
        }

        // Een buitenstaander ziet het artikel niet; verwijderen ruimt de versies op.
        val stranger = login("stranger@example.com")
        mockMvc.get("/api/articles/$articleId") { auth(stranger) }.andExpect { status { isNotFound() } }
        mockMvc.delete("/api/articles/$articleId") { auth(editor) }.andExpect { status { isNoContent() } }
        mockMvc.get("/api/articles/$articleId") { auth(owner) }.andExpect { status { isNotFound() } }
    }

    @Test
    fun `adding a browser search preserves the original sharing and isolated dossier copy`() {
        val owner = login("adopter@example.com")
        val dossierId = postJson("/api/dossiers", owner, """{"title":"Dossier","goal":""}""", HttpStatus.CREATED).path("id").asText()
        val visitor = UUID.randomUUID()
        val sessionId = UUID.randomUUID()
        val answerId = UUID.randomUUID()
        jdbc.update("INSERT INTO ai_search_session (id, visitor_id) VALUES (?, ?)", sessionId, visitor)
        jdbc.update(
            """
            INSERT INTO ai_search_turn (id, session_id, turn_number, question, status, progress_percent, progress_message, title, answer_html, completed_at)
            VALUES (?, ?, 1, 'Wie woonde er?', 'SUCCEEDED', 100, 'Onderzoek afgerond', 'Bewoners', '<p>Een antwoord</p>', CURRENT_TIMESTAMP)
            """.trimIndent(),
            answerId, sessionId,
        )
        val cookie = Cookie("hkh_ai_visitor", visitor.toString())
        val token = objectMapper.readTree(mockMvc.post("/api/ai-search/answers/$answerId/share") {
            cookie(cookie)
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString).path("token").asText()
        val strangerCookie = Cookie("hkh_ai_visitor", UUID.randomUUID().toString())
        mockMvc.post("/api/dossiers/$dossierId/questions/adopt") {
            auth(owner); cookie(strangerCookie); contentType = MediaType.APPLICATION_JSON; content = """{"sessionId":"$sessionId"}"""
        }.andExpect { status { isNotFound() } }

        fun adopt(): JsonNode = objectMapper.readTree(mockMvc.post("/api/dossiers/$dossierId/questions/adopt") {
            auth(owner); cookie(cookie); contentType = MediaType.APPLICATION_JSON; content = """{"sessionId":"$sessionId"}"""
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString)
        val copy = adopt()
        val copyId = copy.path("id").asText()
        kotlin.test.assertNotEquals(sessionId.toString(), copyId)
        kotlin.test.assertNotEquals(answerId.toString(), copy.path("turns")[0].path("id").asText())
        kotlin.test.assertEquals("Bewoners", copy.path("turns")[0].path("title").asText())
        // Herhaald toevoegen is idempotent, en het origineel blijft zichtbaar en leesbaar.
        kotlin.test.assertEquals(copyId, adopt().path("id").asText())
        mockMvc.get("/api/ai-search/sessions") { cookie(cookie) }.andExpect {
            status { isOk() }; jsonPath("$[0].id") { value(sessionId.toString()) }
        }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect { status { isOk() } }
        mockMvc.get("/api/shared-answers/$token").andExpect { status { isOk() } }
        mockMvc.get("/api/dossiers/$dossierId/questions") { auth(owner) }.andExpect {
            status { isOk() }; jsonPath("$", hasSize<Any>(1)); jsonPath("$[0].id") { value(copyId) }
        }
        mockMvc.get("/api/ai-search/sessions/$copyId") { cookie(cookie) }.andExpect { status { isNotFound() } }
        kotlin.test.assertEquals(listOf("Wie woonde er?"), aiSearch.dossierAnswers(dossierId).map { it.question })
        // Dossiervervolgvragen komen niet in het origineel terecht.
        jdbc.update("INSERT INTO ai_search_turn (id, session_id, turn_number, question, status) VALUES (?, ?::uuid, 2, 'Dossiervervolg', 'SUCCEEDED')", UUID.randomUUID(), copyId)
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect {
            status { isOk() }; jsonPath("$.turns", hasSize<Any>(1))
        }
        // Verwijderen uit het dossier verwijdert nooit het origineel of zijn deellink.
        mockMvc.delete("/api/dossiers/$dossierId/questions/$copyId") { auth(owner) }.andExpect { status { isNoContent() } }
        mockMvc.get("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect { status { isOk() } }
        mockMvc.get("/api/shared-answers/$token").andExpect { status { isOk() } }
        // Omgekeerd blijft een nieuwe dossierkopie behouden als het origineel wordt verwijderd.
        val replacementId = adopt().path("id").asText()
        mockMvc.delete("/api/ai-search/sessions/$sessionId") { cookie(cookie) }.andExpect { status { isNoContent() } }
        mockMvc.get("/api/dossiers/$dossierId/questions/$replacementId") { auth(owner) }.andExpect {
            status { isOk() }; jsonPath("$.turns[0].question") { value("Wie woonde er?") }
        }
    }

    @Test
    fun `running browser research cannot be copied into a dossier`() {
        val owner = login("running-adopter@example.com")
        val dossierId = postJson("/api/dossiers", owner, """{"title":"Dossier","goal":""}""", HttpStatus.CREATED).path("id").asText()
        val visitor = UUID.randomUUID()
        val sessionId = UUID.randomUUID()
        jdbc.update("INSERT INTO ai_search_session (id, visitor_id) VALUES (?, ?)", sessionId, visitor)
        jdbc.update("INSERT INTO ai_search_turn (id, session_id, turn_number, question, status) VALUES (?, ?, 1, 'Nog bezig', 'RUNNING')", UUID.randomUUID(), sessionId)
        mockMvc.post("/api/dossiers/$dossierId/questions/adopt") {
            auth(owner); cookie(Cookie("hkh_ai_visitor", visitor.toString()))
            contentType = MediaType.APPLICATION_JSON; content = """{"sessionId":"$sessionId"}"""
        }.andExpect { status { isConflict() } }
        mockMvc.get("/api/dossiers/$dossierId/questions") { auth(owner) }.andExpect {
            status { isOk() }; content { json("[]") }
        }
        jdbc.update("UPDATE ai_search_turn SET status = 'CANCELLED' WHERE session_id = ?", sessionId)
    }

    private fun seedCollectionItem(collection: String, ident: String, title: String) {
        jdbc.update(
            """
            INSERT INTO collection_item (collection, ident, title, description, detail_url, search_text)
            VALUES (?, ?, ?, 'Beschrijving', ?, ?)
            ON CONFLICT (collection, ident) DO NOTHING
            """.trimIndent(),
            collection, ident, title, "https://www.historischekringheemskerk.nl/cgi-bin/$collection.pl?ident=$ident", title,
        )
    }

    private fun login(email: String): String {
        val body = mockMvc.post("/api/auth/google") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"idToken":"$email"}"""
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString
        return objectMapper.readTree(body).path("token").asText()
    }

    private fun MockHttpServletRequestDsl.auth(token: String) = header(HttpHeaders.AUTHORIZATION, "Bearer $token")

    private fun getJson(path: String, token: String): JsonNode = objectMapper.readTree(
        mockMvc.get(path) { auth(token) }.andExpect { status { isOk() } }.andReturn().response.contentAsString,
    )

    private fun postJson(path: String, token: String, body: String, expected: HttpStatus): JsonNode = objectMapper.readTree(
        mockMvc.post(path) {
            auth(token)
            if (body.isNotEmpty()) {
                contentType = MediaType.APPLICATION_JSON
                content = body
            }
        }.andExpect { status { isEqualTo(expected.value()) } }.andReturn().response.contentAsString,
    )

    private fun putJson(path: String, token: String, body: String): JsonNode = objectMapper.readTree(
        mockMvc.put(path) {
            auth(token); contentType = MediaType.APPLICATION_JSON; content = body
        }.andExpect { status { isOk() } }.andReturn().response.contentAsString,
    )

    private fun assertJson(node: JsonNode, path: String, expected: String) {
        var current = node
        for (segment in path.split('.')) {
            val match = Regex("([^\\[]+)(?:\\[(\\d+)])?").matchEntire(segment)!!
            current = current.path(match.groupValues[1])
            match.groupValues[2].takeIf(String::isNotEmpty)?.let { current = current.path(it.toInt()) }
        }
        kotlin.test.assertEquals(expected, current.asText(), "at $path")
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
