package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import java.nio.charset.StandardCharsets.UTF_8
import nl.vdzon.hkh.aisearch.AiAnswerExportFailedException
import nl.vdzon.hkh.aisearch.AiAnswerExportService
import org.slf4j.LoggerFactory
import org.springframework.http.CacheControl
import org.springframework.http.ContentDisposition
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

/** Downloadt één antwoord met dezelfde account- of browsertoegang als de persoonlijke vragen. */
@RestController
@RequestMapping("/api/ai-search")
class AiAnswerExportController(private val exportService: AiAnswerExportService, private val identities: AiSearchIdentityResolver) {
    private val log = LoggerFactory.getLogger(javaClass)

    @GetMapping("/{answerId}/export/pdf")
    fun exportPdf(
        @CookieValue(name = VISITOR_COOKIE, required = false) visitorCookie: String?,
        request: HttpServletRequest,
        response: HttpServletResponse,
        @PathVariable answerId: String,
    ): ResponseEntity<ByteArray> {
        val visitorId = identities.resolve(visitorCookie, request, response)
        val pdf = try {
            exportService.exportAnswer(visitorId, answerId)
        } catch (error: AiAnswerExportFailedException) {
            // Geen lichaam: een half gevulde PDF is erger dan geen PDF.
            log.warn("PDF-export van antwoord {} is mislukt", answerId, error)
            return ResponseEntity.internalServerError().build()
        } ?: return ResponseEntity.notFound().build()

        return ResponseEntity.ok()
            .contentType(MediaType.APPLICATION_PDF)
            .header(
                HttpHeaders.CONTENT_DISPOSITION,
                ContentDisposition.attachment().filename(pdf.fileName, UTF_8).build().toString(),
            )
            .cacheControl(CacheControl.noStore())
            .contentLength(pdf.bytes.size.toLong())
            .body(pdf.bytes)
    }
}
