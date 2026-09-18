package nl.vdzon.hkh.aisearch

import java.time.Instant
import java.util.UUID
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import nl.vdzon.hkh.docexport.HtmlToPdfRenderer
import nl.vdzon.hkh.docexport.PdfRenderException
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

/**
 * Dekt de inhoud van de geëxporteerde PDF zonder database, zodat het bewijs voor titel,
 * antwoordtekst en bronnenlijst ook draait in omgevingen zonder Docker. De
 * Testcontainers-variant (`AiAnswerExportApiIntegrationTest`) dekt daarnaast het HTTP-contract
 * tegen een echte database.
 */
class AiAnswerExportServiceTest {
    private val repository = mock(AiSearchRepository::class.java)
    private val visitor = AiSearchIdentity(visitorId = UUID.randomUUID().toString())
    private val sessionId = UUID.randomUUID().toString()
    private val answerId = UUID.randomUUID().toString()

    @Test
    fun `the pdf contains the title, the rendered answer and the sources`() {
        val service = AiAnswerExportService(repository, HtmlToPdfRenderer())
        givenOwnedAnswer()

        val pdf = service.exportAnswer(visitor, answerId)

        assertEquals("antwoord-$answerId.pdf", pdf?.fileName)
        val bytes = pdf?.bytes ?: error("Verwachtte een PDF")
        assertTrue(bytes.size > 4, "De PDF is leeg")
        assertEquals("%PDF", bytes.decodeToString(0, 4))
        val text = Loader.loadPDF(bytes).use { PDFTextStripper().getText(it) }
        assertContains(text, "De geschiedenis van de Kerklaan")
        assertContains(text, "schepen en molenaar")
        assertContains(text, "beeldbank")
        assertContains(text, "https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42")
    }

    @Test
    fun `an answer of another visitor is not exported`() {
        val service = AiAnswerExportService(repository, HtmlToPdfRenderer())
        `when`(repository.findTurn(answerId)).thenReturn(completedTurn())
        `when`(repository.sessionExists(sessionId, visitor)).thenReturn(false)

        assertNull(service.exportAnswer(visitor, answerId))
    }

    @Test
    fun `an unknown, unfinished or empty answer is not exported`() {
        val service = AiAnswerExportService(repository, HtmlToPdfRenderer())
        `when`(repository.sessionExists(sessionId, visitor)).thenReturn(true)

        `when`(repository.findTurn(answerId)).thenReturn(null)
        assertNull(service.exportAnswer(visitor, answerId), "Onbekend antwoord")

        `when`(repository.findTurn(answerId)).thenReturn(completedTurn(status = AiTurnStatus.RUNNING))
        assertNull(service.exportAnswer(visitor, answerId), "Nog niet afgerond antwoord")

        `when`(repository.findTurn(answerId)).thenReturn(completedTurn(answerHtml = " "))
        assertNull(service.exportAnswer(visitor, answerId), "Leeg antwoord")

        assertNull(service.exportAnswer(visitor, "geen-uuid"), "Ongeldig id")
    }

    @Test
    fun `a render failure never yields partial bytes`() {
        val renderer = mock(HtmlToPdfRenderer::class.java)
        `when`(renderer.render(anyTitle(), anyBody(), anySources())).thenThrow(PdfRenderException("kapot"))
        val service = AiAnswerExportService(repository, renderer)
        givenOwnedAnswer()

        assertFailsWith<AiAnswerExportFailedException> { service.exportAnswer(visitor, answerId) }
    }

    private fun givenOwnedAnswer() {
        `when`(repository.findTurn(answerId)).thenReturn(completedTurn())
        `when`(repository.sessionExists(sessionId, visitor)).thenReturn(true)
    }

    private fun completedTurn(
        status: AiTurnStatus = AiTurnStatus.SUCCEEDED,
        answerHtml: String? = "<p>Hij was <strong>schepen en molenaar</strong> in Heemskerk.</p>",
    ) = AiSearchTurn(
        id = answerId,
        sessionId = sessionId,
        turnNumber = 1,
        question = "Wie was Jan Klaasz. Beemster?",
        runtimeJobId = null,
        status = status,
        progressPercent = 100,
        progressMessage = "Onderzoek afgerond",
        title = "De geschiedenis van de Kerklaan",
        answerHtml = answerHtml,
        sources = listOf(AiSourceRef("beeldbank", "42")),
        suggestedFollowUps = emptyList(),
        errorMessage = null,
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
        completedAt = Instant.EPOCH,
    )

    // Mockito-matchers geven in Kotlin een niet-nullable placeholder terug.
    private fun anyTitle(): String = org.mockito.ArgumentMatchers.anyString()

    private fun anyBody(): String = org.mockito.ArgumentMatchers.anyString()

    private fun anySources(): List<String> = org.mockito.ArgumentMatchers.anyList()
}
