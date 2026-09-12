package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import nl.vdzon.hkh.aisearch.AiSearchService
import nl.vdzon.hkh.aisearch.AiSearchSessionView
import nl.vdzon.hkh.aisearch.AiSearchSummaryView
import java.time.Duration
import java.util.UUID
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseCookie
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
    ): List<AiSearchSummaryView> = service.list(visitorId(visitorCookie, request, response))

    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun start(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        servletRequest: HttpServletRequest,
        response: HttpServletResponse,
        @Valid @RequestBody request: AskAiRequest,
    ): AiSearchSessionView = service.start(visitorId(visitorCookie, servletRequest, response), request.question)

    @GetMapping("/{sessionId}")
    fun get(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.get(visitorId(visitorCookie, request, response), sessionId)

    @PostMapping("/{sessionId}/questions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun followUp(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        servletRequest: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
        @Valid @RequestBody request: AskAiRequest,
    ): AiSearchSessionView = service.followUp(
        visitorId(visitorCookie, servletRequest, response),
        sessionId,
        request.question,
    )

    @PostMapping("/{sessionId}/cancel")
    fun cancel(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ): AiSearchSessionView = service.cancel(visitorId(visitorCookie, request, response), sessionId)

    @DeleteMapping("/{sessionId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable sessionId: String,
    ) = service.delete(visitorId(visitorCookie, request, response), sessionId)

    private fun visitorId(
        cookieValue: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
    ): String {
        val existing = runCatching { UUID.fromString(cookieValue) }.getOrNull()
        val id = existing ?: UUID.randomUUID()
        if (existing == null) {
            val secure = request.isSecure || request.getHeader("X-Forwarded-Proto").equals("https", ignoreCase = true)
            response.addHeader(
                HttpHeaders.SET_COOKIE,
                ResponseCookie.from(VISITOR_COOKIE, id.toString())
                    .httpOnly(true)
                    .secure(secure)
                    .sameSite("Lax")
                    .path("/")
                    .maxAge(Duration.ofDays(365))
                    .build()
                    .toString(),
            )
        }
        return id.toString()
    }

    private companion object {
        const val VISITOR_COOKIE = "hkh_ai_visitor"
    }
}
