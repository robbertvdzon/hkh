package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import org.jsoup.Jsoup
import org.junit.jupiter.api.Test

/**
 * Regressietest voor een echte, opgeslagen ZCBS-lijstpagina (archief, eerste 3 van 30
 * records + de volledige pagina-omlijsting: kop, paginering, en het sluitende
 * `<!-- ZCBS-LIST -->`-marker gevolgd door een footer). De sluitmarker mag nooit als
 * record worden gelezen (zie parseListItems).
 */
class ZcbsListParsingTest {
    @Test
    fun `parses real records from a full list page and ignores the closing marker`() {
        val html = javaClass.classLoader.getResource("zcbs-sample-list-archief-full.html")!!.readText(Charsets.ISO_8859_1)
        val doc = Jsoup.parse(html, "https://www.historischekringheemskerk.nl")
        val client = ZcbsClient(ZcbsProperties())

        val items = client.parseListItems(doc, "archief")

        assertEquals(listOf("10000", "10003", "10004"), items.map { it.ident })
        assertFalse(items.any { it.ident == "ZCBS-LIST" })
        assertEquals("Gemeentedag zaterdag 23 september 1995", items[0].title)
    }

    @Test
    fun `the grey sequence number never leaks into a field label`() {
        // Elk item staat in dezelfde <tr> als een <font color="gray">N.</font>-teller,
        // zonder scheidingsteken ertussen; die mag nooit aan het eerste veld plakken
        // (bv. "1. Documentnummer" i.p.v. "Documentnummer").
        val html = javaClass.classLoader.getResource("zcbs-sample-list-archief-full.html")!!.readText(Charsets.ISO_8859_1)
        val doc = Jsoup.parse(html, "https://www.historischekringheemskerk.nl")
        val client = ZcbsClient(ZcbsProperties())

        val items = client.parseListItems(doc, "archief")

        for (item in items) {
            assertFalse(
                item.fields.keys.any { it.matches(Regex("""^\d+\.\s.*""")) },
                "veld begint met een cijfer-teller: ${item.fields.keys}",
            )
        }
    }
}
