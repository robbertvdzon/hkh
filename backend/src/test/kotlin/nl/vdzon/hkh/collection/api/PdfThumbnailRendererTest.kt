package nl.vdzon.hkh.collection.api

import java.io.ByteArrayOutputStream
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.apache.pdfbox.pdmodel.PDDocument
import org.apache.pdfbox.pdmodel.PDPage
import org.junit.jupiter.api.Test

class PdfThumbnailRendererTest {
    @Test
    fun `large PDF pages produce bounded thumbnails`() {
        val pdf = ByteArrayOutputStream().also { output ->
            PDDocument().use { document ->
                document.addPage(PDPage(org.apache.pdfbox.pdmodel.common.PDRectangle(10000f, 20000f)))
                document.save(output)
            }
        }.toByteArray()
        val image = javax.imageio.ImageIO.read(PdfThumbnailRenderer.render(pdf).inputStream())
        assertTrue(image.width <= 800 && image.height <= 800)
        assertTrue(image.width > 0 && image.height > 0)
        image.flush()
    }

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
