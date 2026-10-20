package nl.vdzon.hkh.requestlog.api

import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.requestlog.RequestLogEntry
import nl.vdzon.hkh.requestlog.RequestLogService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

/** Beheer: het logboek van verzoeken, nieuwste eerst. */
@RestController
@RequestMapping("/api/admin/requests")
class AdminRequestLogController(private val log: RequestLogService, private val authenticator: AdminAuthenticator) {
    @GetMapping
    fun recent(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
        @RequestParam(required = false) limit: Int?,
    ): List<RequestLogEntry> {
        authenticator.authenticate(authorization, previewHeader)
        return log.recent((limit ?: 200).coerceIn(1, 1000))
    }
}
