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
        val page = document.getPage(0).cropBox
        require(page.width > 0 && page.height > 0) { "Invalid page dimensions" }
        // Limit output pixels even for posters and downsample embedded high-resolution scans.
        val scale = minOf(1.5f, 800f / maxOf(page.width, page.height))
        val renderer = PDFRenderer(document).apply { isSubsamplingAllowed = true }
        val image = renderer.renderImage(0, scale, ImageType.RGB)
        ByteArrayOutputStream().use { output ->
            check(ImageIO.write(image, "jpeg", output)) { "JPEG renderer unavailable" }
            image.flush()
            output.toByteArray()
        }
    }
}
