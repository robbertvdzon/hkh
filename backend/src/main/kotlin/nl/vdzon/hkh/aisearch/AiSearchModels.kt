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
    val depth: AiResearchDepth = AiResearchDepth.DEFAULT,
    /** Bronnenlijst met beschrijvingen en beelden, los van de antwoordtekst; null bij oudere antwoorden. */
    val sourcesHtml: String? = null,
    /** Stand per zoekronde, zoals de agent die tijdens het onderzoek meldt. */
    val researchLog: List<AiResearchRound> = emptyList(),
    /** Geheim in de meld-URL van deze vraag; alleen de agent kent het. */
    val controlToken: String? = null,
    val steering: AiSteering = AiSteering(),
)

/** Verslag van één zoekronde, door de agent gemeld na afloop van die ronde. */
data class AiResearchRound(
    val round: Int,
    val sources: Int,
    val found: String,
    val next: List<String>,
    val reportedAt: Instant,
)

/**
 * Bijsturing door de gebruiker: stoppen met zoeken en het antwoord schrijven, of een aanwijzing
 * voor de volgende ronde. [deliveredAt] is het moment waarop de agent het heeft opgehaald.
 */
data class AiSteering(
    val stop: Boolean = false,
    val hint: String? = null,
    val deliveredAt: Instant? = null,
) {
    val pending: Boolean get() = (stop || !hint.isNullOrBlank()) && deliveredAt == null
}

/** Eigenaar van een zoekopdracht: een anonieme browser of een dossier. */
data class AiSearchOwner(
    val visitorId: String? = null,
    val dossierId: String? = null,
    val userId: String? = null,
    val userEmail: String? = null,
)

/** Wordt gepubliceerd zodra een dossiervraag succesvol is beantwoord. */
data class AiDossierTurnCompleted(val dossierId: String, val sessionId: String, val turnId: String)
