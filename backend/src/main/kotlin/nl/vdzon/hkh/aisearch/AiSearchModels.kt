package nl.vdzon.hkh.aisearch

import java.time.Instant

enum class AiTurnStatus { SUBMITTING, QUEUED, RUNNING, SUCCEEDED, FAILED, CANCELLED }

/**
 * Hoe een vraag onderzocht wordt. AGENT: de agent in de runtime zoekt zelf via de REST-API.
 * PIPELINE: de code bestuurt de rondes; het model beoordeelt kaarten en schrijft het antwoord.
 */
enum class AiResearchMethod {
    AGENT, PIPELINE;

    companion object {
        fun parse(value: String?): AiResearchMethod = entries.firstOrNull { it.name.equals(value?.trim(), ignoreCase = true) } ?: AGENT
    }
}

data class AiSourceRef(val collection: String, val ident: String)

/** Eén van de eerste treffers die de gebruiker te zien krijgt terwijl het model nog werkt. */
data class AiPreviewHit(
    val collection: String,
    val ident: String,
    val title: String,
    val year: Int?,
    val hasImage: Boolean,
    /** Publieke link naar de afbeelding, of null. */
    val imageUrl: String?,
    /** Publieke link naar het record, zoals de bronnen in een antwoord. */
    val url: String,
    /** Korte omschrijving: het fragment rond de treffer, anders het begin van de samenvatting. Foto's hebben vaak alleen een algemene titel. */
    val snippet: String? = null,
)

/** De eerste treffers en aantallen na de snelle zoekstap. */
data class AiSearchPreview(
    val total: Int,
    val perCollection: Map<String, Int>,
    val terms: List<String>,
    val hits: List<AiPreviewHit>,
)

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
    val method: AiResearchMethod = AiResearchMethod.AGENT,
    /** Jobs, modellen en tokens van het onderzoek (JSON), voor vergelijking; null bij oudere vragen. */
    val researchStats: String? = null,
    /** De testsetvraag waaruit deze beurt komt; null bij gewone vragen. */
    val benchmarkQuestionId: Long? = null,
    /** De schrijver meldde dat er meer te vertellen is dan het begrensde antwoord bevat, met één zin wat. */
    val moreAvailable: Boolean = false,
    val moreSummary: String? = null,
    /** Als deze beurt een uitwerking is: de beurt waarvan het antwoord en de bronnen de basis zijn. */
    val expandsTurnId: String? = null,
    /** Pijplijn: de eerste treffers, direct na de snelle zoekstap; null bij agent of oudere vragen. */
    val preview: AiSearchPreview? = null,
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
