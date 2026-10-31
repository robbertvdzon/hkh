package nl.vdzon.hkh.workflowlog.api

import java.util.UUID
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
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
class AdminWorkflowLogController(private val service: WorkflowLogService, private val authenticator: AdminAuthenticator) {
    @GetMapping("/logins")
    fun logins(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) limit: Int?,
    ): List<WorkflowLoginEntry> {
        authenticator.authenticate(authorization, previewHeader)
        return service.logins(limit ?: 200)
    }

    @GetMapping("/sessions")
    fun sessions(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam kind: WorkflowKind,
        @RequestParam(required = false) limit: Int?,
    ): List<WorkflowSessionSummary> {
        authenticator.authenticate(authorization, previewHeader)
        return service.sessions(kind, limit ?: 200)
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
}
