package nl.vdzon.hkh.collection

import java.io.ByteArrayInputStream
import java.net.URI
import java.time.Duration
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient

/**
 * Praat met de ZCBS Perl-scripts (cgi-bin/<collectie>.pl) op de HKH-webserver.
 * Pagina's zijn ISO-8859-1 en worden met jsoup geparst.
 */
@Component
class ZcbsClient(private val properties: ZcbsProperties) {

    private val restClient: RestClient = run {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(Duration.ofSeconds(properties.timeoutSeconds))
            setReadTimeout(Duration.ofSeconds(properties.timeoutSeconds))
        }
        RestClient.builder()
            .baseUrl(properties.baseUrl)
            .requestFactory(factory)
            .defaultHeader("User-Agent", "HKH-collectie-import/1.0 (+historischekringheemskerk.nl)")
            .build()
    }

    /** Alle ident-nummers van een collectie, via de "toon alles"-query (search=%25) en istart-paginering. */
    fun listIdents(collection: String): List<String> {
        val idents = LinkedHashSet<String>()
        var istart = 1
        var previous = -1
        var pages = 0
        val identPattern = Regex("""$collection\.pl\?ident=([^"&#]+)""")
        while (pages++ < properties.maxPagesPerCollection && istart != previous) {
            val doc = get("/cgi-bin/$collection.pl?search=%25&veld=all&display=list&istart=$istart")
            val html = doc.outerHtml()
            identPattern.findAll(html).forEach { idents.add(it.groupValues[1]) }
            val starts = Regex("""istart=(\d+)""").findAll(html)
                .map { it.groupValues[1].toInt() }
                .toSortedSet()
            val next = starts.firstOrNull { it > istart }
            previous = istart
            istart = next ?: istart
            if (next == null) break
        }
        return idents.toList()
    }

    /** Haalt één recordpagina op en parset die naar velden + beeld/PDF-verwijzingen. */
    fun fetchRecord(collection: String, ident: String): ScrapedRecord {
        val path = "/cgi-bin/$collection.pl?ident=$ident"
        val doc = get(path)
        val fields = parseFields(doc)
        val title = firstNonBlank(fields, TITLE_KEYS)
        val description = firstNonBlank(fields, DESCRIPTION_KEYS)
        val year = extractYear(fields)
        val imageUrl = extractImageUrl(doc, collection)
        val pdfUrl = extractPdfUrl(doc, collection)
        return ScrapedRecord(
            collection = collection,
            ident = ident,
            title = title,
            description = description,
            year = year,
            imageUrl = imageUrl,
            pdfUrl = pdfUrl,
            detailUrl = properties.baseUrl + path,
            fields = fields,
        )
    }

    private fun get(path: String): Document {
        val bytes = restClient.get().uri(path).retrieve().body(ByteArray::class.java)
            ?: ByteArray(0)
        return Jsoup.parse(ByteArrayInputStream(bytes), "ISO-8859-1", properties.baseUrl)
    }

    /** Leest de detailtabel als label:waarde-paren (patroon: [label] [:] [waarde]). */
    private fun parseFields(doc: Document): Map<String, String> {
        val fields = LinkedHashMap<String, String>()
        for (row in doc.select("tr")) {
            val cells = row.select("td, th").map { it.text().replace(' ', ' ').trim() }
            val colon = cells.indexOf(":")
            if (colon <= 0 || colon + 1 >= cells.size) continue
            val label = cells[colon - 1]
            val value = cells.subList(colon + 1, cells.size).joinToString(" ").trim()
            if (label.length in 1..40 && label.any { it.isLetter() } && !fields.containsKey(label)) {
                fields[label] = value
            }
        }
        return fields
    }

    private fun firstNonBlank(fields: Map<String, String>, keys: List<String>): String {
        for (key in keys) {
            val v = fields[key]
            if (!v.isNullOrBlank()) return v
        }
        return ""
    }

    private fun extractYear(fields: Map<String, String>): Int? {
        for (key in YEAR_KEYS) {
            val v = fields[key] ?: continue
            val m = Regex("""\b(1[0-9]{3}|20[0-9]{2})\b""").find(v)
            if (m != null) return m.groupValues[1].toInt()
        }
        return null
    }

    private fun extractImageUrl(doc: Document, collection: String): String? {
        val candidates = mutableListOf<String>()
        doc.select("img[src]").forEach { candidates.add(it.attr("src")) }
        doc.select("a[href]").forEach { candidates.add(it.attr("href")) }
        val images = candidates
            .map { it.substringBefore('#').substringBefore('?') }
            .filter { it.contains("/$collection/", ignoreCase = true) }
            .filter { it.substringAfterLast('.').lowercase() in IMAGE_EXTENSIONS }
            .filterNot { it.contains("/misc/", ignoreCase = true) }
        val best = images.firstOrNull { url -> LARGE_DIRS.any { url.contains("/$it/", ignoreCase = true) } }
            ?: images.firstOrNull()
        return best?.let { absolute(it) }
    }

    private fun extractPdfUrl(doc: Document, collection: String): String? {
        val href = doc.select("a[href]").map { it.attr("href") }
            .map { it.substringBefore('#') }
            .firstOrNull { it.contains("/$collection/", ignoreCase = true) && it.endsWith(".pdf", ignoreCase = true) }
        return href?.let { absolute(it) }
    }

    private fun absolute(url: String): String = when {
        url.startsWith("http://") || url.startsWith("https://") -> url
        url.startsWith("//") -> "https:$url"
        url.startsWith("/") -> properties.baseUrl + url
        else -> URI(properties.baseUrl + "/").resolve(url).toString()
    }

    private companion object {
        val TITLE_KEYS = listOf("Titel", "Titel artikel", "Titel object", "Naam", "Onderwerp", "Omschrijving kort")
        val DESCRIPTION_KEYS = listOf("Beschrijving", "Omschrijving", "Toelichting", "Inhoud")
        val YEAR_KEYS = listOf("Verschijningsjaar", "Datering", "Jaar", "Periode", "Datum")
        val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "webp")
        val LARGE_DIRS = listOf("large", "groot", "original", "origineel", "medium", "middel")
    }
}
