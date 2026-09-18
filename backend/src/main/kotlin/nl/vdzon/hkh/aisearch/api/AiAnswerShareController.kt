package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import java.util.UUID
import nl.vdzon.hkh.aisearch.AiAnswerShareService
import nl.vdzon.hkh.aisearch.AiAnswerShareState
import nl.vdzon.hkh.aisearch.SharedAiAnswer
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
class AiAnswerShareController(private val service: AiAnswerShareService) {
    @GetMapping("/api/ai-search/answers/{answerId}/share")
    fun state(
        @CookieValue(name = VISITOR_COOKIE, required = false) cookie: String?,
        request: HttpServletRequest, response: HttpServletResponse,
        @PathVariable answerId: UUID,
    ): ResponseEntity<AiAnswerShareState> = privateResponse(
        service.state(anonymousVisitorId(cookie, request, response), answerId),
    )

    @PostMapping("/api/ai-search/answers/{answerId}/share")
    fun create(
        @CookieValue(name = VISITOR_COOKIE, required = false) cookie: String?,
        request: HttpServletRequest, response: HttpServletResponse,
        @PathVariable answerId: UUID,
    ): ResponseEntity<AiAnswerShareState> = privateResponse(
        service.create(anonymousVisitorId(cookie, request, response), answerId),
    )

    @DeleteMapping("/api/ai-search/answers/{answerId}/share")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun revoke(
        @CookieValue(name = VISITOR_COOKIE, required = false) cookie: String?,
        request: HttpServletRequest, response: HttpServletResponse,
        @PathVariable answerId: UUID,
    ) = service.revoke(anonymousVisitorId(cookie, request, response), answerId)

    // De ontvanger heeft geen cookie, account of toegang tot de oorspronkelijke sessie nodig.
    @GetMapping("/api/shared-answers/{token}")
    fun read(@PathVariable token: UUID, response: HttpServletResponse): ResponseEntity<SharedAiAnswer> {
        // Ook ingetrokken links mogen niet uit een browser- of proxycache terugkomen.
        response.setHeader("Cache-Control", "no-store")
        response.setHeader("X-Robots-Tag", "noindex, nofollow")
        return privateResponse(service.read(token))
    }

    private fun <T : Any> privateResponse(value: T): ResponseEntity<T> =
        ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(value)
}
