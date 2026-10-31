package nl.vdzon.hkh.workflowlog.api

import java.util.UUID
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.workflowlog.AppLogCursorInvalid
import nl.vdzon.hkh.workflowlog.AppLogOverviewRow
import nl.vdzon.hkh.workflowlog.AppLogPage
import nl.vdzon.hkh.workflowlog.WorkflowAppLogService
import nl.vdzon.hkh.workflowlog.WorkflowKind
import nl.vdzon.hkh.workflowlog.WorkflowLogService
import nl.vdzon.hkh.workflowlog.WorkflowLoginEntry
import nl.vdzon.hkh.workflowlog.WorkflowSessionDetail
import nl.vdzon.hkh.workflowlog.WorkflowSessionSummary
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

/** Beheer: het workflow-logboek met inlogpogingen en de sessies van de workflow-app, nieuwste eerst. */
@RestController
@RequestMapping("/api/admin/workflow-log")
class AdminWorkflowLogController(
    private val service: WorkflowLogService,
    private val appLogService: WorkflowAppLogService,
    private val authenticator: AdminAuthenticator,
) {
    @GetMapping("/logins")
    fun logins(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) limit: Int?,
        @RequestParam(required = false) source: String?,
    ): List<WorkflowLoginEntry> {
        authenticator.authenticate(authorization, previewHeader)
        return service.logins(limit ?: 200, source?.takeIf { it.isNotBlank() })
    }

    /** De bronnen (macbook, windows-laptop, hkh, ...) die iets hebben gemeld, om op te filteren. */
    @GetMapping("/sources")
    fun sources(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): List<String> {
        authenticator.authenticate(authorization, previewHeader)
        return service.sources()
    }

    @GetMapping("/sessions")
    fun sessions(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam kind: WorkflowKind,
        @RequestParam(required = false) limit: Int?,
        @RequestParam(required = false) source: String?,
    ): List<WorkflowSessionSummary> {
        authenticator.authenticate(authorization, previewHeader)
        return service.sessions(kind, limit ?: 200, source?.takeIf { it.isNotBlank() })
    }

    @GetMapping("/sessions/{id}")
    fun session(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @PathVariable id: UUID,
    ): WorkflowSessionDetail {
        authenticator.authenticate(authorization, previewHeader)
        return service.session(id) ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Sessie niet gevonden")
    }

    /** App-logregels (INFO en hoger), nieuwste eerst. `level` is een minimumniveau; `before` is de cursor uit `next` van de vorige pagina. */
    @GetMapping("/app-logs")
    fun appLogs(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) source: String?,
        @RequestParam(required = false) computer: String?,
        @RequestParam(required = false) level: String?,
        @RequestParam(required = false) version: String?,
        @RequestParam(required = false) q: String?,
        @RequestParam(required = false) before: String?,
        @RequestParam(required = false) limit: Int?,
    ): AppLogPage {
        authenticator.authenticate(authorization, previewHeader)
        return try {
            appLogService.entries(source, computer, level, version, q, before, limit ?: WorkflowAppLogService.DEFAULT_LIMIT)
        } catch (_: AppLogCursorInvalid) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Ongeldige cursor")
        }
    }

    /** Per bron en computer: versie, laatste melding en aantallen van de laatste 24 uur. */
    @GetMapping("/app-logs/overview")
    fun appLogOverview(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): List<AppLogOverviewRow> {
        authenticator.authenticate(authorization, previewHeader)
        return appLogService.overview()
    }

    /** De versies van de app waarvan er logregels zijn, voor het filter. */
    @GetMapping("/app-logs/versions")
    fun appLogVersions(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): List<String> {
        authenticator.authenticate(authorization, previewHeader)
        return appLogService.versions()
    }
}
