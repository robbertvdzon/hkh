package nl.vdzon.hkh.aisearch

import kotlin.test.*
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import tools.jackson.databind.ObjectMapper

class PreviewAiRuntimeFixturesTest {
    private val mapper = ObjectMapper()
    @Test
    fun `fixtures cannot be enabled outside a validated isolated environment`() {
        val production = PreviewRuntimeConfig(false, "", "jdbc:postgresql://production/hkh", "")
        assertFailsWith<IllegalArgumentException> { PreviewAiRuntimeFixtures(production, true, mapper) }
        assertFalse(PreviewAiRuntimeFixtures(production, false, mapper).enabled)
    }
    @Test
    fun `fixture jobs survive client reconstruction and never reinterpret real jobs`() {
        val preview = PreviewRuntimeConfig(true, "hkh-acceptance", "jdbc:postgresql://database:5432/hkh", "")
        val first = PreviewAiRuntimeFixtures(preview, true, mapper)
        val job = first.create("unique-turn", mapper.readTree("""{"properties":{"answerHtml":{}}}"""))
        val restarted = PreviewAiRuntimeFixtures(preview, true, mapper)
        assertEquals("SUCCEEDED", restarted.job(job.id).status)
        assertEquals("test-pdf-001", restarted.result(job.id).path("sources")[0].path("ident").asText())
        assertFailsWith<IllegalArgumentException> { restarted.result("real-runtime-job") }
        assertFailsWith<IllegalArgumentException> { first.create("other", mapper.readTree("{}")) }
    }
}
