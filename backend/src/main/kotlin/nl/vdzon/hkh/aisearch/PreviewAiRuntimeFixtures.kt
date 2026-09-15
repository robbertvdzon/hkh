package nl.vdzon.hkh.aisearch

import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/** Only the external AI generation is synthetic; sessions, sources and PDF export remain real. */
@Component
class PreviewAiRuntimeFixtures(
    preview: PreviewRuntimeConfig,
    @param:Value("\${hkh.ai-search.fixture-enabled:false}") val enabled: Boolean,
    private val mapper: ObjectMapper,
) {
    init { if (enabled) preview.requireSeedingAllowed() }

    fun create(idempotencyKey: String, schema: JsonNode): RuntimeJob {
        require(schema.path("properties").has("answerHtml")) { "The isolated AI fixture only supports archive search answers" }
        return job("fixture-search:$idempotencyKey")
    }

    fun job(id: String): RuntimeJob {
        require(id.startsWith("fixture-search:")) { "A real runtime job cannot be read as a fixture" }
        return RuntimeJob(id, "SUCCEEDED", "COMPLETED", 100, "Synthetisch testantwoord voor PDF- en schermcontrole", null)
    }

    fun result(id: String): JsonNode {
        job(id)
        return mapper.readTree("""{
          "title":"Testantwoord (synthetisch)",
          "answerHtml":"<h2>Synthetische collectie voor exporttests</h2><p>Dit is herkenbare <strong>testinhoud</strong>, geen historisch of door AI onderzocht antwoord.</p><ul><li>Eerste testpunt</li><li>Tweede testpunt met accenten: café en België.</li></ul><table><tr><th>Onderdeel</th><th>Waarde</th></tr><tr><td>Bron</td><td>Testcollectie</td></tr></table><p><a data-hkh-source='beeldbank/test-pdf-001'>Bekijk de synthetische bron</a></p>",
          "sources":[{"collection":"beeldbank","ident":"test-pdf-001"}],
          "suggestedFollowUps":["Toon nog een testantwoord"]
        }""")
    }
}
