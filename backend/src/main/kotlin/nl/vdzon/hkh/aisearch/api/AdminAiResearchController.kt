package nl.vdzon.hkh.aisearch.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Duration
import java.time.Instant
import nl.vdzon.hkh.aisearch.AiBenchmarkQuestion
import nl.vdzon.hkh.aisearch.AiBenchmarkRepository
import nl.vdzon.hkh.aisearch.AiBenchmarkService
import nl.vdzon.hkh.aisearch.AiResearchDepth
import nl.vdzon.hkh.aisearch.AiResearchMethod
import nl.vdzon.hkh.aisearch.AiSearchRepository
import nl.vdzon.hkh.aisearch.AiSearchTurn
import nl.vdzon.hkh.aisearch.AiTurnStatus
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException
import tools.jackson.databind.ObjectMapper

/** Eén beurt in het vergelijkingsoverzicht: wat is gevraagd, hoe en wat het kostte. */
data class AiTurnComparisonView(
    val id: String,
    val sessionId: String,
    val question: String,
    val title: String?,
    val status: AiTurnStatus,
    val depth: AiResearchDepth,
    val method: AiResearchMethod,
    val createdAt: Instant,
    val durationSeconds: Long,
    val rounds: Int,
    val sourceCount: Int,
    /** Modellen die aan het antwoord bijdroegen (leverancier/model), uit de vastgelegde jobs. */
    val models: List<String>,
    val jobs: Int,
    val inputTokens: Long,
    val outputTokens: Long,
    val askedBy: String?,
    val benchmarkQuestionId: Long?,
    val errorMessage: String?,
)

data class AiBenchmarkQuestionView(val id: Long, val question: String, val depth: AiResearchDepth, val createdAt: Instant, val createdBy: String?)

data class AiBenchmarkView(val questions: List<AiBenchmarkQuestionView>, val running: Boolean)

data class AddBenchmarkQuestionRequest(@field:NotBlank @field:Size(min = 3, max = 1000) val question: String, @field:Size(max = 20) val depth: String? = null)

data class RunBenchmarkRequest(val questionIds: List<Long>? = null)

/** Beheer: vergelijkingsoverzicht van onderzoeken en de testset. */
@RestController
@RequestMapping("/api/admin/ai-search")
class AdminAiResearchController(
    private val repository: AiSearchRepository,
    private val benchmark: AiBenchmarkRepository,
    private val runner: AiBenchmarkService,
    private val authenticator: AdminAuthenticator,
    private val objectMapper: ObjectMapper,
) {
    @GetMapping("/turns")
    fun turns(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) limit: Int?,
        @RequestParam(required = false) benchmarkOnly: Boolean?,
    ): List<AiTurnComparisonView> {
        authenticator.authenticate(authorization, previewHeader)
        return repository.recentTurns((limit ?: 50).coerceIn(1, 500), benchmarkOnly == true).map { (turn, askedBy) -> turn.toComparison(askedBy) }
    }

    @GetMapping("/benchmark")
    fun benchmark(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): AiBenchmarkView {
        authenticator.authenticate(authorization, previewHeader)
        return view()
    }

    @PostMapping("/benchmark")
    fun add(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @Valid @RequestBody request: AddBenchmarkQuestionRequest,
    ): AiBenchmarkView {
        val admin = authenticator.authenticate(authorization, previewHeader)
        benchmark.add(request.question.trim(), AiResearchDepth.parse(request.depth), admin.email)
        return view()
    }

    @DeleteMapping("/benchmark/{id}")
    fun delete(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @PathVariable id: Long,
    ): AiBenchmarkView {
        authenticator.authenticate(authorization, previewHeader)
        if (!benchmark.delete(id)) throw ResponseStatusException(HttpStatus.NOT_FOUND, "Vraag niet gevonden")
        return view()
    }

    @PostMapping("/benchmark/run")
    fun run(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestBody(required = false) request: RunBenchmarkRequest?,
    ): AiBenchmarkView {
        val admin = authenticator.authenticate(authorization, previewHeader)
        if (benchmark.list().isEmpty()) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De testset is leeg.")
        if (!runner.run(admin.email, request?.questionIds)) throw ResponseStatusException(HttpStatus.CONFLICT, "Er loopt al een testsetrun.")
        return view()
    }

    private fun view() = AiBenchmarkView(benchmark.list().map { it.toView() }, runner.isRunning())

    private fun AiBenchmarkQuestion.toView() = AiBenchmarkQuestionView(id, question, depth, createdAt, createdBy)

    private fun AiSearchTurn.toComparison(askedBy: String?): AiTurnComparisonView {
        val stats = researchStats?.let { runCatching { objectMapper.readTree(it) }.getOrNull() }
        val jobs = stats?.path("jobs")
        val models = mutableListOf<String>()
        var input = 0L
        var output = 0L
        var jobCount = 0
        if (jobs != null) {
            for (job in jobs) {
                jobCount++
                job.path("model").asText("").takeIf { it.isNotBlank() }?.let { if (it !in models) models += it }
                input += job.path("inputTokens").asLong(0)
                output += job.path("outputTokens").asLong(0)
            }
        }
        return AiTurnComparisonView(
            id = id, sessionId = sessionId, question = question, title = title, status = status, depth = depth, method = method,
            createdAt = createdAt, durationSeconds = Duration.between(createdAt, completedAt ?: Instant.now()).seconds.coerceAtLeast(0),
            rounds = researchLog.size, sourceCount = sources.size, models = models, jobs = jobCount,
            inputTokens = input, outputTokens = output, askedBy = askedBy, benchmarkQuestionId = benchmarkQuestionId, errorMessage = errorMessage,
        )
    }
}
