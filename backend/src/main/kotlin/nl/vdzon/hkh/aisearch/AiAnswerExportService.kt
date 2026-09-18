package nl.vdzon.hkh.aisearch

import jakarta.annotation.PreDestroy
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import nl.vdzon.hkh.collection.CollectionLinks
import nl.vdzon.hkh.docexport.HtmlToPdfRenderer
import org.springframework.stereotype.Service

/** Een volledig gegenereerde PDF; half gevulde bytes verlaten deze service nooit. */
data class AiAnswerPdf(val fileName: String, val bytes: ByteArray) {
    override fun equals(other: Any?) = this === other ||
        (other is AiAnswerPdf && fileName == other.fileName && bytes.contentEquals(other.bytes))

    override fun hashCode() = 31 * fileName.hashCode() + bytes.contentHashCode()
}

/** Het renderen van het antwoord is mislukt of duurde te lang. */
class AiAnswerExportFailedException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/**
 * Maakt on-demand een PDF van één geslaagd AI-antwoord. Er wordt niets opgeslagen of gecachet;
 * de HTML is exact de al gesaniteerde HTML die ook op het scherm staat.
 */
@Service
class AiAnswerExportService(
    private val repository: AiSearchRepository,
    private val renderer: HtmlToPdfRenderer,
    @param:org.springframework.beans.factory.annotation.Value("\${hkh.public-origin:https://hkh.vdzonsoftware.nl}")
    private val publicOrigin: String = CollectionLinks.PUBLIC_ORIGIN,
) {
    private val executor = Executors.newVirtualThreadPerTaskExecutor()

    @PreDestroy
    fun close() = executor.shutdownNow()

    /** Geeft null als het antwoord niet bestaat of niet bij deze bezoeker hoort. */
    fun exportAnswer(identity: AiSearchIdentity, answerId: String): AiAnswerPdf? {
        val turn = findOwnedAnswer(identity, answerId) ?: return null
        val title = CollectionLinks.rewrite(turn.title?.takeIf(String::isNotBlank) ?: turn.question)
        val bodyHtml = CollectionLinks.rewrite(turn.answerHtml.orEmpty())
        val sources = turn.sources.map { ref ->
            "${ref.collection} · ${ref.ident} — ${CollectionLinks.detail(ref.collection, ref.ident, publicOrigin)}"
        }
        return AiAnswerPdf(fileName(turn.id), render(title, bodyHtml, sources))
    }

    private fun render(title: String, bodyHtml: String, sources: List<String>): ByteArray {
        val task = executor.submit<ByteArray> { renderer.render(title, bodyHtml, sources) }
        return try {
            task.get(RENDER_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (error: Exception) {
            task.cancel(true)
            throw AiAnswerExportFailedException("Het antwoord kon niet naar PDF worden omgezet.", error)
        }
    }

    private fun findOwnedAnswer(identity: AiSearchIdentity, answerId: String): AiSearchTurn? {
        if (runCatching { UUID.fromString(answerId) }.isFailure) return null
        val turn = repository.findTurn(answerId) ?: return null
        if (turn.status != AiTurnStatus.SUCCEEDED || turn.answerHtml.isNullOrBlank()) return null
        if (!repository.sessionExists(turn.sessionId, identity)) return null
        return turn
    }

    private companion object {
        const val RENDER_TIMEOUT_SECONDS = 20L

        fun fileName(answerId: String) = "antwoord-${answerId.replace(Regex("[^A-Za-z0-9._-]"), "-")}.pdf"
    }
}
