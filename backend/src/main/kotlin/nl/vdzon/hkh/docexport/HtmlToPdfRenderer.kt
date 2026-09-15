package nl.vdzon.hkh.docexport

import com.openhtmltopdf.extend.FSSupplier
import com.openhtmltopdf.extend.FSUriResolver
import com.openhtmltopdf.outputdevice.helper.BaseRendererBuilder
import com.openhtmltopdf.pdfboxout.PdfRendererBuilder
import java.io.ByteArrayOutputStream
import java.io.InputStream
import org.jsoup.Jsoup
import org.jsoup.helper.W3CDom
import org.jsoup.nodes.Document
import org.springframework.stereotype.Component

/** Het renderen van een document naar PDF is mislukt; er zijn dan nooit bruikbare bytes. */
class PdfRenderException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/**
 * Zet reeds gesaniteerde HTML om naar PDF-bytes. Deze module saniteert of herschrijft niets:
 * de aanroeper levert de HTML aan die ook op het scherm wordt getoond. Er worden nooit externe
 * bronnen (afbeeldingen, stylesheets, fonts) opgehaald tijdens het renderen.
 */
@Component
class HtmlToPdfRenderer {
    /**
     * @param title kop boven het document, als platte tekst.
     * @param bodyHtml gesaniteerd HTML-fragment dat ongewijzigd in het document komt.
     * @param sources bronregels als platte tekst; leeg betekent geen bronnensectie.
     */
    fun render(title: String, bodyHtml: String, sources: List<String>): ByteArray {
        val document = buildDocument(title, bodyHtml, sources)
        val output = ByteArrayOutputStream()
        try {
            PdfRendererBuilder().apply {
                useFastMode()
                useUriResolver(BLOCK_EXTERNAL_RESOURCES)
                useFont(fontSupplier(REGULAR_FONT), FONT_FAMILY, 400, BaseRendererBuilder.FontStyle.NORMAL, true)
                useFont(fontSupplier(BOLD_FONT), FONT_FAMILY, 700, BaseRendererBuilder.FontStyle.NORMAL, true)
                withW3cDocument(W3CDom().fromJsoup(document), "")
                toStream(output)
            }.run()
        } catch (error: Exception) {
            throw PdfRenderException("Het document kon niet naar PDF worden omgezet.", error)
        }
        val bytes = output.toByteArray()
        if (bytes.isEmpty()) throw PdfRenderException("De PDF-generatie leverde geen inhoud op.")
        return bytes
    }

    /** Vast, minimaal sjabloon: titel, de aangeleverde HTML, en daarna de bronnen. */
    private fun buildDocument(title: String, bodyHtml: String, sources: List<String>): Document {
        val document = Jsoup.parse("<html><head><meta charset=\"utf-8\"></head><body></body></html>")
        document.outputSettings().prettyPrint(false)
        document.head().appendElement("title").text(title)
        document.head().appendElement("style").text(DOCUMENT_CSS)
        val body = document.body()
        body.appendElement("h1").text(title)
        body.append(bodyHtml)
        if (sources.isNotEmpty()) {
            body.appendElement("h2").text(SOURCES_HEADING)
            val list = body.appendElement("ul")
            sources.forEach { source -> list.appendElement("li").text(source) }
        }
        return document
    }

    private fun fontSupplier(resource: String) = FSSupplier<InputStream> {
        checkNotNull(HtmlToPdfRenderer::class.java.getResourceAsStream(resource)) {
            "Het lettertype $resource ontbreekt in de backend-resources."
        }
    }

    private companion object {
        const val FONT_FAMILY = "HKH Sans"
        const val REGULAR_FONT = "/fonts/LiberationSans-Regular.ttf"
        const val BOLD_FONT = "/fonts/LiberationSans-Bold.ttf"
        const val SOURCES_HEADING = "Bronnen"

        /**
         * Geen enkel verzoek naar buiten: een niet-oplosbare verwijzing levert geen bron op,
         * waardoor een ontbrekende of onbereikbare afbeelding het renderen niet laat falen.
         */
        val BLOCK_EXTERNAL_RESOURCES = FSUriResolver { _, _ -> null }

        val DOCUMENT_CSS = """
            @page { size: A4; margin: 20mm 18mm; }
            body { font-family: "$FONT_FAMILY", sans-serif; font-size: 11pt; line-height: 1.45; color: #1a1a1a; }
            h1 { font-size: 19pt; margin: 0 0 14pt 0; }
            h2 { font-size: 14pt; margin: 16pt 0 6pt 0; }
            h3 { font-size: 12pt; margin: 12pt 0 4pt 0; }
            p, li { margin: 0 0 6pt 0; }
            ul, ol { margin: 0 0 8pt 0; padding-left: 16pt; }
            a { color: #1f3b2e; }
            img { max-width: 100%; }
            figure { margin: 8pt 0; }
            figcaption { font-size: 9pt; color: #555555; }
            hr { border: 0; border-top: 1px solid #cccccc; margin: 14pt 0; }
            table { border-collapse: collapse; width: 100%; }
            td, th { border: 1px solid #cccccc; padding: 3pt 5pt; text-align: left; }
            blockquote { margin: 0 0 8pt 12pt; color: #444444; }
        """.trimIndent()
    }
}
