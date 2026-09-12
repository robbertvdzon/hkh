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
    /** Dossiercontext (titel, doel, feitenlijst) die bij het stellen van de vraag is vastgelegd. */
    val dossierContext: String? = null,
)

/** Eigenaar van een zoekopdracht: een anonieme browser of een dossier. */
data class AiSearchOwner(
    val visitorId: String? = null,
    val dossierId: String? = null,
    val userId: String? = null,
    val userEmail: String? = null,
)

/** Wordt gepubliceerd zodra een dossiervraag succesvol is beantwoord. */
data class AiDossierTurnCompleted(val dossierId: String, val sessionId: String, val turnId: String)
