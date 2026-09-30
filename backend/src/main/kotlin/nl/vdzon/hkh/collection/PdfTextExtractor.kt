package nl.vdzon.hkh.collection

import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper

/**
 * Haalt de tekstlaag uit een PDF. De ZCBS-scans hebben die laag al (OCR door de HKH-site), dus
 * dit is extractie, geen tekstherkenning. Witruimte wordt genormaliseerd: regels binnen een
 * alinea worden samengevoegd, alinea's blijven gescheiden door een lege regel.
 */
object PdfTextExtractor {
    /** Bovengrens per document; ruim boven de langste bekende scans, onder de tsvector-limiet. */
    const val MAX_CHARS = 300_000

    fun extract(pdf: ByteArray): String = Loader.loadPDF(pdf).use { document ->
        val stripper = PDFTextStripper().apply { sortByPosition = false }
        normalize(stripper.getText(document))
    }

    internal fun normalize(raw: String): String {
        val paragraphs = raw.replace("\r\n", "\n").replace('\r', '\n')
            .replace(' ', ' ')
            .replace("\u000c", "\n\n")
            .split(Regex("\n\\s*\n"))
            .map { paragraph -> paragraph.split('\n').map { it.trim() }.filter { it.isNotEmpty() }.joinToString(" ") }
            .map { it.replace(Regex("[ \\t]+"), " ") }
            .filter { it.isNotEmpty() }
        return paragraphs.joinToString("\n\n").take(MAX_CHARS)
    }
}
