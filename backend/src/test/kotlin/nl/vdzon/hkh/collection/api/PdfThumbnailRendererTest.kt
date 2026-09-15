package nl.vdzon.hkh.collection.api

import java.io.ByteArrayOutputStream
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.apache.pdfbox.pdmodel.PDDocument
import org.apache.pdfbox.pdmodel.PDPage
import org.junit.jupiter.api.Test

class PdfThumbnailRendererTest {
    @Test
    fun `renders the first PDF page as JPEG`() {
        val pdf = ByteArrayOutputStream().also { output ->
            PDDocument().use { document ->
                document.addPage(PDPage())
                document.save(output)
            }
        }.toByteArray()

        val thumbnail = PdfThumbnailRenderer.render(pdf)

        assertTrue(thumbnail.size > 100)
        assertEquals(0xff.toByte(), thumbnail[0])
        assertEquals(0xd8.toByte(), thumbnail[1])
    }
}
