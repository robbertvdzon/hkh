package nl.vdzon.hkh.aisearch

import java.net.http.HttpClient
import java.time.Duration
import nl.vdzon.hkh.research.AiRole
import nl.vdzon.hkh.research.JobAttachment
import nl.vdzon.hkh.research.StructuredJobCancelledException
import nl.vdzon.hkh.research.StructuredJobFailedException
import nl.vdzon.hkh.research.StructuredJobOutcome
import nl.vdzon.hkh.research.StructuredJobRequest
import nl.vdzon.hkh.research.StructuredJobRunner
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

/** Verbruik van één runtime-job: tokens en de API-equivalente kosten (USD) die de runtime schat. */
data class RuntimeUsage(val inputTokens: Long, val outputTokens: Long, val costUsd: java.math.BigDecimal?)

@Component
class AgentRuntimeClient(
    private val properties: AiSearchProperties,
    private val fixtures: PreviewAiRuntimeFixtures,
    private val objectMapper: ObjectMapper,
    private val modelSettings: AiModelSettings,
) : StructuredJobRunner {
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

    fun isConfigured(): Boolean = fixtures.enabled || (properties.enabled && properties.runtimeToken.isNotBlank())

    val pollIntervalMs: Long get() = properties.pollIntervalMs.coerceIn(500, 15_000)

    fun createJob(
        idempotencyKey: String,
        instruction: String,
        resultSchema: JsonNode = SEARCH_RESULT_SCHEMA,
        executionTimeoutSeconds: Int = properties.executionTimeoutSeconds,
        role: AiRole = AiRole.AGENT,
        attachments: List<JobAttachment> = emptyList(),
    ): RuntimeJob {
        if (fixtures.enabled) return fixtures.create(idempotencyKey, resultSchema)
        val execution = modelSettings.execution(role)
        require(instruction.length <= MAX_INSTRUCTION_LENGTH) { "De instructie is te lang voor de runtime (${instruction.length} tekens); zet grote inhoud in een bijlage." }
        val objects = attachments.map { attachment ->
            mapOf("objectId" to upload(attachment), "name" to attachment.name, "role" to "DOCUMENT")
        }
        val body = mapOf(
            "idempotencyKey" to idempotencyKey,
            "jobKind" to "APPLICATION_WORK",
            "taskType" to "STRUCTURED_GENERATION",
            "execution" to mapOf(
                "vendorId" to execution.vendorId,
                "model" to execution.model,
                "mode" to execution.mode,
            ),
            "input" to mapOf("instruction" to instruction, "objects" to objects),
            "output" to mapOf("resultSchema" to resultSchema, "artifacts" to emptyList<Any>()),
            "executionTimeoutSeconds" to executionTimeoutSeconds,
        )
        val json = client.post().uri("/v2/jobs").body(body).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen job terug")
        return parseJob(objectMapper.readTree(json))
    }

    /** Zet een tekstbijlage als invoerobject bij de runtime: reserveren, bytes sturen, afronden. */
    private fun upload(attachment: JobAttachment): String {
        val bytes = attachment.text.toByteArray(Charsets.UTF_8)
        val sha256 = java.security.MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
        val reserved = client.post().uri("/v2/uploads")
            .body(mapOf("filename" to attachment.filename, "mimeType" to attachment.mimeType, "sizeBytes" to bytes.size, "sha256" to sha256))
            .retrieve().body(String::class.java) ?: error("Agent Runtime gaf geen upload terug")
        val uploadId = objectMapper.readTree(reserved).path("uploadId").asText()
        require(uploadId.isNotBlank()) { "Agent Runtime gaf geen upload-id terug" }
        client.patch().uri("/v2/uploads/{id}", uploadId)
            .header("Upload-Offset", "0")
            .contentType(org.springframework.http.MediaType.parseMediaType("application/offset+octet-stream"))
            .body(bytes)
            .retrieve().toBodilessEntity()
        val completed = client.post().uri("/v2/uploads/{id}/complete", uploadId).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen object terug")
        return objectMapper.readTree(completed).path("objectId").asText().ifBlank { error("Agent Runtime gaf geen object-id terug") }
    }

    fun getJob(jobId: String): RuntimeJob {
        if (fixtures.enabled) return fixtures.job(jobId)
        val json = client.get().uri("/v2/jobs/{jobId}", jobId).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen jobstatus terug")
        return parseJob(objectMapper.readTree(json))
    }

    fun getResult(jobId: String): JsonNode = getResultEnvelope(jobId).path("result")

    /** Het volledige resultaat, inclusief het verbruik (usageSummary) van de job. */
    fun getResultEnvelope(jobId: String): JsonNode {
        if (fixtures.enabled) return objectMapper.createObjectNode().set("result", fixtures.result(jobId))
        val json = client.get().uri("/v2/jobs/{jobId}/result", jobId).retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen resultaat terug")
        return objectMapper.readTree(json)
    }

    /**
     * Eén gestructureerde aanroep: job aanmaken, pollen tot hij klaar is en het resultaat met
     * verbruik teruggeven. Blokkeert de aanroepende thread (virtuele threads in de services).
     */
    override fun run(request: StructuredJobRequest): StructuredJobOutcome {
        val execution = modelSettings.execution(request.role)
        val job = createJob(request.idempotencyKey, request.instruction, request.resultSchema, request.executionTimeoutSeconds, request.role, request.attachments)
        val deadline = System.currentTimeMillis() + (request.executionTimeoutSeconds + 600) * 1000L
        while (true) {
            val current = getJob(job.id)
            when (current.status) {
                "SUCCEEDED" -> {
                    val envelope = getResultEnvelope(job.id)
                    val used = usage(envelope)
                    return StructuredJobOutcome(job.id, envelope.path("result"), used.inputTokens, used.outputTokens, "${execution.vendorId}/${execution.model}", used.costUsd)
                }
                "FAILED" -> throw StructuredJobFailedException(job.id, current.errorMessage ?: "De AI-dienst kon de opdracht niet afronden.")
                "CANCELLED" -> throw StructuredJobFailedException(job.id, "De opdracht is gestopt.")
            }
            if (request.cancelled()) {
                runCatching { cancel(job.id) }
                throw StructuredJobCancelledException(job.id)
            }
            if (System.currentTimeMillis() > deadline) {
                runCatching { cancel(job.id) }
                throw StructuredJobFailedException(job.id, "De AI-dienst reageerde niet op tijd.")
            }
            Thread.sleep(pollIntervalMs)
        }
    }

    /** Tokens en API-equivalente kosten uit het verbruiksoverzicht van een resultaat. */
    fun usage(envelope: JsonNode): RuntimeUsage {
        var input = 0L
        var output = 0L
        val summary = envelope.path("usageSummary")
        for (metric in summary.path("metrics")) {
            val quantity = metric.path("quantity").asText("0").toBigDecimalOrNull()?.toLong() ?: 0L
            when (metric.path("metric").asText()) {
                "INPUT_TOKENS", "CACHED_INPUT_TOKENS", "CACHE_WRITE_TOKENS" -> input += quantity
                "OUTPUT_TOKENS" -> output += quantity
            }
        }
        var cost: java.math.BigDecimal? = null
        for (entry in summary.path("costs")) {
            if (entry.path("currency").asText("USD") != "USD") continue
            entry.path("amount").asText("").toBigDecimalOrNull()?.let { cost = (cost ?: java.math.BigDecimal.ZERO) + it }
        }
        return RuntimeUsage(input, output, cost)
    }

    fun cancel(jobId: String) {
        if (fixtures.enabled) { fixtures.job(jobId); return }
        client.post().uri("/v2/jobs/{jobId}/cancel", jobId).retrieve().toBodilessEntity()
    }

    fun getActivity(jobId: String, afterSequence: Long): RuntimeActivity {
        if (fixtures.enabled) { fixtures.job(jobId); return RuntimeActivity(afterSequence, null) }
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

    /** Modellen die de runtime voor dit project kan uitvoeren, met of er nu een worker voor online is. */
    fun executionOptions(): List<AiExecutionOption> {
        if (fixtures.enabled) {
            return listOf(AiExecutionOption(AiExecution(properties.vendorId, properties.model, properties.mode), available = true, onlineWorkers = 1))
        }
        val json = client.get().uri("/v2/execution-options?taskType=STRUCTURED_GENERATION").retrieve().body(String::class.java)
            ?: error("Agent Runtime gaf geen catalogus terug")
        val options = mutableListOf<AiExecutionOption>()
        for (node in objectMapper.readTree(json)) {
            val execution = node.path("execution")
            options += AiExecutionOption(
                AiExecution(execution.path("vendorId").asText(), execution.path("model").asText(), execution.path("mode").asText()),
                available = node.path("available").asBoolean(false),
                onlineWorkers = node.path("matchingOnlineWorkers").asInt(0),
            )
        }
        return options.sortedWith(compareBy({ it.execution.vendorId }, { it.execution.model }))
    }

    /** Maakt een JSON-schema-node uit een letterlijke schema-tekst; handig voor andere modules. */
    fun schema(json: String): JsonNode = objectMapper.readTree(json)

    private fun classifyActivity(text: String): String? = RuntimeActivityClassifier.classify(text)

    private fun parseJob(node: JsonNode) = RuntimeJob(
        id = node.path("id").asText(),
        status = node.path("status").asText(),
        phase = node.path("phase").asText(),
        progressPercent = node.path("progressPercent").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asInt(),
        progressMessage = node.path("progressMessage").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asText(),
        errorMessage = node.path("errorMessage").takeUnless(JsonNode::isMissingNode)?.takeUnless(JsonNode::isNull)?.asText(),
    )

    private val SEARCH_RESULT_SCHEMA: JsonNode by lazy {
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

    companion object {
        /** Limiet van het runtime-contract voor `input.instruction`. */
        const val MAX_INSTRUCTION_LENGTH = 65_536
    }
}

/** Vertaalt logregels van de agent naar een voortgangsmelding voor de gebruiker. */
internal object RuntimeActivityClassifier {
    fun classify(text: String): String? = when {
        text.contains("Spoor:") -> text.lineSequence()
            .map(String::trim).lastOrNull { it.trimStart('*', '_', '#', ' ').startsWith("Spoor:") }
            ?.substringAfter("Spoor:")?.trim()?.trim('"', '*', '_')?.takeIf(String::isNotBlank)
            ?.let { "Spoor wordt gevolgd: ${it.take(120)}" }
        text.contains("/api/collections/search") -> "Een nieuwe zoekpagina uit de collectie wordt opgehaald"
        text.contains("/api/collections/") -> "Details van relevante bronnen worden gecontroleerd"
        text.contains("jq ") || text.contains("python") -> "De gevonden gegevens worden geordend en vergeleken"
        else -> null
    }
}
