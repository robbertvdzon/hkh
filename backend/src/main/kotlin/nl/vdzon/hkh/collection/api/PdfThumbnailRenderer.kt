package nl.vdzon.hkh.collection.api

import java.io.ByteArrayOutputStream
import javax.imageio.ImageIO
import org.apache.pdfbox.Loader
import org.apache.pdfbox.rendering.ImageType
import org.apache.pdfbox.rendering.PDFRenderer

/** Renders only page one, at card size, so PDF scans can participate in the gallery. */
internal object PdfThumbnailRenderer {
    fun render(pdf: ByteArray): ByteArray = Loader.loadPDF(pdf).use { document ->
        require(document.numberOfPages > 0) { "PDF has no pages" }
        val image = PDFRenderer(document).renderImageWithDPI(0, 110f, ImageType.RGB)
        ByteArrayOutputStream().use { output ->
            check(ImageIO.write(image, "jpeg", output)) { "JPEG renderer unavailable" }
            image.flush()
            output.toByteArray()
        }
    }
}
