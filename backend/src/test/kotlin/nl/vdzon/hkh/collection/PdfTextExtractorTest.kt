package nl.vdzon.hkh.collection

import java.io.ByteArrayOutputStream
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.apache.pdfbox.pdmodel.PDDocument
import org.apache.pdfbox.pdmodel.PDPage
import org.apache.pdfbox.pdmodel.PDPageContentStream
import org.apache.pdfbox.pdmodel.font.PDType1Font
import org.apache.pdfbox.pdmodel.font.Standard14Fonts
import org.junit.jupiter.api.Test

class PdfTextExtractorTest {
    @Test
    fun `reads the text layer of a pdf across pages`() {
        val pdf = pdfWithPages(listOf("Bouwplan Commandeurs", "Eerste paal geslagen"))

        val text = PdfTextExtractor.extract(pdf)

        assertTrue(text.contains("Bouwplan Commandeurs"), text)
        assertTrue(text.contains("Eerste paal geslagen"), text)
        assertTrue(text.indexOf("Bouwplan") < text.indexOf("Eerste paal"))
    }

    @Test
    fun `normalizes line breaks into paragraphs and caps the length`() {
        val raw = "Regel een\nregel  twee  \r\n\r\n\n  Alinea twee hier\u000cPagina twee"
        assertEquals("Regel een regel twee\n\nAlinea twee hier\n\nPagina twee", PdfTextExtractor.normalize(raw))
        assertEquals(PdfTextExtractor.MAX_CHARS, PdfTextExtractor.normalize("x".repeat(PdfTextExtractor.MAX_CHARS + 10)).length)
    }

    companion object {
        fun pdfWithPages(pages: List<String>): ByteArray = PDDocument().use { document ->
            for (line in pages) {
                val page = PDPage()
                document.addPage(page)
                PDPageContentStream(document, page).use { content ->
                    content.beginText()
                    content.setFont(PDType1Font(Standard14Fonts.FontName.HELVETICA), 12f)
                    content.newLineAtOffset(50f, 700f)
                    content.showText(line)
                    content.endText()
                }
            }
            ByteArrayOutputStream().also(document::save).toByteArray()
        }
    }
}
