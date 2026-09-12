package nl.vdzon.hkh.dossier.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import nl.vdzon.hkh.aisearch.AiSearchSessionView
import nl.vdzon.hkh.aisearch.AiSearchSummaryView
import nl.vdzon.hkh.auth.SessionService
import nl.vdzon.hkh.dossier.DossierDetailView
import nl.vdzon.hkh.dossier.DossierRole
import nl.vdzon.hkh.dossier.DossierService
import nl.vdzon.hkh.dossier.DossierSummaryView
import java.util.UUID
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

data class DossierRequest(
    @field:NotBlank @field:Size(max = 200) val title: String,
    @field:Size(max = 2000) val goal: String = "",
)

data class MemberRequest(val role: DossierRole)

data class TransferRequest(@field:NotBlank val email: String)

data class FactSheetRequest(@field:Size(max = 60_000) val markdown: String)

data class QuestionRequest(@field:NotBlank @field:Size(min = 3, max = 1000) val question: String)

data class AdoptRequest(@field:NotBlank val sessionId: String)

@RestController
@RequestMapping("/api/dossiers")
class DossierController(
    private val sessions: SessionService,
    private val service: DossierService,
) {
    @GetMapping
    fun list(@RequestHeader(AUTH, required = false) authorization: String?): List<DossierSummaryView> =
        service.list(sessions.requireUser(authorization))

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @Valid @RequestBody request: DossierRequest,
    ): DossierDetailView = service.create(sessions.requireUser(authorization), request.title, request.goal)

    @GetMapping("/{dossierId}")
    fun get(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
    ): DossierDetailView = service.detail(dossierId, sessions.requireUser(authorization))

    @PutMapping("/{dossierId}")
    fun update(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: DossierRequest,
    ): DossierDetailView = service.update(dossierId, sessions.requireUser(authorization), request.title, request.goal)

    @DeleteMapping("/{dossierId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
    ) = service.delete(dossierId, sessions.requireUser(authorization))

    // ---- Leden ----

    @PutMapping("/{dossierId}/members/{email}")
    fun setMember(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable email: String,
        @Valid @RequestBody request: MemberRequest,
    ): DossierDetailView = service.setMember(dossierId, sessions.requireUser(authorization), email, request.role)

    @DeleteMapping("/{dossierId}/members/{email}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun removeMember(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable email: String,
    ) = service.removeMember(dossierId, sessions.requireUser(authorization), email)

    @PostMapping("/{dossierId}/transfer")
    fun transfer(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: TransferRequest,
    ): DossierDetailView = service.transferOwnership(dossierId, sessions.requireUser(authorization), request.email)

    // ---- Feitenlijst ----

    @PutMapping("/{dossierId}/fact-sheet")
    fun updateFactSheet(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: FactSheetRequest,
    ): DossierDetailView = service.updateFactSheet(dossierId, sessions.requireUser(authorization), request.markdown)

    @PostMapping("/{dossierId}/fact-sheet/refresh")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun refreshFactSheet(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
    ): DossierDetailView = service.refreshFactSheet(dossierId, sessions.requireUser(authorization))

    // ---- Vragen ----

    @GetMapping("/{dossierId}/questions")
    fun questions(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
    ): List<AiSearchSummaryView> = service.questions(dossierId, sessions.requireUser(authorization))

    @PostMapping("/{dossierId}/questions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun ask(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: QuestionRequest,
    ): AiSearchSessionView = service.ask(dossierId, sessions.requireUser(authorization), request.question)

    @PostMapping("/{dossierId}/questions/adopt")
    fun adopt(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: AdoptRequest,
    ): AiSearchSessionView {
        val visitorId = runCatching { UUID.fromString(visitorCookie) }.getOrNull()?.toString()
        return service.adoptQuestion(dossierId, sessions.requireUser(authorization), visitorId, request.sessionId)
    }

    @GetMapping("/{dossierId}/questions/{sessionId}")
    fun question(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.question(dossierId, sessions.requireUser(authorization), sessionId)

    @PostMapping("/{dossierId}/questions/{sessionId}/questions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun followUp(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable sessionId: String,
        @Valid @RequestBody request: QuestionRequest,
    ): AiSearchSessionView = service.followUp(dossierId, sessions.requireUser(authorization), sessionId, request.question)

    @PostMapping("/{dossierId}/questions/{sessionId}/cancel")
    fun cancel(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.cancelQuestion(dossierId, sessions.requireUser(authorization), sessionId)

    @DeleteMapping("/{dossierId}/questions/{sessionId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteQuestion(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @PathVariable sessionId: String,
    ) = service.deleteQuestion(dossierId, sessions.requireUser(authorization), sessionId)

    private companion object {
        const val AUTH = "Authorization"
        const val VISITOR_COOKIE = "hkh_ai_visitor"
    }
}
