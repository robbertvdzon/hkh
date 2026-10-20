package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.jdbc.core.JdbcTemplate
import tools.jackson.databind.ObjectMapper

class ResearchPipelineServiceTest {
    private val mapper = ObjectMapper()

    private fun card(ident: String, title: String, summary: String, image: Boolean = false, text: Boolean = false, year: Int? = 1950, collection: String = "beeldbank") =
        CandidateCard(ResearchRef(collection, ident), title, year, image, summary, listOf("person: Toos Oostrum"), setOf("Oostrum"), 0.9, hasText = text)

    /** Zoekdienst zonder database: SQL 1 geeft de eerste set terug, SQL 2 (select) de tweede. */
    private class FakeSearch(private val first: List<CandidateCard>, private val second: List<CandidateCard> = first) : KeywordSearchService(jdbcStub) {
        val searches = mutableListOf<List<ResearchQuery>>()
        val selections = mutableListOf<ResearchQuery>()
        override fun search(queries: List<ResearchQuery>, exclude: Set<ResearchRef>, limit: Int): SearchResult {
            searches += queries
            val found = first.filter { it.ref !in exclude }
            return SearchResult(found, queries.flatMap { it.terms }.map { TermReport(it, listOf("Oostrom"), found.size.toLong(), 1) }, found.size + 5)
        }
        override fun select(query: ResearchQuery, limit: Int): SearchResult {
            selections += query
            val included = (first + second).distinctBy { it.ref }.filter { it.ref in query.includeRecords }
            val found = if (query.terms.isEmpty()) emptyList() else second.filter { it.ref !in query.includeRecords }
            return SearchResult(included + found, emptyList(), included.size + found.size)
        }
        override fun cards(refs: List<ResearchRef>): List<CandidateCard> = (first + second).distinctBy { it.ref }.filter { it.ref in refs }
    }

    private class FakeDocuments(private val cards: List<CandidateCard>, private val texts: Map<String, String> = emptyMap()) : ResearchDocumentStore {
        override fun load(refs: List<ResearchRef>): List<ResearchDocument> = refs.mapNotNull { ref ->
            cards.firstOrNull { it.ref == ref }?.let {
                ResearchDocument(ref, it.title, it.year, it.summary, mapOf("Straatnaam" to "Kerklaan"), texts[ref.ident] ?: "Volledige tekst over ${it.title}", it.hasImage, it.summary)
            }
        }
    }

    private class Listener : ResearchListener {
        val progress = mutableListOf<String>()
        val rounds = mutableListOf<ResearchRoundReport>()
        override fun progress(percent: Int, message: String) { progress += "$percent $message" }
        override fun round(report: ResearchRoundReport): Boolean { rounds += report; return false }
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

    private fun direction(terms: String, include: String = "", sort: String = "none", conclusion: String = "Toos en Cis woonden aan de Kerklaan.") =
        """{"conclusionSoFar":"$conclusion","query":{"terms":[$terms],"yearFrom":0,"yearTo":0,"collections":[],"withImage":false,"sortByYear":"$sort","includeRecords":[$include],"reason":"test"}}"""

    private fun input(question: String, prefix: String = "t", budget: Int = ResearchPipelineService.DEFAULT_WRITE_BUDGET_CHARS, prior: List<ResearchRef> = emptyList()) =
        ResearchInput(question, "", priorSources = prior, idempotencyPrefix = prefix, writeBudgetChars = budget)

