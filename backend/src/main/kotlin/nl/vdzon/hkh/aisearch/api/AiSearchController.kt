package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import nl.vdzon.hkh.aisearch.AiSearchService
import nl.vdzon.hkh.aisearch.AiSearchSessionView
import nl.vdzon.hkh.aisearch.AiSearchSummaryView
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

data class AskAiRequest(@field:NotBlank @field:Size(min = 3, max = 1000) val question: String)

@RestController
@RequestMapping("/api/ai-search/sessions")
class AiSearchController(private val service: AiSearchService) {
    @GetMapping
    fun list(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
    ): List<AiSearchSummaryView> = service.list(anonymousVisitorId(visitorCookie, request, response))

    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun start(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        servletRequest: HttpServletRequest,
        response: HttpServletResponse,
        @Valid @RequestBody request: AskAiRequest,
    ): AiSearchSessionView = service.start(anonymousVisitorId(visitorCookie, servletRequest, response), request.question)

    @GetMapping("/{sessionId}")
    fun get(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.get(anonymousVisitorId(visitorCookie, request, response), sessionId)

    @PostMapping("/{sessionId}/questions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun followUp(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        servletRequest: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
        @Valid @RequestBody request: AskAiRequest,
    ): AiSearchSessionView = service.followUp(
        anonymousVisitorId(visitorCookie, servletRequest, response),
        sessionId,
        request.question,
    )

    @PostMapping("/{sessionId}/cancel")
    fun cancel(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.cancel(anonymousVisitorId(visitorCookie, request, response), sessionId)

    @DeleteMapping("/{sessionId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ) = service.delete(anonymousVisitorId(visitorCookie, request, response), sessionId)
}
