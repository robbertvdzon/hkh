package nl.vdzon.hkh.workflowlog

import java.time.Instant
import java.util.UUID
import tools.jackson.databind.JsonNode

/** Soort doorloop in de workflow-app: nieuwe bestanden in ZCBS zetten, of records aanpassen. */
enum class WorkflowKind { NEW_FILES, EDIT }

/** Toestand die de app zelf meldt; "verlaten" bepaalt het logboek zelf als er te lang niets meer binnenkomt. */
enum class WorkflowStatus { RUNNING, FINISHED, FAILED }

/** Een geslaagde of mislukte inlogpoging in de workflow-app. */
data class WorkflowLoginReport(
    val user: String?, val success: Boolean, val method: String, val detail: String?, val appVersion: String?, val computer: String?,
    /** Van welke bron de melding komt, zoals de beheerder die in de workflow-app heeft ingesteld (bijvoorbeeld macbook of hkh). */
    val source: String? = null,
)

/** Eén melding over een sessie: de samenvatting plus de volledige momentopname van de doorloop. */
data class WorkflowSessionReport(
    val id: UUID,
    val kind: WorkflowKind,
    val secret: String,
    val user: String?,
    val collection: String?,
    val appVersion: String?,
    val computer: String?,
    val source: String? = null,
    val phase: Int,
    val phaseCount: Int,
    val phaseLabel: String?,
    val status: WorkflowStatus,
    val fileCount: Int,
    /** Korte regel voor de tijdlijn; zonder tekst komt er alleen een regel bij als fase of status verandert. */
    val event: String?,
    /** Alles wat de app weet (instellingen, bestanden, stappen, logs); [null] laat de vorige momentopname staan. */
    val snapshot: JsonNode?,
)

data class WorkflowLoginEntry(
    val id: Long, val createdAt: Instant, val user: String?, val success: Boolean, val method: String, val detail: String?,
    val appVersion: String?, val computer: String?, val ip: String?, val source: String? = null,
)

data class WorkflowSessionSummary(
    val id: UUID,
    val kind: WorkflowKind,
    val createdAt: Instant,
    val updatedAt: Instant,
    val user: String?,
    val collection: String?,
    val phase: Int,
    val phaseCount: Int,
    val phaseLabel: String?,
    /** RUNNING, FINISHED, FAILED of ABANDONED (lang geen bericht meer terwijl hij nog bezig leek). */
    val status: String,
    val fileCount: Int,
    val updates: Int,
    val appVersion: String?,
    val computer: String?,
    val ip: String?,
    val source: String? = null,
)

data class WorkflowEventEntry(val id: Long, val createdAt: Instant, val phase: Int, val phaseLabel: String?, val status: String, val message: String)

data class WorkflowSessionDetail(val summary: WorkflowSessionSummary, val snapshot: JsonNode, val events: List<WorkflowEventEntry>)

/** Eén logregel van de workflow-app (INFO, WARN of ERROR). */
data class AppLogLine(val time: Instant, val level: String, val logger: String, val message: String)

/** Een pakketje logregels; [chunkId] is uniek per bron en computer, zodat een herhaling na een time-out niet dubbel wordt bewaard. */
data class AppLogChunk(val source: String, val computer: String, val appVersion: String?, val chunkId: String, val lines: List<AppLogLine>)

data class AppLogEntry(
    val id: Long, val time: Instant, val level: String, val logger: String, val message: String,
    val source: String, val computer: String, val appVersion: String?,
)

/** Een pagina logregels, nieuwste eerst; [next] is de ondoorzichtige cursor voor de volgende (oudere) pagina, of null. */
data class AppLogPage(val items: List<AppLogEntry>, val next: String?)

/** De stand van één computer in het app-log. */
data class AppLogOverviewRow(
    val source: String, val computer: String, val appVersion: String?, val lastSeen: Instant,
    val lines24h: Int, val warnings24h: Int, val errors24h: Int,
)