    @Test
    fun `a question is answered in two model runs, directing the search and then writing from the selected records`() {
        val found = listOf(card("1", "Kerklaan 13a", "Toos en Cis Oostrum voor hun huis.", image = true), card("2", "Markt", "Niets met Oostrum te maken."))
        val selected = listOf(card("1", "Kerklaan 13a", "Toos en Cis Oostrum voor hun huis.", image = true), card("3", "Pastorie", "Grard Oostrom als huishoudster.", text = true))
        val (runner, requests) = runner(
            direction(""""Oostrum","Oostrom"""", include = """{"collection":"beeldbank","ident":"1"},{"collection":"beeldbank","ident":"99"}"""),
            """{"title":"De dames Oostrum","answerHtml":"<p>Toos woonde aan de Kerklaan <a data-hkh-source=\"1\">foto</a>.</p><figure data-hkh-source=\"1\"><figcaption>Het huis</figcaption></figure><p>Grard <a data-hkh-source=\"2\">pastorie</a> en onbekend <a data-hkh-source=\"9\">x</a></p>","sources":[1,2,9],"suggestedFollowUps":["Wie was Grard Oostrom?","Wat gebeurde er in de pastorie?"]}""",
        )
        val listener = Listener()
        val search = FakeSearch(found, selected)
        val service = ResearchPipelineService(runner, search, FakeDocuments(found + selected), mapper)

        val outcome = service.research(input("Wie waren Toos Oostrum en Ciska Oostrum?"), listener)

        // Geen planjob: de termen komen uit de vraag.
        assertEquals(listOf(AiRole.RESEARCH, AiRole.WRITER), requests.map { it.role })
        assertEquals(listOf("t-direct", "t-write"), requests.map { it.idempotencyKey })
        assertEquals(listOf("Toos Oostrum", "Ciska Oostrum", "Oostrum"), search.searches.single().single().terms)
        // De richtstap ziet alle kaarten met treffertelling en fragmentruimte.
        assertTrue(requests[0].instruction.contains("=== beeldbank/1 | Kerklaan 13a | 1950 | foto | gevonden op: Oostrum ==="), requests[0].instruction)
        assertTrue(requests[0].instruction.contains("In totaal zijn 7 records geraakt; de 2 best gerangschikte kaarten staan hieronder."), requests[0].instruction)
        // SQL 2 krijgt de zoekopdracht van het model; een onbekend record wordt genegeerd.
        val selection = search.selections.single()
        assertEquals(listOf("Oostrum", "Oostrom"), selection.terms)
        assertEquals(listOf(ResearchRef("beeldbank", "1")), selection.includeRecords)
        // De schrijver krijgt de geselecteerde records genummerd, met volledige tekst, en de niet-geselecteerde als "ook gevonden".
        val write = requests[1].instruction
        assertTrue(write.contains("[1] beeldbank 1 \"Kerklaan 13a\" (1950) — foto"), write)
        assertTrue(write.contains("[2] beeldbank 3 \"Pastorie\""), write)
        assertTrue(write.contains("Volledige tekst over Pastorie"), write)
        assertTrue(write.contains("Ook gevonden, niet gebruikt (1"), write)
        assertTrue(write.contains("- Markt (1950)"), write)
        assertTrue(write.contains("Tussenconclusie uit het onderzoek: Toos en Cis woonden aan de Kerklaan."), write)
        val html = outcome.result.path("answerHtml").asText()
        assertTrue(html.contains("data-hkh-source=\"beeldbank/1\""), html)
        assertTrue(html.contains("data-hkh-source=\"beeldbank/3\""), html)
        assertTrue(html.contains("<figure data-hkh-source=\"beeldbank/1\">"), html)
        assertTrue(html.contains("data-hkh-source=\"\""), "onbekend nummer wordt leeg: $html")
        assertEquals(listOf("beeldbank/1", "beeldbank/3"), refs(outcome.result.path("sources")))
        assertEquals(listOf("Wie was Grard Oostrom?", "Wat gebeurde er in de pastorie?"), strings(outcome.result.path("suggestedFollowUps")))
        assertEquals(1, outcome.rounds.size)
        assertEquals(2, listener.rounds.single().chosen)
        assertEquals("Toos en Cis woonden aan de Kerklaan.", listener.rounds.single().conclusion)
        assertEquals(2, outcome.stats.jobs.size)
        assertEquals(2, outcome.stats.candidatesSeen)
        assertEquals(2, outcome.stats.chosen)
        assertTrue(listener.progress.any { it.contains("Er wordt gezocht op Toos Oostrum, Ciska Oostrum, Oostrum") }, listener.progress.toString())
        assertTrue(listener.progress.any { it.contains("beoordeelt 2 kaarten") }, listener.progress.toString())
    }

    @Test
    fun `short records always go in full and long articles fill the budget in rank order, the rest only as card`() {
        val photo = card("p", "Foto", "Een foto.", image = true)
        val short = card("s", "Kort stuk", "Kort.", text = true)
        val long1 = card("a1", "Artikel 1", "Eerste artikel.", text = true)
        val long2 = card("a2", "Artikel 2", "Tweede artikel.", text = true)
        val all = listOf(long1, photo, long2, short)
        val texts = mapOf("s" to "x".repeat(1_000), "a1" to "a".repeat(30_000), "a2" to "b".repeat(30_000))
        val (runner, requests) = runner(
            direction(""""Oostrum""""),
            """{"title":"Antwoord","answerHtml":"<p>Alles <a data-hkh-source=\"1\">bron</a></p>","sources":[1],"suggestedFollowUps":[]}""",
        )
        val service = ResearchPipelineService(runner, FakeSearch(all), FakeDocuments(all, texts), mapper)
        // Budget: de korte records (ongeveer 1.300 tekens) plus één lang artikel van 30.000 passen; het tweede niet meer.
        val packed = service.pack(FakeDocuments(all, texts).load(all.map { it.ref }), 32_000)
        assertEquals(listOf("p", "s", "a1"), packed.full.map { it.ref.ident })
        assertEquals(listOf("a2"), packed.brief.map { it.ref.ident })
        assertTrue(packed.clipped.isEmpty())

        service.research(input("Oostrum", budget = 32_000), Listener())
        val write = requests[1].instruction
        assertTrue(write.contains("Bronnen (3):"), write)
        assertTrue(write.contains("[3] beeldbank a1 \"Artikel 1\""), write)
        assertTrue(write.contains("Alleen de kaart gelezen (1;"), write)
        assertTrue(write.contains("[4] beeldbank a2 \"Artikel 2\""), write)
        assertTrue(write.contains("van [4] tot en met [4] is alleen de kaart beschikbaar"), write)
        assertFalse(write.contains("b".repeat(100)), "de tekst van het tweede artikel gaat niet mee")

        // Een heel lang document wordt ingekort tot het plafond per document.
        val huge = ResearchPipelineService(runner, FakeSearch(all), FakeDocuments(all, mapOf("a1" to "c".repeat(100_000))), mapper)
            .pack(FakeDocuments(all, mapOf("a1" to "c".repeat(100_000))).load(listOf(long1.ref)), 450_000)
        assertEquals(ResearchPipelineService.MAX_DOCUMENT_CHARS, huge.full.single().documentText?.length)
        assertEquals(setOf(long1.ref), huge.clipped)
    }

    @Test
    fun `without terms in the question the model plans the first search, and without hits the writer explains that`() {
        val (runner, requests) = runner(
            """{"queries":[{"terms":["Van den Nouweland"],"yearFrom":0,"yearTo":0,"collections":[],"withImage":false,"reason":"uit de context"}],"conclusionSoFar":""}""",
            """{"title":"Niets gevonden","answerHtml":"<p>Niets.</p>","sources":[],"suggestedFollowUps":[]}""",
        )
        val search = FakeSearch(emptyList())
        val outcome = ResearchPipelineService(runner, search, FakeDocuments(emptyList()), mapper)
            .research(input("en hij?", prefix = "p"), Listener())
        assertEquals(listOf("p-plan", "p-write"), requests.map { it.idempotencyKey })
        assertEquals(listOf("Van den Nouweland"), search.searches.single().single().terms)
        assertTrue(requests[1].instruction.contains("Er zijn geen bronnen gevonden."))
        assertEquals(0, outcome.stats.chosen)
        assertEquals(1, outcome.rounds.size)
    }

    @Test
    fun `a direction without a usable query keeps the found cards in rank order`() {
        val found = listOf(card("1", "Kerklaan 13a", "Toos."), card("2", "Pastorie", "Grard."))
        val (runner, requests) = runner(
            direction("", conclusion = "Twee kaarten."),
            """{"title":"Antwoord","answerHtml":"<p>Kort <a data-hkh-source=\"2\">x</a></p>","sources":[2],"suggestedFollowUps":[]}""",
        )
        val search = FakeSearch(found)
        val outcome = ResearchPipelineService(runner, search, FakeDocuments(found), mapper).research(input("Oostrum"), Listener())
        assertTrue(search.selections.isEmpty(), "zonder termen of vaste records geen SQL 2")
        assertTrue(requests[1].instruction.contains("[2] beeldbank 2 \"Pastorie\""))
        assertEquals(listOf("beeldbank/2"), refs(outcome.result.path("sources")))
    }

    @Test
    fun `sources of the previous answer take part as known cards`() {
        val found = listOf(card("1", "Kerklaan 13a", "Toos."))
        val prior = card("7", "Eerder antwoord", "Bron uit het vorige antwoord.")
        val (runner, requests) = runner(direction(""""Oostrum""""), """{"title":"A","answerHtml":"<p>x</p>","sources":[],"suggestedFollowUps":[]}""")
        ResearchPipelineService(runner, FakeSearch(found, found + prior), FakeDocuments(found + prior), mapper)
            .research(input("Oostrum", prior = listOf(prior.ref)), Listener())
        assertTrue(requests[0].instruction.contains("=== beeldbank/7 | Eerder antwoord"), requests[0].instruction)
    }

    @Test
    fun `the first answer is bounded and reports whether more is available, and the expansion reuses the selection with the short answer as basis`() {
        val found = listOf(card("1", "Kerklaan 13a", "Toos.", image = true), card("2", "Pastorie", "Grard.", text = true))
        val (runner, requests) = runner(
            direction(""""Oostrum""""),
            """{"title":"Kort","answerHtml":"<p>Kort antwoord <a data-hkh-source=\"1\">foto</a></p>","sources":[1],"suggestedFollowUps":[],"moreAvailable":true,"moreSummary":"Ook de pastorie en de scholen."}""",
            """{"title":"Lang","answerHtml":"<p>Lang antwoord <a data-hkh-source=\"2\">pastorie</a></p>","sources":[2],"suggestedFollowUps":[],"moreAvailable":true,"moreSummary":"niets"}""",
        )
        val service = ResearchPipelineService(runner, FakeSearch(found), FakeDocuments(found), mapper)
        val first = service.research(input("Oostrum", prefix = "b"), Listener())
        assertTrue(requests[1].instruction.contains("HOOGSTENS TIEN ALINEA'S"), requests[1].instruction)
        assertTrue(first.result.path("moreAvailable").asBoolean())
        assertEquals("Ook de pastorie en de scholen.", first.result.path("moreSummary").asText())
        assertEquals(listOf("beeldbank/1", "beeldbank/2"), first.stats.selection)

        val expanded = service.expand(input("Oostrum", prefix = "b2"), listOf(ResearchRef("beeldbank", "1"), ResearchRef("beeldbank", "2")), "Kort antwoord", Listener())
        assertEquals(listOf("b-direct", "b-write", "b2-expand"), requests.map { it.idempotencyKey })
        val expand = requests[2].instruction
        assertTrue(expand.contains("UITWERKING van een eerder, begrensd antwoord"), expand)
        assertTrue(expand.contains("<previous-answer>Kort antwoord</previous-answer>"), expand)
        assertTrue(expand.contains("Geen plafond"), expand)
        assertTrue(expand.contains("[2] beeldbank 2 \"Pastorie\""), expand)
        assertFalse(expand.contains("HOOGSTENS TIEN ALINEA'S"))
        // De uitwerking is de volledige versie: nooit nog "meer beschikbaar".
        assertFalse(expanded.result.path("moreAvailable").asBoolean())
        assertEquals(listOf("beeldbank/2"), refs(expanded.result.path("sources")))
        assertEquals(1, expanded.stats.jobs.size)
        assertEquals("uitwerken", expanded.stats.jobs.single().step)
    }

    @Test
    fun `a cancelled turn stops before the next job`() {
        val (runner, _) = runner()
        val listener = object : ResearchListener {
            override fun progress(percent: Int, message: String) {}
            override fun round(report: ResearchRoundReport) = false
            override fun cancelled() = true
        }
        assertFailsWith<ResearchCancelledException> {
            ResearchPipelineService(runner, FakeSearch(listOf(card("1", "x", "y"))), FakeDocuments(emptyList()), mapper)
                .research(input("Oostrum", prefix = "c"), listener)
        }
    }

    private fun refs(node: tools.jackson.databind.JsonNode): List<String> = buildList {
        for (item in node) add("${item.path("collection").asText()}/${item.path("ident").asText()}")
    }

    private fun strings(node: tools.jackson.databind.JsonNode): List<String> = buildList { for (item in node) add(item.asText()) }

    private companion object {
        val jdbcStub = JdbcTemplate()
    }
}
