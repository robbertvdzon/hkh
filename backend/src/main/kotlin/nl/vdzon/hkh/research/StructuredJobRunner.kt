package nl.vdzon.hkh.research

import tools.jackson.databind.JsonNode

/** Rol van een modelaanroep; per rol is in het beheerscherm een model te kiezen. */
enum class AiRole { AGENT, EXTRACTION, RESEARCH, WRITER }

data class StructuredJobRequest(
    val idempotencyKey: String,
    val role: AiRole,
    val instruction: String,
    val resultSchema: JsonNode,
    val executionTimeoutSeconds: Int,
    /** Wordt tijdens het wachten gepeild; true breekt de job af (de runtime-job wordt geannuleerd). */
    val cancelled: () -> Boolean = { false },
)

data class StructuredJobOutcome(
    val jobId: String,
    val result: JsonNode,
    val inputTokens: Long,
    val outputTokens: Long,
    val model: String,
)

open class StructuredJobFailedException(val jobId: String?, message: String) : RuntimeException(message)

/** De aanroeper heeft de job afgebroken (gebruiker stopte het onderzoek). */
class StructuredJobCancelledException(jobId: String?) : StructuredJobFailedException(jobId, "De opdracht is afgebroken.")

/**
 * Eén gestructureerde modelaanroep via de agent-runtime: job aanmaken, wachten, resultaat
 * teruggeven. De implementatie zit bij de runtime-client; deze interface houdt de
 * onderzoeksmodule testbaar zonder runtime.
 */
fun interface StructuredJobRunner {
    fun run(request: StructuredJobRequest): StructuredJobOutcome
}
