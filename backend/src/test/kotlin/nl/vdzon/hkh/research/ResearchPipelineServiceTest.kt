package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.jdbc.core.JdbcTemplate
import tools.jackson.databind.ObjectMapper

class ResearchPipelineServiceTest {
    private val mapper = ObjectMapper()

    private fun card(ident: String, title: String, summary: String, image: Boolean = false) =
        CandidateCard(ResearchRef("beeldbank", ident), title, 1950, image, summary, listOf("person: Toos Oostrum"), setOf("Oostrum"), 0.9)

    /** Zoekdienst zonder database: geeft per ronde een vaste set kaarten terug. */
    private class FakeSearch(private val rounds: List<List<CandidateCard>>) : KeywordSearchService(jdbcStub) {
        val queries = mutableListOf<List<ResearchQuery>>()
        override fun search(queries: List<ResearchQuery>, exclude: Set<ResearchRef>, limit: Int): SearchResult {
            this.queries += queries
            val round = rounds.getOrElse(this.queries.size - 1) { emptyList() }.filter { it.ref !in exclude }
            return SearchResult(round, queries.flatMap { it.terms }.map { TermReport(it, listOf("Oostrom"), round.size.toLong(), 0) })
        }
        override fun cards(refs: List<ResearchRef>): List<CandidateCard> = rounds.flatten().filter { it.ref in refs }
    }

    private class FakeDocuments(private val cards: List<CandidateCard>) : ResearchDocumentStore {
        override fun load(refs: List<ResearchRef>): List<ResearchDocument> = refs.mapNotNull { ref ->
            cards.firstOrNull { it.ref == ref }?.let {
                ResearchDocument(ref, it.title, it.year, it.summary, mapOf("Straatnaam" to "Kerklaan"), "Volledige tekst over ${it.title}", it.hasImage, it.summary)
            }
        }
    }

    private class Listener : ResearchListener {
        val progress = mutableListOf<String>()
        val rounds = mutableListOf<ResearchRoundReport>()
        var stopAfterRound: Int? = null
        override fun progress(percent: Int, message: String) { progress += "$percent $message" }
        override fun round(report: ResearchRoundReport): Boolean { rounds += report; return stopAfterRound == report.round }
    }

    private fun runner(vararg answers: String): Pair<StructuredJobRunner, MutableList<StructuredJobRequest>> {
        val requests = mutableListOf<StructuredJobRequest>()
        val queue = answers.toMutableList()
        val runner = StructuredJobRunner { request ->
            requests += request
            StructuredJobOutcome("job-${requests.size}", mapper.readTree(queue.removeFirst()), 1000, 100, "anthropic/test")
        }
        return runner to requests
    }

    private val plan = """{"queries":[{"terms":["Toos Oostrum","Ciska Oostrum"],"yearFrom":0,"yearTo":0,"collections":[],"withImage":false,"reason":"hoofdpersonen"}],"conclusionSoFar":""}"""

    @Test
    fun `a fast question plans, searches once and writes with numbered sources mapped back to records`() {
        val cards = listOf(card("1", "Kerklaan 13a", "Toos en Cis Oostrum voor hun huis.", image = true), card("2", "Pastorie", "Grard Oostrom als huishoudster."))
        val (runner, requests) = runner(
            plan,
            """{"title":"De dames Oostrum","answerHtml":"<p>Toos woonde aan de Kerklaan <a data-hkh-source=\"1\">foto</a>.</p><figure data-hkh-source=\"1\"><figcaption>Het huis</figcaption></figure><p>Onbekend <a data-hkh-source=\"9\">x</a></p>","sources":[1,9],"suggestedFollowUps":["Wie was Grard Oostrom?"]}""",
        )
        val listener = Listener()
        val service = ResearchPipelineService(runner, FakeSearch(listOf(cards)), FakeDocuments(cards), mapper)

        val outcome = service.research(ResearchInput("Wie waren Toos en Ciska Oostrum?", "", maxRounds = 1, answerLength = "kort", guidance = "", idempotencyPrefix = "t"), listener)

        assertEquals(listOf(AiRole.RESEARCH, AiRole.WRITER), requests.map { it.role })
        assertEquals(listOf("t-plan", "t-write"), requests.map { it.idempotencyKey })
        assertTrue(requests[1].instruction.contains("[1] beeldbank 1 \"Kerklaan 13a\" (1950) — foto"))
        assertTrue(requests[1].instruction.contains("Volledige tekst over Pastorie"))
        val html = outcome.result.path("answerHtml").asText()
        assertTrue(html.contains("data-hkh-source=\"beeldbank/1\""), html)
        assertTrue(html.contains("<figure data-hkh-source=\"beeldbank/1\">"), html)
        assertTrue(html.contains("data-hkh-source=\"\""), "onbekend nummer wordt leeg: $html")
        assertEquals(listOf("beeldbank/1"), refs(outcome.result.path("sources")))
        assertEquals("Wie was Grard Oostrom?", outcome.result.path("suggestedFollowUps")[0].asText())
        assertEquals(1, outcome.rounds.size)
        assertEquals(2, outcome.stats.jobs.size)
        assertEquals(2000, outcome.stats.inputTokens)
        assertTrue(listener.progress.any { it.contains("Ronde 1: er wordt gezocht op Toos Oostrum, Ciska Oostrum") }, listener.progress.toString())
    }

