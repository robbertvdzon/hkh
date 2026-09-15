package nl.vdzon.hkh.docexport

import kotlin.test.assertContains
import kotlin.test.assertTrue
import org.apache.pdfbox.Loader
import org.apache.pdfbox.text.PDFTextStripper
import org.junit.jupiter.api.Test

class HtmlToPdfRendererTest {
    private val renderer = HtmlToPdfRenderer()

    @Test
    fun `renders title, body and sources into a readable pdf`() {
        val bytes = renderer.render(
            "Jan Klaasz. Beemster",
            "<p>Hij was <strong>schepen en molenaar</strong> in Heemskerk.</p>",
            listOf("beeldbank · 42 — https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42"),
        )

        assertTrue(bytes.size > 4, "De PDF is leeg")
        assertTrue(bytes.decodeToString(0, 4) == "%PDF", "De body begint niet met de PDF-magic")
        val text = extractText(bytes)
        assertContains(text, "Jan Klaasz. Beemster")
        assertContains(text, "schepen en molenaar")
        assertContains(text, "Bronnen")
        assertContains(text, "beeldbank")
        assertContains(text, "https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42")
    }

    @Test
    fun `keeps dutch diacritics and punctuation intact`() {
        val bytes = renderer.render(
            "Café Zomerlust – 1890",
            "<p>De rijtuigen reden ‘s ochtends langs de Kerklaan; België lag ver weg.</p>",
            emptyList(),
        )

        val text = extractText(bytes)
        assertContains(text, "Café Zomerlust – 1890")
        assertContains(text, "‘s ochtends")
        assertContains(text, "België")
    }

    @Test
    fun `an unreachable image never fails the generation`() {
        val bytes = renderer.render(
            "Bron met beeld",
            """
            <p>Tekst voor het beeld.</p>
            <figure>
              <img src="https://hkh.vdzonsoftware.nl/api/collection-media/bestaat-niet.jpg" alt="Archiefbeeld"/>
              <figcaption>beeldbank · 42</figcaption>
            </figure>
            <p>Tekst na het beeld.</p>
            """.trimIndent(),
            emptyList(),
        )

        val text = extractText(bytes)
        assertContains(text, "Tekst voor het beeld.")
        assertContains(text, "Tekst na het beeld.")
    }

    @Test
    fun `no sources means no sources heading`() {
        val text = extractText(renderer.render("Zonder bronnen", "<p>Alleen tekst.</p>", emptyList()))

        assertContains(text, "Alleen tekst.")
        assertTrue(!text.contains("Bronnen"), "Er hoort geen lege bronnensectie in de PDF te staan")
    }

    private fun extractText(bytes: ByteArray): String =
        Loader.loadPDF(bytes).use { document -> PDFTextStripper().getText(document) }
}
