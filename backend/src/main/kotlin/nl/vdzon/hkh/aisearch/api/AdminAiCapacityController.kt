package nl.vdzon.hkh.aisearch.api

import nl.vdzon.hkh.aisearch.*
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.core.io.ClassPathResource
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/** Test-only choices are accepted only on these authenticated admin routes. */
@RestController
@RequestMapping("/api/admin/ai-search/capacity")
class AdminAiCapacityController(
    private val service: AiCapacityService,
    private val runtime: AgentRuntimeClient,
    private val settings: AiModelSettings,
    private val auth: AdminAuthenticator,
    private val mapper: ObjectMapper,
) {
    private fun user(authorization: String?, preview: String?) = auth.authenticate(authorization, preview).email

    @GetMapping
    fun state(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?): Map<String, Any> {
        user(authorization, preview)
        val catalog = if (runtime.isConfigured()) runCatching { runtime.executionOptions() } else Result.success(emptyList())
        return mapOf("datasets" to service.datasets(), "campaigns" to service.campaigns(), "options" to catalog.getOrDefault(emptyList()),
            "catalogueError" to if (!runtime.isConfigured()) "Agent Runtime is niet ingesteld." else if (catalog.isFailure) "De runtimecatalogus is tijdelijk niet bereikbaar." else "",
            "method" to settings.method(), "writeBudgetChars" to settings.writeBudget().chars)
    }

    @PostMapping("/datasets")
    fun import(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?,
               @RequestBody body: JsonNode): Map<String,String> {
        val user = user(authorization, preview)
        val questions = body.path("questions")
        require(questions.isArray) { "questions moet een lijst zijn." }
        return mapOf("id" to service.importDataset(body.path("name").asText(), parseQuestions(questions), user))
    }

    @PostMapping("/datasets/bundled")
    fun bundled(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?): Map<String,String> {
        val user = user(authorization, preview)
        val questions = ClassPathResource("capacity/vragen-v1.json").inputStream.use { mapper.readTree(it) }
        return mapOf("id" to service.importDataset("HKH 1.000 vragen — versie 1", parseQuestions(questions), user))
    }

    @PostMapping("/campaigns")
    fun create(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?,
               @RequestBody request: CreateCapacityRequest): Map<String,String> {
        val user = user(authorization, preview)
        return mapOf("id" to service.create(request.name, validId(request.datasetId), request.execution, request.parallelism, request.maxScenarios, request.hours,
            request.repeatQuestions, request.accountAlias, request.datasetVersion, request.maxCostUsd, user, request.expandIfAvailable, request.followUpQuestion))
    }

    @GetMapping("/campaigns/{id}", "/campaigns/{id}/export")
    fun detail(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?,
               @PathVariable id: String): Map<String,Any?> { user(authorization, preview); return service.detail(validId(id)) }

    @GetMapping("/campaigns/{id}/runs/{runId}/result")
    fun result(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?,
               @PathVariable id: String, @PathVariable runId: String): org.springframework.http.ResponseEntity<Map<String,Any?>> {
        user(authorization, preview)
        return org.springframework.http.ResponseEntity.ok().cacheControl(org.springframework.http.CacheControl.noStore()).body(service.result(validId(id), validId(runId)))
    }

    @PostMapping("/campaigns/{id}/{action}")
    fun control(@RequestHeader("Authorization", required=false) authorization: String?, @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required=false) preview: String?,
                @PathVariable id: String, @PathVariable action: String): Map<String,Any?> {
        user(authorization, preview); service.control(validId(id), action); return service.detail(id)
    }

    @ExceptionHandler(IllegalArgumentException::class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    fun invalid(ex: IllegalArgumentException) = mapOf("message" to (ex.message ?: "Ongeldige invoer"))

    private fun validId(id: String): String = try { java.util.UUID.fromString(id).toString() } catch (_: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Ongeldig campagne-id") }
    private fun parseQuestions(nodes: JsonNode): List<CapacityQuestion> = nodes.asSequence().map { node ->
        val depth = when (val text = node.path("depth").asText("FAST").uppercase()) {
            "SNEL" -> AiResearchDepth.FAST
            "DOORZOEKEN" -> AiResearchDepth.EXTENDED
            "UITGEBREID" -> AiResearchDepth.THOROUGH
            else -> AiResearchDepth.entries.firstOrNull { it.name == text } ?: throw IllegalArgumentException("Onbekende diepte: $text")
        }
        CapacityQuestion(if (node.isTextual) node.asText() else node.path("question").asText(), depth, node.path("category").asText("overig"))
    }.toList()
}

data class CreateCapacityRequest(
    val name: String, val datasetId: String, val execution: AiExecution, val parallelism: Int = 1,
    val maxScenarios: Int = 1000, val hours: Int = 168, val repeatQuestions: Boolean = false,
    val accountAlias: String = "default", val datasetVersion: String = "onbekend", val maxCostUsd: java.math.BigDecimal? = null,
    val expandIfAvailable: Boolean = false, val followUpQuestion: String? = null,
)
