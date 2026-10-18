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
)

data class StructuredJobOutcome(
    val jobId: String,
    val result: JsonNode,
    val inputTokens: Long,
    val outputTokens: Long,
    val model: String,
)

class StructuredJobFailedException(val jobId: String?, message: String) : RuntimeException(message)

/**
 * Eén gestructureerde modelaanroep via de agent-runtime: job aanmaken, wachten, resultaat
 * teruggeven. De implementatie zit bij de runtime-client; deze interface houdt de
 * onderzoeksmodule testbaar zonder runtime.
 */
fun interface StructuredJobRunner {
    fun run(request: StructuredJobRequest): StructuredJobOutcome
}
