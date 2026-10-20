package nl.vdzon.hkh.aisearch.api

import nl.vdzon.hkh.aisearch.AiSearchOptionsView
import nl.vdzon.hkh.aisearch.AiSearchService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

/** Openbaar: wat de site vooraf moet weten om een vraag te stellen (methode, of de diepte te kiezen is). */
@RestController
@RequestMapping("/api/ai-search/options")
class AiSearchOptionsController(private val service: AiSearchService) {
    @GetMapping
    fun options(): AiSearchOptionsView = service.options()
}
