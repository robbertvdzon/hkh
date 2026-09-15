package nl.vdzon.hkh.dossier

import java.time.Instant
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import nl.vdzon.hkh.auth.AuthenticatedUser
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionSearchService
import nl.vdzon.hkh.docexport.HtmlToPdfRenderer
import nl.vdzon.hkh.docexport.PdfRenderException
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

/**
 * Dekt de inhoud van de artikel-PDF en het autorisatiepad zonder database, zodat het bewijs ook
 * draait in omgevingen zonder Docker. De service draait op een echte [ArticleService] met een
 * echte [MarkdownRenderer], zodat de export aantoonbaar dezelfde gesaniteerde HTML gebruikt als
 * het artikelscherm. De Testcontainers-variant (`ArticleExportApiIntegrationTest`) dekt daarnaast
 * het HTTP-contract tegen een echte database.
 */
class ArticleExportServiceTest {
    private val repository = mock(DossierRepository::class.java)
    private val dossiers = mock(DossierService::class.java)
    private val collectionSearch = mock(CollectionSearchService::class.java)
    private val markdown = MarkdownRenderer(collectionSearch)
    private val jobs = mock(DossierAiJobs::class.java)
    private val articles = ArticleService(repository, dossiers, markdown, jobs)

    private val user = AuthenticatedUser("u1", "onderzoeker@example.com", "Onderzoeker", false)

    @Test
    fun `the pdf contains the title, the rendered content and the sources`() {
        val service = ArticleExportService(articles, HtmlToPdfRenderer())
        givenAccessibleArticle()

        val pdf = service.exportArticle(DOSSIER_ID, ARTICLE_ID, user)

        assertEquals("artikel-$ARTICLE_ID.pdf", pdf.fileName)
        assertTrue(pdf.bytes.size > 4, "De PDF is leeg")
        assertEquals("%PDF", pdf.bytes.decodeToString(0, 4))
        val text = Loader.loadPDF(pdf.bytes).use { PDFTextStripper().getText(it) }
        assertContains(text, "Jan Klaasz. Beemster")
        assertContains(text, "schepen en molenaar")
        assertContains(text, "Bronnen")
        assertContains(text, "Resolutieboek ambachtsheerlijkheid Heemskerk")
        assertContains(text, "beeldbank/42")
        assertContains(text, "objecten/beeldbank/42")
    }

    @Test
    fun `the exported body is exactly the sanitised html of the article screen`() {
        val renderer = RecordingRenderer()
        val service = ArticleExportService(articles, renderer)
        givenAccessibleArticle()
        val screen = articles.get(ARTICLE_ID, user).current

        service.exportArticle(DOSSIER_ID, ARTICLE_ID, user)

        assertEquals(ARTICLE_TITLE, renderer.title)
        assertEquals(screen.contentHtml, renderer.body, "De export moet exact de schermversie van de HTML gebruiken")
        val body = renderer.body.orEmpty()
        assertFalse(body.contains("<script", ignoreCase = true), "Er mag geen script in de PDF terechtkomen")
        assertFalse(body.contains("<img", ignoreCase = true), "Er mag geen niet-gesaniteerde afbeelding in de PDF terechtkomen")
        assertEquals(
            listOf("Resolutieboek ambachtsheerlijkheid Heemskerk · beeldbank/42 — https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42"),
            renderer.sources,
        )
    }

    @Test
    fun `a user without dossier access gets the same status as on the existing article endpoint`() {
        val service = ArticleExportService(articles, HtmlToPdfRenderer())
        `when`(repository.findArticle(ARTICLE_ID)).thenReturn(article())
        `when`(dossiers.access(DOSSIER_ID, user)).thenThrow(ResponseStatusException(HttpStatus.NOT_FOUND, "Dossier niet gevonden"))

        val existing = assertFailsWith<ResponseStatusException> { articles.get(ARTICLE_ID, user) }
        val export = assertFailsWith<ResponseStatusException> { service.exportArticle(DOSSIER_ID, ARTICLE_ID, user) }

        assertEquals(existing.statusCode, export.statusCode)
    }

