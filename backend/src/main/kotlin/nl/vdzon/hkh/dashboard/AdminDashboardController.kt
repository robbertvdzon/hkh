package nl.vdzon.hkh.dashboard

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import nl.vdzon.hkh.aisearch.AgentRuntimeClient
import nl.vdzon.hkh.aisearch.AiModelSettings
import nl.vdzon.hkh.aisearch.AiResearchMethod
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.collection.CollectionScrapeService
import nl.vdzon.hkh.collection.CollectionSearchService
import nl.vdzon.hkh.requestlog.RequestLogService
import nl.vdzon.hkh.requestlog.UsagePeriod
import nl.vdzon.hkh.research.AiRole
import nl.vdzon.hkh.research.CARD_EXTRACTION_VERSION
import nl.vdzon.hkh.research.CardStats
import nl.vdzon.hkh.research.DocumentCardStore
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class DashboardRole(val role: AiRole, val label: String, val model: String)

data class DashboardAi(
    val method: AiResearchMethod,
    val roles: List<DashboardRole>,
    val writeBudgetChars: Int,
    val runtimeConfigured: Boolean,
    val runtimeReachable: Boolean,
    val workersOnline: Int,
)

data class DashboardCollectionCount(val collection: String, val count: Long)

data class DashboardRun(
    val status: String,
    val mode: String,
    val startedAt: Instant,
    val finishedAt: Instant?,
    val total: Int,
    val processed: Int,
    val failed: Int,
    val message: String?,
)

data class DashboardCollection(
    val totalRecords: Long,
    val collections: List<DashboardCollectionCount>,
    val running: Boolean,
    val lastRun: DashboardRun?,
    val cards: CardStats,
)

data class DashboardUsage(val today: UsagePeriod, val last7Days: UsagePeriod, val last30Days: UsagePeriod, val retentionDays: Int)

data class DashboardView(val ai: DashboardAi, val collection: DashboardCollection, val usage: DashboardUsage)

/** Beheer: de statusgegevens voor de startpagina in één aanroep. */
@RestController
@RequestMapping("/api/admin/dashboard")
class AdminDashboardController(
    private val settings: AiModelSettings,
    private val runtime: AgentRuntimeClient,
    private val scrape: CollectionScrapeService,
    private val search: CollectionSearchService,
    private val cards: DocumentCardStore,
    private val requestLog: RequestLogService,
    private val authenticator: AdminAuthenticator,
) {
    @GetMapping
    fun dashboard(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): DashboardView {
        authenticator.authenticate(authorization, previewHeader)
        return DashboardView(ai(), collection(), usage())
    }

    private fun ai(): DashboardAi {
        val catalog = runCatching { runtime.executionOptions() }
        return DashboardAi(
            method = settings.method(),
            roles = listOf(
                DashboardRole(AiRole.AGENT, "Agent", settings.execution(AiRole.AGENT).model),
                DashboardRole(AiRole.RESEARCH, "Richten", settings.execution(AiRole.RESEARCH).model),
                DashboardRole(AiRole.WRITER, "Schrijven", settings.execution(AiRole.WRITER).model),
                DashboardRole(AiRole.EXTRACTION, "Kaarten maken", settings.execution(AiRole.EXTRACTION).model),
            ),
            writeBudgetChars = settings.writeBudget().chars,
            runtimeConfigured = runtime.isConfigured(),
            runtimeReachable = catalog.isSuccess,
            workersOnline = catalog.getOrNull()?.maxOfOrNull { it.onlineWorkers } ?: 0,
        )
    }

    private fun collection(): DashboardCollection {
        val run = scrape.status()
        return DashboardCollection(
            totalRecords = search.total(),
            collections = search.collections().map { DashboardCollectionCount(it.collection, it.count) },
            running = scrape.isRunning(),
            lastRun = run?.let { DashboardRun(it.status.name, it.mode.name, it.startedAt, it.finishedAt, it.total, it.processed, it.failed, it.message) },
            cards = cards.stats(CARD_EXTRACTION_VERSION),
        )
    }

    private fun usage(): DashboardUsage {
        val zone = ZoneId.of("Europe/Amsterdam")
        val startOfToday = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val now = Instant.now()
        return DashboardUsage(
            today = requestLog.usage(startOfToday),
            last7Days = requestLog.usage(now.minusSeconds(7 * 86_400)),
            last30Days = requestLog.usage(now.minusSeconds(30 * 86_400)),
            retentionDays = RequestLogService.RETENTION_DAYS,
        )
    }
}
