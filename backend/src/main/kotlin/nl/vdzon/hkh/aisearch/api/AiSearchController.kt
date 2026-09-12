package nl.vdzon.hkh.aisearch.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import nl.vdzon.hkh.aisearch.AiSearchService
import nl.vdzon.hkh.aisearch.AiSearchSessionView
import org.springframework.http.HttpStatus
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
    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun start(@Valid @RequestBody request: AskAiRequest): AiSearchSessionView = service.start(request.question)

    @GetMapping("/{sessionId}")
    fun get(@PathVariable sessionId: String): AiSearchSessionView = service.get(sessionId)

    @PostMapping("/{sessionId}/questions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun followUp(@PathVariable sessionId: String, @Valid @RequestBody request: AskAiRequest): AiSearchSessionView =
        service.followUp(sessionId, request.question)

    @PostMapping("/{sessionId}/cancel")
    fun cancel(@PathVariable sessionId: String): AiSearchSessionView = service.cancel(sessionId)
}