    @Test
    fun `an article of another dossier is not found`() {
        val service = ArticleExportService(articles, HtmlToPdfRenderer())
        givenAccessibleArticle()

        val error = assertFailsWith<ResponseStatusException> { service.exportArticle("ander-dossier", ARTICLE_ID, user) }

        assertEquals(HttpStatus.NOT_FOUND, error.statusCode)
    }

    @Test
    fun `a render failure never yields partial bytes`() {
        val service = ArticleExportService(articles, RecordingRenderer(failing = true))
        givenAccessibleArticle()

        assertFailsWith<ArticleExportFailedException> { service.exportArticle(DOSSIER_ID, ARTICLE_ID, user) }
    }

    private fun givenAccessibleArticle() {
        val article = article()
        `when`(repository.findArticle(ARTICLE_ID)).thenReturn(article)
        `when`(dossiers.access(DOSSIER_ID, user)).thenReturn(DossierAccess(dossier(), DossierRole.READER))
        `when`(repository.versions(ARTICLE_ID)).thenReturn(listOf(version()))
        `when`(repository.openProposal(ARTICLE_ID)).thenReturn(null)
        `when`(collectionSearch.detail("beeldbank", "42")).thenReturn(collectionItem())
    }

    private fun article() = Article(
        id = ARTICLE_ID,
        dossierId = DOSSIER_ID,
        title = ARTICLE_TITLE,
        createdByEmail = user.email,
        currentVersionId = VERSION_ID,
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
    )

    private fun version() = ArticleVersion(
        id = VERSION_ID,
        articleId = ARTICLE_ID,
        versionNumber = 2,
        title = ARTICLE_TITLE,
        contentMarkdown = MARKDOWN,
        authorKind = AuthorKind.USER,
        authorEmail = user.email,
        aiInstruction = null,
        changeSummary = "Handmatig bewerkt",
        state = VersionState.ACCEPTED,
        basedOnVersionId = null,
        runtimeJobId = null,
        jobStatus = null,
        progressMessage = null,
        errorMessage = null,
        createdAt = Instant.EPOCH,
        decidedAt = null,
        decidedByEmail = null,
    )

    private fun dossier() = Dossier(
        id = DOSSIER_ID,
        ownerUserId = "owner",
        ownerEmail = "owner@example.com",
        title = "De Kerklaan",
        goal = "Artikel voor het verenigingsblad",
        factSheetMarkdown = "",
        factSheetStatus = FactSheetStatus.IDLE,
        factSheetJobId = null,
        factSheetDirty = false,
        factSheetError = null,
        factSheetUpdatedAt = null,
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
    )

    private fun collectionItem() = CollectionItem(
        id = 1,
        collection = "beeldbank",
        ident = "42",
        title = "Resolutieboek ambachtsheerlijkheid Heemskerk",
        description = "Notulen van de schepenbank.",
        year = 1748,
        imageUrl = null,
        pdfUrl = null,
        detailUrl = "https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42",
        fields = emptyMap(),
        isComplete = true,
        scrapedAt = Instant.EPOCH,
    )

    /** Legt vast wat de export aan de gedeelde renderer meegeeft, en kan een renderfout simuleren. */
    private class RecordingRenderer(private val failing: Boolean = false) : HtmlToPdfRenderer() {
        var title: String? = null
        var body: String? = null
        var sources: List<String> = emptyList()

        override fun render(title: String, bodyHtml: String, sources: List<String>): ByteArray {
            this.title = title
            this.body = bodyHtml
            this.sources = sources
            if (failing) throw PdfRenderException("Gesimuleerde renderfout")
            return "%PDF-gerenderd".toByteArray()
        }
    }

    private companion object {
        const val DOSSIER_ID = "d1"
        const val ARTICLE_ID = "a1"
        const val VERSION_ID = "v2"
        const val ARTICLE_TITLE = "Jan Klaasz. Beemster"
        val MARKDOWN = """
            Jan Klaasz. Beemster was **schepen en molenaar** in Heemskerk.

            <script>alert('xss')</script>

            ![Losse afbeelding](https://elders.example/foto.png)

            Zie het [Resolutieboek ambachtsheerlijkheid Heemskerk](hkh:beeldbank/42).
        """.trimIndent()
    }
}
