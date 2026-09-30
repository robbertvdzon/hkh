package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletResponse
import java.time.Instant
import nl.vdzon.hkh.aisearch.AiResearchRound
import nl.vdzon.hkh.aisearch.AiSearchService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException
import tools.jackson.databind.JsonNode

/** Antwoord aan de agent: stoppen en schrijven, en/of een aanwijzing voor de volgende ronde. */
data class ResearchControlResponse(val stop: Boolean, val hint: String?)

/**
 * Meldpunt voor de digitale onderzoeker zelf. De URL bevat een geheim dat alleen in de prompt van
 * die ene vraag staat; er is geen sessie of account. De agent stuurt per afgeronde ronde zijn stand
 * en krijgt de bijsturing van de gebruiker terug.
 */
@RestController
class AiResearchControlController(private val service: AiSearchService) {
    @PostMapping("/api/ai-search/research/{turnId}/{token}/rounds")
    fun reportRound(
        @PathVariable turnId: String,
        @PathVariable token: String,
        @RequestBody body: JsonNode,
        response: HttpServletResponse,
    ): ResearchControlResponse {
        response.setHeader("Cache-Control", "no-store")
        val round = AiResearchRound(
            round = body.path("ronde").asInt(body.path("round").asInt(0)).coerceIn(0, 999),
            sources = body.path("bronnen").asInt(body.path("sources").asInt(0)).coerceIn(0, 100_000),
            found = body.path("gevonden").asText(body.path("found").asText("")).take(600),
            next = (body.path("volgende").takeIf { it.isArray } ?: body.path("next")).let { array ->
                buildList { for (item in array) item.asText().trim().takeIf(String::isNotEmpty)?.let { add(it.take(120)) } }.take(10)
            },
            reportedAt = Instant.now(),
        )
        val steering = service.reportRound(turnId, token, round)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Onbekend onderzoek")
        return ResearchControlResponse(stop = steering.stop, hint = steering.hint?.takeIf(String::isNotBlank))
    }
}
