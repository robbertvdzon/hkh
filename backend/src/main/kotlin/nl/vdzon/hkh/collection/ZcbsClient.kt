package nl.vdzon.hkh.collection

import java.io.ByteArrayInputStream
import java.net.URI
import java.time.Duration
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.slf4j.LoggerFactory
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Component
import org.springframework.web.client.HttpServerErrorException
import org.springframework.web.client.ResourceAccessException
import org.springframework.web.client.RestClient
import org.springframework.web.util.UriComponentsBuilder

/**
 * Praat met de ZCBS Perl-scripts (cgi-bin/<collectie>.pl) op de HKH-webserver.
 * Pagina's zijn ISO-8859-1 en worden met jsoup geparst.
 */
@Component
class ZcbsClient(private val properties: ZcbsProperties, restClientOverride: RestClient? = null) {
    private val logger = LoggerFactory.getLogger(javaClass)

    /** [restClientOverride] exists so tests can exercise [getWithRetry] against a fake server. */
    private val restClient: RestClient = restClientOverride ?: run {
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
            val doc = getListPage(collection, istart)
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

    /**
     * Snelle route: parset de "toon alles"-lijstpagina's zelf (30 records/pagina) in plaats
     * van elk record apart op te halen. Geeft per record titel, korte beschrijving, een
     * thumbnail en een deel van de detailvelden - maar geen PDF-link en een paar velden die
     * alleen op de detailpagina staan (bv. uitgever, paginanummer). Bedoeld om de collectie
     * binnen enkele minuten doorzoekbaar te maken; [fetchRecord] vult de rest later aan.
     *
     * Roept [onPage] aan zodra een pagina geparset is (in plaats van alles pas aan het eind in
     * één keer terug te geven), zodat een grote collectie (bv. 12.000 foto's, 400+ pagina's)
     * tussentijds al wordt opgeslagen. Zonder dat zou één tijdelijke serverfout halverwege het
     * werk van de hele collectie weggooien en de voortgang minutenlang "stil" laten staan.
     */
    fun listSummaries(collection: String, onPage: (List<ListSummary>) -> Unit) {
        var istart = 1
        var previous = -1
        var pages = 0
        while (pages++ < properties.maxPagesPerCollection && istart != previous) {
            val doc = getListPage(collection, istart)
            val items = parseListItems(doc, collection)
            if (items.isNotEmpty()) onPage(items)
            val html = doc.outerHtml()
            val starts = Regex("""istart=(\d+)""").findAll(html)
                .map { it.groupValues[1].toInt() }
                .toSortedSet()
            val next = starts.firstOrNull { it > istart }
            previous = istart
            istart = next ?: istart
            if (next == null) break
            sleepBetweenPages()
        }
    }

    /**
     * Elk lijstitem staat in de HTML als `<!-- ident -->` gevolgd door zijn tabelblok. De hele
     * lijst zit tussen een openend en een sluitend `<!-- ZCBS-LIST -->`-marker; alleen dat
     * middenstuk wordt gescand zodat de sluitmarker zelf (en de paginafooter erna) nooit als
     * een extra "record" wordt gelezen.
     */
    internal fun parseListItems(doc: Document, collection: String): List<ListSummary> {
        val html = doc.outerHtml()
        val start = html.indexOf(LIST_MARKER)
        if (start < 0) return emptyList()
        val bodyStart = start + LIST_MARKER.length
        val end = html.indexOf(LIST_MARKER, bodyStart)
        val body = if (end >= 0) html.substring(bodyStart, end) else html.substring(bodyStart)
        val identComments = Regex("""<!--\s*([A-Za-z0-9_.-]+)\s*-->""").findAll(body).toList()
        val items = mutableListOf<ListSummary>()
        for (i in identComments.indices) {
            val ident = identComments[i].groupValues[1]
            if (ident == "ZCBS-LIST") continue
            val chunkStart = identComments[i].range.last + 1
            val chunkEnd = if (i + 1 < identComments.size) identComments[i + 1].range.first else body.length
            items += parseListItem(collection, ident, body.substring(chunkStart, chunkEnd))
        }
        return items
    }

    private fun parseListItem(collection: String, ident: String, chunkHtml: String): ListSummary {
        val fragment = Jsoup.parseBodyFragment(chunkHtml)
        fragment.select("br, tr, p").forEach { it.appendText(LINE_SEP) }
        val fields = LinkedHashMap<String, String>()
        val looseLines = mutableListOf<String>()
        for (rawLine in fragment.body().text().split(LINE_SEP)) {
            val line = rawLine.trim()
            if (line.isEmpty()) continue
            var matchedAny = false
            for (segment in line.split(Regex("""\s+--\s+"""))) {
                val trimmed = segment.trim()
                val colon = trimmed.indexOf(':')
                if (colon in 1..40) {
                    val label = trimmed.substring(0, colon).trim()
                    val value = trimmed.substring(colon + 1).trim()
                    if (label.length in 1..40 && label.any { it.isLetter() } && value.isNotBlank() && !fields.containsKey(label)) {
                        fields[label] = value
                        matchedAny = true
                    }
                }
            }
            if (!matchedAny) looseLines += line
        }
        val imageUrl = fragment.select("img[src]").map { it.attr("src") }
            .firstOrNull { it.contains("/$collection/", ignoreCase = true) }
            ?.let { absolute(it) }
        val title = firstNonBlank(fields, TITLE_KEYS).ifBlank {
            looseLines.firstOrNull { it.length in 3..160 } ?: ""
        }
        val description = firstNonBlank(fields, DESCRIPTION_KEYS).ifBlank {
            looseLines.filterNot { it == title }.joinToString(" ").trim().take(2000)
        }
        val path = "/cgi-bin/$collection.pl?ident=$ident"
        return ListSummary(
            collection = collection,
            ident = ident,
            title = title,
            description = description,
            year = extractYear(fields),
            imageUrl = imageUrl,
            detailUrl = properties.baseUrl + path,
            fields = fields,
        )
    }

    private fun sleepBetweenPages() = sleep(properties.requestDelayMs)

    private fun sleep(millis: Long) {
        if (millis > 0) {
            try {
                Thread.sleep(millis)
            } catch (ex: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }

    /** Haalt één recordpagina op en parset die naar velden + beeld/PDF-verwijzingen. */
    fun fetchRecord(collection: String, ident: String): ScrapedRecord {
        val path = "/cgi-bin/$collection.pl?ident=$ident"
        val doc = get("/cgi-bin/$collection.pl", mapOf("ident" to ident))
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

    /** Lijstpagina voor een collectie: "toon alles" (search=%) met istart-paginering. */
    private fun getListPage(collection: String, istart: Int): Document =
        get(
            "/cgi-bin/$collection.pl",
            mapOf("search" to "%", "veld" to "all", "display" to "list", "istart" to istart),
        )

    /**
     * Bouwt de URI zelf via [UriComponentsBuilder] en geeft die als [java.net.URI] mee aan
     * RestClient. RestClient.uri(String) behandelt een pad als template en encodeert het
     * nogmaals - een letterlijke `%` in bv. `search=%` zou dan dubbel encoderen tot `%25`
     * (waardoor de HKH-server naar de tekst "%25" zoekt in plaats van naar "alles").
     */
    private fun get(path: String, queryParams: Map<String, Any> = emptyMap()): Document {
        val builder = UriComponentsBuilder.fromUriString(properties.baseUrl).path(path)
        queryParams.forEach { (name, value) -> builder.queryParam(name, value) }
        val uri = builder.build().encode().toUri()
        val bytes = getWithRetry(uri)
        return Jsoup.parse(ByteArrayInputStream(bytes), "ISO-8859-1", properties.baseUrl)
    }

    /**
     * De HKH-server geeft af en toe een tijdelijke 502/503/504 of een verbindingsfout terug
     * (bv. onder belasting van een lange scrape). Zonder retry gooit dat meteen de hele
     * lopende scrape-run weg. Drie pogingen met oplopende wachttijd (1s, 2s, 4s).
     */
    internal fun getWithRetry(uri: URI): ByteArray {
        var attempt = 0
        var delay = 1000L
        while (true) {
            try {
                return restClient.get().uri(uri).retrieve().body(ByteArray::class.java) ?: ByteArray(0)
            } catch (ex: Exception) {
                val retryable = ex is HttpServerErrorException || ex is ResourceAccessException
                attempt++
                if (!retryable || attempt > MAX_RETRIES) throw ex
                logger.warn("Verzoek aan {} mislukt (poging {}/{}): {}. Nieuwe poging over {}ms.", uri, attempt, MAX_RETRIES, ex.message, delay)
                sleep(delay)
                delay *= 2
            }
        }
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
        const val MAX_RETRIES = 3
        const val LIST_MARKER = "<!-- ZCBS-LIST -->"
        const val LINE_SEP = ""
    }
}

/** Samenvatting van één record zoals die al op de lijstpagina staat (geen PDF-link). */
data class ListSummary(
    val collection: String,
    val ident: String,
    val title: String,
    val description: String,
    val year: Int?,
    val imageUrl: String?,
    val detailUrl: String,
    val fields: Map<String, String>,
)
