package nl.vdzon.hkh.aisearch.api

import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.aisearch.AiAnswerExportFailedException
import nl.vdzon.hkh.aisearch.AiAnswerExportService
import nl.vdzon.hkh.aisearch.AiSearchIdentity
import nl.vdzon.hkh.aisearch.AiSearchRepository
import nl.vdzon.hkh.auth.SessionService
import nl.vdzon.hkh.aisearch.AiAnswerPdf
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class AiAnswerExportControllerTest {
    private val service = mock(AiAnswerExportService::class.java)
    private val controller = AiAnswerExportController(service, AiSearchIdentityResolver(mock(SessionService::class.java), mock(AiSearchRepository::class.java)))
    private val request = MockHttpServletRequest().apply { serverName = "hkh.vdzonsoftware.nl" }
    private val response = MockHttpServletResponse()
    private val visitor = UUID.randomUUID().toString()
    private val answerId = UUID.randomUUID().toString()

    @Test
    fun `a rendered answer is returned as a pdf attachment`() {
        val bytes = "%PDF-1.4 inhoud".toByteArray()
        `when`(service.exportAnswer(AiSearchIdentity(visitorId = visitor), answerId)).thenReturn(AiAnswerPdf("antwoord-$answerId.pdf", bytes))

        val result = controller.exportPdf(visitor, request, response, answerId)

        assertEquals(HttpStatus.OK, result.statusCode)
        assertEquals(MediaType.APPLICATION_PDF, result.headers.contentType)
        assertEquals(bytes.size.toLong(), result.headers.contentLength)
        assertTrue(
            result.headers.getFirst(HttpHeaders.CONTENT_DISPOSITION)
                ?.startsWith("attachment; filename=\"antwoord-$answerId.pdf\"") == true,
            "Verwachtte een attachment met de antwoordbestandsnaam",
        )
        assertEquals("no-store", result.headers.cacheControl)
        assertEquals(bytes.toList(), result.body?.toList())
    }

    @Test
    fun `an unknown answer gives a not found without a body`() {
        `when`(service.exportAnswer(AiSearchIdentity(visitorId = visitor), answerId)).thenReturn(null)

        val result = controller.exportPdf(visitor, request, response, answerId)

        assertEquals(HttpStatus.NOT_FOUND, result.statusCode)
        assertNull(result.body)
    }

    @Test
    fun `a render failure gives an error status without a body`() {
        `when`(service.exportAnswer(AiSearchIdentity(visitorId = visitor), answerId)).thenThrow(AiAnswerExportFailedException("mislukt"))

        val result = controller.exportPdf(visitor, request, response, answerId)

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, result.statusCode)
        assertNull(result.body)
    }

    @Test
    fun `a visit without cookie gets the same fresh anonymous cookie as the search routes`() {
        val result = controller.exportPdf(null, request, response, answerId)

        val cookie = response.getHeader(HttpHeaders.SET_COOKIE)
        assertTrue(cookie?.startsWith("$VISITOR_COOKIE=") == true, "Verwachtte een nieuwe bezoekerscookie")
        assertTrue(cookie?.contains("HttpOnly") == true)
        assertTrue(cookie?.contains("Max-Age=31536000") == true)
        // Een verse bezoeker bezit nog geen antwoorden, dus de export is niet gevonden.
        assertEquals(HttpStatus.NOT_FOUND, result.statusCode)
    }
}
