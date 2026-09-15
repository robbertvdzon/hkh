package nl.vdzon.hkh.collection

import java.util.Base64
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CollectionLinksTest {
    @Test
    fun `legacy links in saved html markdown and prose open our objects`() {
        val url = "https://www.historischekringheemskerk.nl/cgi-bin/beeldbank.pl?display=gallery&ident=0042"
        val local = CollectionLinks.detail("beeldbank", "0042")
        assertEquals("<a href=\"$local\">$local</a>", CollectionLinks.rewrite("<a href=\"$url\">$url</a>"))
        assertEquals("[Bron]($local).", CollectionLinks.rewrite("[Bron]($url)."))
        assertEquals(local, CollectionLinks.rewrite(url.replace("&ident", "&amp;ident")))
        assertEquals(local, CollectionLinks.rewrite(url.replace("https:", "")))
        assertEquals(CollectionLinks.detail("beeldbank", "A B"), CollectionLinks.rewrite(url.replace("0042", "A%20B")))
    }

    @Test
    fun `unresolvable old pages and plain domain names lead to local search`() {
        for (text in listOf("https://historischekringheemskerk.nl/cgi-bin/", "WWW.HISTORISCHEKRINGHEEMSKERK.NL", "https://www.historischekringheemskerk.nl/over-ons")) {
            val rewritten = CollectionLinks.rewrite(text)
            assertFalse(rewritten.contains("historischekringheemskerk", true))
            assertTrue(rewritten.contains("/#/zoeken"))
        }
        assertEquals("https://example.com", CollectionLinks.rewrite("https://example.com"))
    }

    @Test
    fun `media uses an internal endpoint and the import allowlist cannot be bypassed`() {
        val url = "https://www.historischekringheemskerk.nl/objecten/foto.jpg"
        val media = CollectionLinks.media(url)!!
        assertTrue(media.startsWith("${CollectionLinks.PUBLIC_ORIGIN}/api/collection-media/"))
        assertFalse(media.contains("historischekringheemskerk"))
        assertEquals(url, String(Base64.getUrlDecoder().decode(media.substringAfterLast('/'))))
        assertEquals(media, CollectionLinks.rewrite(url))
        for (bad in listOf("https://historischekringheemskerk.nl.evil.test/a", "https://evil.test@historischekringheemskerk.nl/a", "file:///etc/passwd", "http://127.0.0.1/a", "https://historischekringheemskerk.nl:9000/a")) {
            assertFalse(CollectionLinks.isImportUrl(bad), bad)
        }
    }

    @Test
    fun `media proxy unwraps the PDF behind a legacy viewer link`() {
        val media = CollectionLinks.media(
            "https://www.historischekringheemskerk.nl/pdfjs3/web/viewer.html?file=/archief/pdf/10396.pdf",
        )

        val token = media!!.substringAfterLast('/')
        assertEquals(
            "https://www.historischekringheemskerk.nl/archief/pdf/10396.pdf",
            String(Base64.getUrlDecoder().decode(token)),
        )
        val thumbnail = CollectionLinks.thumbnail(
            "https://www.historischekringheemskerk.nl/pdfjs3/web/viewer.html?file=/archief/pdf/10396.pdf",
        )!!
        assertTrue(thumbnail.startsWith("${CollectionLinks.PUBLIC_ORIGIN}/api/collection-thumbnail/"))
    }
}
