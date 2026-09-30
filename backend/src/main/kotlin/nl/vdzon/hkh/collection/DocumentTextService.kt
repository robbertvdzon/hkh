package nl.vdzon.hkh.collection

import java.net.URI
import java.security.MessageDigest
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

sealed interface DocumentTextOutcome {
    /** Tekst opgeslagen. */
    data class Extracted(val characters: Int) : DocumentTextOutcome

    /** De PDF is ongewijzigd sinds de vorige extractie; niets opnieuw gedaan. */
    data object Unchanged : DocumentTextOutcome

    /** Downloaden of extraheren mislukte; de fout staat bij het record. */
    data class Failed(val reason: String) : DocumentTextOutcome
}

/**
 * Downloadt de PDF van een record via de ZCBS-site en slaat de tekstlaag op bij het record.
 * Wordt door de scraper (nieuwe records) en de backfill (bestaande collectie) gebruikt.
 * Fouten worden per record vastgelegd en stoppen nooit een lopende run.
 */
@Service
class DocumentTextService(
    private val client: ZcbsClient,
    private val items: CollectionItemStore,
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun extract(collection: String, ident: String, pdfUrl: String, previousHash: String? = null): DocumentTextOutcome {
        val outcome = try {
            // Oudere records hebben de pdf.js-viewerpagina als PDF-link; haal het bestand zelf op.
            val pdf = client.getWithRetry(URI(CollectionLinks.directPdf(pdfUrl)))
            if (pdf.isEmpty()) throw IllegalStateException("Lege PDF")
            if (!looksLikePdf(pdf)) throw IllegalStateException("Geen PDF ontvangen maar ${describe(pdf)}")
            val hash = sha256(pdf)
            if (previousHash != null && previousHash == hash) return DocumentTextOutcome.Unchanged
            val text = PdfTextExtractor.extract(pdf)
            items.saveDocumentText(collection, ident, text, hash)
            DocumentTextOutcome.Extracted(text.length)
        } catch (ex: Exception) {
            val reason = (ex.message ?: ex.javaClass.simpleName).take(500)
            items.saveDocumentTextError(collection, ident, reason)
            DocumentTextOutcome.Failed(reason)
        }
        if (outcome is DocumentTextOutcome.Failed) {
            logger.warn("Documenttekst {}/{} mislukt: {}", collection, ident, outcome.reason)
        }
        return outcome
    }

    private fun looksLikePdf(bytes: ByteArray): Boolean {
        val head = bytes.take(1024).toByteArray()
        val index = String(head, Charsets.ISO_8859_1).indexOf("%PDF-")
        return index in 0..1019
    }

    private fun describe(bytes: ByteArray): String {
        val head = String(bytes.take(200).toByteArray(), Charsets.ISO_8859_1).replace(Regex("\\s+"), " ").trim()
        return if (head.contains("<html", ignoreCase = true) || head.contains("<!doctype", ignoreCase = true)) "een HTML-pagina (${bytes.size} bytes)"
            else "${bytes.size} bytes: ${head.take(60)}"
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
}
