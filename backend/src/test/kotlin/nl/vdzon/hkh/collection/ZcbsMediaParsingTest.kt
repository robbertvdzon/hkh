package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import org.jsoup.Jsoup
import org.junit.jupiter.api.Test

class ZcbsMediaParsingTest {
    @Test
    fun `uses the PDF behind a legacy pdfjs viewer`() {
        val document = Jsoup.parse(
            "<a href=\"/pdfjs3/web/viewer.html?file=%2Farchief%2Fpdf%2F10396.pdf\">scan</a>",
            "https://www.historischekringheemskerk.nl",
        )

        assertEquals(
            "https://www.historischekringheemskerk.nl/archief/pdf/10396.pdf",
            ZcbsClient(ZcbsProperties()).extractPdfUrl(document, "archief"),
        )
    }
}
