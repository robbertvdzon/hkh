package nl.vdzon.hkh.aisearch

import java.net.http.HttpClient
import java.time.Duration
import org.springframework.http.HttpHeaders
import org.springframework.http.client.JdkClientHttpRequestFactory
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

data class RuntimeJob(
    val id: String,
    val status: String,
    val phase: String,
    val progressPercent: Int?,
    val progressMessage: String?,
    val errorMessage: String?,
)

data class RuntimeActivity(val nextSequence: Long, val message: String?)

@Component
class AgentRuntimeClient(
    private val properties: AiSearchProperties,
    private val objectMapper: ObjectMapper,
) {
    private val client: RestClient by lazy {
        val requestFactory = JdkClientHttpRequestFactory(
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(),
        ).apply { setReadTimeout(Duration.ofSeconds(30)) }
        RestClient.builder()
            .baseUrl(properties.runtimeBaseUrl.trimEnd('/'))
            .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer ${properties.runtimeToken}")
            .requestFactory(requestFactory)
            .build()
    }

    fun isConfigured(): Boolean = properties.enabled && properties.runtimeToken.isNotBlank()

    fun createJob(idempotencyKey: String, instruction: String): RuntimeJob {
        val body = mapOf(
            "idempotencyKey" to idempotencyKey,
            "jobKind" to "APPLICATION_WORK",
            "taskType" to "STRUCTURED_GENERATION",
            "execution" to mapOf(
                "vendorId" to properties.vendorId,
                "model" to properties.model,
                "mode" to properties.mode,
            ),
            "input" to mapOf("instruction" to instruction, "objects" to emptyList<Any>()),
            "output" to mapOf("resultSchema" to RESULT_SCHEMA, "artifacts" to emptyList<Any>()),
            "executionTimeoutSeconds" to properties.executionTimeoutSeconds,
        )
        val json = client.post().uri("/v2/jobs").body(body).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen job terug")
        return parseJob(objectMapper.readTree(json))
    }

    fun getJob(jobId: String): RuntimeJob {
        val json = client.get().uri("/v2/jobs/{jobId}", jobId).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen jobstatus terug")
        return parseJob(objectMapper.readTree(json))
    }

    fun getResult(jobId: String): JsonNode {
        val json = client.get().uri("/v2/jobs/{jobId}/result", jobId).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen resultaat terug")
        return objectMapper.readTree(json).path("result")
    }

    fun cancel(jobId: String) {
        client.post().uri("/v2/jobs/{jobId}/cancel", jobId).retrieve().toBodilessEntity()
    }

    fun getActivity(jobId: String, afterSequence: Long): RuntimeActivity {
        val json = client.get()
            .uri("/v2/jobs/{jobId}/events?afterSequence={after}&limit=100", jobId, afterSequence)
            .retrieve().body(String::class.java) ?: return RuntimeActivity(afterSequence, null)
        val root = objectMapper.readTree(json)
        var cursor = afterSequence
        var activity: String? = null
        for (event in root.path("items")) {
            cursor = maxOf(cursor, event.path("sequence").asLong())
            val text = event.path("logText").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asText().orEmpty()
            classifyActivity(text)?.let { activity = it }
        }
        return RuntimeActivity(cursor, activity)
    }

    private fun classifyActivity(text: String): String? = when {
        text.contains("/api/collections/search") -> "Een nieuwe zoekpagina uit de collectie wordt opgehaald"
        text.contains("/api/collections/") -> "Details van relevante bronnen worden gecontroleerd"
        text.contains("jq ") || text.contains("python") -> "De gevonden gegevens worden geordend en vergeleken"
        else -> null
    }

    private fun parseJob(node: JsonNode) = RuntimeJob(
        id = node.path("id").asText(),
        status = node.path("status").asText(),
        phase = node.path("phase").asText(),
        progressPercent = node.path("progressPercent").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asInt(),
        progressMessage = node.path("progressMessage").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asText(),
        errorMessage = node.path("errorMessage").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asText(),
    )

    private val RESULT_SCHEMA: JsonNode by lazy {
        objectMapper.readTree(
            """
            {
              "type": "object",
              "required": ["title", "answerHtml", "sources", "suggestedFollowUps"],
              "properties": {
                "title": {"type": "string", "maxLength": 500},
                "answerHtml": {"type": "string", "maxLength": 750000},
                "sources": {
                  "type": "array", "maxItems": 100,
                  "items": {
                    "type": "object",
                    "required": ["collection", "ident"],
                    "properties": {
                      "collection": {"type": "string", "maxLength": 40},
                      "ident": {"type": "string", "maxLength": 64}
                    },
                    "additionalProperties": false
                  }
                },
                "suggestedFollowUps": {
                  "type": "array", "maxItems": 4,
                  "items": {"type": "string", "maxLength": 300}
                }
              },
              "additionalProperties": false
            }
            """.trimIndent(),
        )
    }
}
