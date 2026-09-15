package nl.vdzon.hkh.dossier.api

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.auth.AuthenticatedUser
import nl.vdzon.hkh.auth.SessionService
import nl.vdzon.hkh.dossier.ArticleExportFailedException
import nl.vdzon.hkh.dossier.ArticleExportService
import nl.vdzon.hkh.dossier.ArticlePdf
import nl.vdzon.hkh.dossier.ArticleService
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.web.server.ResponseStatusException

/** Het HTTP-contract van `GET /api/dossiers/{dossierId}/articles/{articleId}/export/pdf`. */
class ArticleExportControllerTest {
    private val sessions = mock(SessionService::class.java)
    private val service = mock(ArticleService::class.java)
    private val exportService = mock(ArticleExportService::class.java)
    private val controller = ArticleController(sessions, service, exportService)

    private val user = AuthenticatedUser("u1", "onderzoeker@example.com", "Onderzoeker", false)
    private val token = "Bearer geldig"

    @Test
    fun `a rendered article is returned as a pdf attachment`() {
        val bytes = "%PDF-1.4 inhoud".toByteArray()
        `when`(sessions.requireUser(token)).thenReturn(user)
        `when`(exportService.exportArticle(DOSSIER_ID, ARTICLE_ID, user)).thenReturn(ArticlePdf("artikel-$ARTICLE_ID.pdf", bytes))

        val result = controller.exportPdf(token, DOSSIER_ID, ARTICLE_ID)

        assertEquals(HttpStatus.OK, result.statusCode)
        assertEquals(MediaType.APPLICATION_PDF, result.headers.contentType)
        assertEquals(bytes.size.toLong(), result.headers.contentLength)
        assertTrue(
            result.headers.getFirst(HttpHeaders.CONTENT_DISPOSITION)
                ?.startsWith("attachment; filename=\"artikel-$ARTICLE_ID.pdf\"") == true,
            "Verwachtte een attachment met de artikelbestandsnaam",
        )
        assertEquals("no-store", result.headers.cacheControl)
        assertEquals(bytes.toList(), result.body?.toList())
    }

    @Test
    fun `a render failure gives an error status without a body`() {
        `when`(sessions.requireUser(token)).thenReturn(user)
        `when`(exportService.exportArticle(DOSSIER_ID, ARTICLE_ID, user)).thenThrow(ArticleExportFailedException("mislukt"))

        val result = controller.exportPdf(token, DOSSIER_ID, ARTICLE_ID)

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, result.statusCode)
        assertNull(result.body)
    }

    @Test
    fun `a user without dossier access gets the same status as on the existing article endpoint`() {
        `when`(sessions.requireUser(token)).thenReturn(user)
        `when`(service.get(ARTICLE_ID, user)).thenThrow(ResponseStatusException(HttpStatus.NOT_FOUND, "Artikel niet gevonden"))
        `when`(exportService.exportArticle(DOSSIER_ID, ARTICLE_ID, user))
            .thenThrow(ResponseStatusException(HttpStatus.NOT_FOUND, "Artikel niet gevonden"))

        val existing = assertFailsWith<ResponseStatusException> { controller.get(token, ARTICLE_ID) }
        val export = assertFailsWith<ResponseStatusException> { controller.exportPdf(token, DOSSIER_ID, ARTICLE_ID) }

        assertEquals(existing.statusCode, export.statusCode)
    }

    @Test
    fun `a request without session gets the same status as on the existing article endpoint`() {
        `when`(sessions.requireUser(null)).thenThrow(ResponseStatusException(HttpStatus.UNAUTHORIZED, "Inloggen is vereist"))

        val existing = assertFailsWith<ResponseStatusException> { controller.get(null, ARTICLE_ID) }
        val export = assertFailsWith<ResponseStatusException> { controller.exportPdf(null, DOSSIER_ID, ARTICLE_ID) }

        assertEquals(existing.statusCode, export.statusCode)
        assertEquals(HttpStatus.UNAUTHORIZED, export.statusCode)
    }

    private companion object {
        const val DOSSIER_ID = "d1"
        const val ARTICLE_ID = "a1"
    }
}