    @Test
    fun `an extended question judges each round, follows leads and stops when the model has enough`() {
        val round1 = listOf(card("1", "Kerklaan 13a", "Toos en Cis Oostrum."), card("2", "Markt", "Niets met Oostrum te maken."))
        val round2 = listOf(card("3", "Pastorie", "Pastoor Van den Nouweland met huishoudster Oostrom."))
        val (runner, requests) = runner(
            plan,
            """{"relevant":[{"collection":"beeldbank","ident":"1","why":"de zusters zelf"},{"collection":"beeldbank","ident":"99","why":"bestaat niet"}],"acceptedVariants":["Oostrom"],"rejectedVariants":[],"conclusionSoFar":"Toos en Cis woonden aan de Kerklaan.","nextLeads":["pastoor Van den Nouweland"],"nextQueries":[{"terms":["Van den Nouweland"],"yearFrom":0,"yearTo":0,"collections":["beeldbank"],"withImage":false,"reason":"spoor"}],"enough":false}""",
            """{"relevant":[{"collection":"beeldbank","ident":"3","why":"huishoudster"}],"acceptedVariants":[],"rejectedVariants":[],"conclusionSoFar":"Grard was huishoudster bij de pastoor.","nextLeads":["Kerklaan"],"nextQueries":[{"terms":["Kerklaan"],"yearFrom":1940,"yearTo":1960,"collections":[],"withImage":false,"reason":"straat"}],"enough":true}""",
            """{"title":"Antwoord","answerHtml":"<p>Alles <a data-hkh-source=\"2\">bron</a></p>","sources":[2],"suggestedFollowUps":[]}""",
        )
        val listener = Listener()
        val search = FakeSearch(listOf(round1, round2))
        val outcome = ResearchPipelineService(runner, search, FakeDocuments(round1 + round2), mapper)
            .research(ResearchInput("Alles over de familie Oostrum", "", maxRounds = 5, answerLength = "lang", guidance = "Volg sporen.", idempotencyPrefix = "u"), listener)

        assertEquals(listOf("u-plan", "u-round-1", "u-round-2", "u-write"), requests.map { it.idempotencyKey })
        assertEquals(listOf("Toos Oostrum", "Ciska Oostrum"), search.queries[0].flatMap { it.terms })
        assertEquals(listOf("Van den Nouweland"), search.queries[1].flatMap { it.terms })
        assertEquals(listOf(1, 2), listener.rounds.map { it.round })
        assertEquals(listOf(1, 2), listener.rounds.map { it.chosen })
        assertEquals(listOf("pastoor Van den Nouweland"), listener.rounds[0].nextLeads)
        // Ronde 2 ziet de al gekozen kaart en de niet-gekozen van ronde 1 niet opnieuw als kandidaat.
        assertTrue(requests[2].instruction.contains("Al gekozen records (1)"))
        assertTrue(requests[2].instruction.contains("=== beeldbank/3 |"))
        assertTrue(!requests[2].instruction.contains("=== beeldbank/2 |"))
        // De schrijver krijgt de gekozen documenten genummerd in volgorde van kiezen; bron 2 is de pastorie.
        assertTrue(requests[3].instruction.contains("[2] beeldbank 3 \"Pastorie\""))
        assertEquals(listOf("beeldbank/3"), refs(outcome.result.path("sources")))
        // Niet-gevolgde sporen worden vervolgvragen.
        assertEquals("Wat is er te vinden over Kerklaan?", outcome.result.path("suggestedFollowUps")[0].asText())
        assertEquals(2, outcome.stats.rounds)
    }

    @Test
    fun `the stop button ends the search after the current round`() {
        val round1 = listOf(card("1", "Kerklaan 13a", "Toos en Cis Oostrum."))
        val (runner, requests) = runner(
            plan,
            """{"relevant":[{"collection":"beeldbank","ident":"1","why":"ja"}],"acceptedVariants":[],"rejectedVariants":[],"conclusionSoFar":"Gevonden.","nextLeads":["meer"],"nextQueries":[{"terms":["meer"],"yearFrom":0,"yearTo":0,"collections":[],"withImage":false,"reason":""}],"enough":false}""",
            """{"title":"Antwoord","answerHtml":"<p>Kort</p>","sources":[1],"suggestedFollowUps":[]}""",
        )
        val listener = Listener().apply { stopAfterRound = 1 }
        ResearchPipelineService(runner, FakeSearch(listOf(round1, round1)), FakeDocuments(round1), mapper)
            .research(ResearchInput("Vraag", "", maxRounds = 15, answerLength = "", guidance = "", idempotencyPrefix = "s"), listener)
        assertEquals(listOf("s-plan", "s-round-1", "s-write"), requests.map { it.idempotencyKey })
    }

    @Test
    fun `a cancelled turn stops before the next job`() {
        val (runner, _) = runner(plan)
        val listener = object : ResearchListener {
            override fun progress(percent: Int, message: String) {}
            override fun round(report: ResearchRoundReport) = false
            override fun cancelled() = true
        }
        assertFailsWith<ResearchCancelledException> {
            ResearchPipelineService(runner, FakeSearch(emptyList()), FakeDocuments(emptyList()), mapper)
                .research(ResearchInput("Vraag", "", maxRounds = 5, answerLength = "", guidance = "", idempotencyPrefix = "c"), listener)
        }
    }

    private fun refs(node: tools.jackson.databind.JsonNode): List<String> = buildList {
        for (item in node) add("${item.path("collection").asText()}/${item.path("ident").asText()}")
    }

    private companion object {
        val jdbcStub = JdbcTemplate()
    }
}
