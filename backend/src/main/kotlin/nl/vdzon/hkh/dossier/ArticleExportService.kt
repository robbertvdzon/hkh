package nl.vdzon.hkh.dossier

import jakarta.annotation.PreDestroy
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import nl.vdzon.hkh.auth.AuthenticatedUser
import nl.vdzon.hkh.docexport.HtmlToPdfRenderer
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

/** Een volledig gerenderde artikel-PDF; half gevulde bytes verlaten deze service nooit. */
data class ArticlePdf(val fileName: String, val bytes: ByteArray) {
    override fun equals(other: Any?) = this === other ||
        (other is ArticlePdf && fileName == other.fileName && bytes.contentEquals(other.bytes))

    override fun hashCode() = 31 * fileName.hashCode() + bytes.contentHashCode()
}

/** Het renderen van het artikel is mislukt of duurde te lang. */
class ArticleExportFailedException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/**
 * Maakt on-demand een PDF van de huidige versie van één artikel. Er wordt niets opgeslagen of
 * gecachet. De HTML is exact de al door [MarkdownRenderer] gesaniteerde HTML die ook op het
 * artikelscherm staat; hier wordt niets opnieuw gerenderd of opnieuw gesaniteerd.
 */
@Service
class ArticleExportService(
    private val articles: ArticleService,
    private val renderer: HtmlToPdfRenderer,
) {
    private val executor = Executors.newVirtualThreadPerTaskExecutor()

    @PreDestroy
    fun close() = executor.shutdownNow()

    /**
     * Autorisatie loopt via exact hetzelfde pad als de bestaande artikel-endpoints: [ArticleService.get]
     * doet de dossier-toegangscontrole en gooit dezelfde foutstatus als daar.
     */
    fun exportArticle(dossierId: String, articleId: String, user: AuthenticatedUser): ArticlePdf {
        val article = articles.get(articleId, user)
        // Een artikel uit een ander dossier is via deze route net zo onvindbaar als een onbekend artikel.
        if (article.dossierId != dossierId) throw ResponseStatusException(HttpStatus.NOT_FOUND, "Artikel niet gevonden")
        val current = article.current
        return ArticlePdf(fileName(article.id), render(article.title, current.contentHtml, sourceLines(current)))
    }

    /** De bronvermeldingen zoals het artikelscherm ze toont: titel, verwijzing en detaillink. */
    private fun sourceLines(version: VersionView): List<String> =
        version.sources.map { source -> "${source.title} · ${source.collection}/${source.ident} — ${source.detailUrl}" }

    private fun render(title: String, bodyHtml: String, sources: List<String>): ByteArray {
        val task = executor.submit<ByteArray> { renderer.render(title, bodyHtml, sources) }
        return try {
            task.get(RENDER_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (error: Exception) {
            task.cancel(true)
            throw ArticleExportFailedException("Het artikel kon niet naar PDF worden omgezet.", error)
        }
    }

    private companion object {
        const val RENDER_TIMEOUT_SECONDS = 20L

        fun fileName(articleId: String) = "artikel-${articleId.replace(Regex("[^A-Za-z0-9._-]"), "-")}.pdf"
    }
}
