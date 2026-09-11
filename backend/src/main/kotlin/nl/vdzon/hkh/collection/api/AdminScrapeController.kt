package nl.vdzon.hkh.collection.api

import java.time.Instant
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.collection.CollectionScrapeService
import nl.vdzon.hkh.collection.ScrapeAlreadyRunningException
import nl.vdzon.hkh.collection.ScrapeRun
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

data class ScrapeRunResponse(
    val id: Long,
    val status: String,
    val running: Boolean,
    val startedBy: String,
    val force: Boolean,
    val startedAt: Instant,
    val finishedAt: Instant?,
    val total: Int,
    val processed: Int,
    val skipped: Int,
    val failed: Int,
    val currentCollection: String?,
    val message: String?,
    val perCollection: Map<String, Int>,
)

@RestController
@RequestMapping("/api/admin/collections/scrape")
class AdminScrapeController(
    private val service: CollectionScrapeService,
    private val authenticator: AdminAuthenticator,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun start(
        @RequestParam(name = "force", defaultValue = "false") force: Boolean,
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): ScrapeRunResponse {
        val admin = authenticator.authenticate(authorization, previewHeader)
        return try {
            service.start(admin.email, force).toResponse(running = true)
        } catch (ex: ScrapeAlreadyRunningException) {
            throw ResponseStatusException(HttpStatus.CONFLICT, ex.message)
        }
    }

    @GetMapping("/status")
    fun status(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): ScrapeRunResponse? {
        authenticator.authenticate(authorization, previewHeader)
        return service.status()?.toResponse(running = service.isRunning())
    }
}

private fun ScrapeRun.toResponse(running: Boolean) = ScrapeRunResponse(
    id = id,
    status = status.name,
    running = running,
    startedBy = startedBy,
    force = force,
    startedAt = startedAt,
    finishedAt = finishedAt,
    total = total,
    processed = processed,
    skipped = skipped,
    failed = failed,
    currentCollection = currentCollection,
    message = message,
    perCollection = perCollection,
)
