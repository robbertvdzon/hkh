package nl.vdzon.hkh.aisearch

import java.time.Instant

enum class AiTurnStatus { SUBMITTING, QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELLED }

data class AiSourceRef(val collection: String, val ident: String)

data class AiSearchTurn(
    val id: String,
    val sessionId: String,
    val turnNumber: Int,
    val question: String,
    val runtimeJobId: String?,
    val status: AiTurnStatus,
    val progressPercent: Int?,
    val progressMessage: String?,
    val title: String?,
    val answerHtml: String?,
    val sources: List<AiSourceRef>,
    val suggestedFollowUps: List<String>,
    val errorMessage: String?,
    val createdAt: Instant,
    val updatedAt: Instant,
    val completedAt: Instant?,
)
