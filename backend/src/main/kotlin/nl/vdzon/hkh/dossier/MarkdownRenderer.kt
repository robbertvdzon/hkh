package nl.vdzon.hkh.dossier

import java.net.URI
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionSearchService
import org.commonmark.ext.gfm.tables.TablesExtension
import org.commonmark.parser.Parser
import org.commonmark.renderer.html.HtmlRenderer
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.safety.Safelist
import org.springframework.stereotype.Component

data class RenderedSource(
    val collection: String,
    val ident: String,
    val title: String,
    val detailUrl: String,
    val imageUrl: String?,
)

data class RenderedMarkdown(val html: String, val sources: List<RenderedSource>, val unknownSources: List<String>)

/**
 * Zet artikel- en feitenlijst-Markdown om naar veilige HTML. Bronlinks in de vorm
 * `[naam](hkh:collection/ident)` worden alleen een echte link als de bron in de collectie bestaat;
 * andere links, afbeeldingen en ruwe HTML worden niet gerenderd.
 */
@Component
class MarkdownRenderer(private val collectionSearch: CollectionSearchService) {
    private val parser = Parser.builder().extensions(listOf(TablesExtension.create())).build()
    private val renderer = HtmlRenderer.builder().extensions(listOf(TablesExtension.create())).escapeHtml(true).build()

    fun render(markdown: String): RenderedMarkdown {
        val document = Jsoup.parseBodyFragment(renderer.render(parser.parse(markdown)))
        document.select("img, script, style, iframe, form, input, button, svg, object, embed, video, audio").remove()
        val sources = linkedMapOf<String, RenderedSource>()
        val unknown = linkedSetOf<String>()
        document.select("a").forEach { link ->
            val ref = parseSourceRef(link.attr("href"))
            val item = ref?.let { (collection, ident) -> lookup(collection, ident) }
            if (ref == null || item == null) {
                if (ref != null) unknown += "${ref.first}/${ref.second}"
                link.removeAttr("href").removeAttr("target").removeAttr("rel")
                link.attr("data-hkh-unknown", "true")
            } else {
                link.attr("href", item.detailUrl).attr("target", "_blank").attr("rel", "noopener")
                link.attr("data-hkh-collection", ref.first).attr("data-hkh-ident", ref.second)
                sources.putIfAbsent("${ref.first}/${ref.second}", item.toRendered(ref.first, ref.second))
            }
        }
        val safeList = Safelist.relaxed()
            .addAttributes("a", "target", "rel", "data-hkh-collection", "data-hkh-ident", "data-hkh-unknown")
            .addProtocols("a", "href", "https")
        val html = Jsoup.clean(document.body().html(), "", safeList, Document.OutputSettings().prettyPrint(false))
        return RenderedMarkdown(html, sources.values.toList(), unknown.toList())
    }

    /** Alle `hkh:`-verwijzingen in de tekst, ongeacht of ze bestaan. */
    fun sourceRefs(markdown: String): List<Pair<String, String>> =
        SOURCE_LINK.findAll(markdown).map { it.groupValues[1] to it.groupValues[2] }.distinct().toList()

    private fun lookup(collection: String, ident: String): CollectionItem? =
        collectionSearch.detail(collection, ident)?.takeIf { isSafeHkhUrl(it.detailUrl) }

    private fun CollectionItem.toRendered(collection: String, ident: String) = RenderedSource(
        collection = collection,
        ident = ident,
        title = title.ifBlank { "$collection $ident" },
        detailUrl = detailUrl,
        imageUrl = imageUrl?.takeIf(String::isNotBlank)?.takeIf(::isSafeHkhUrl),
    )

    private fun parseSourceRef(href: String): Pair<String, String>? {
        val match = SOURCE_HREF.matchEntire(href.trim()) ?: return null
        return match.groupValues[1] to match.groupValues[2]
    }

    private fun isSafeHkhUrl(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme == "https" && (
            uri.host == "hkh.vdzonsoftware.nl" ||
                uri.host == "historischekringheemskerk.nl" ||
                uri.host?.endsWith(".historischekringheemskerk.nl") == true
            )
    }.getOrDefault(false)

    companion object {
        private val SOURCE_HREF = Regex("^hkh:([A-Za-z0-9_-]{1,40})/([A-Za-z0-9_.-]{1,64})$")
        private val SOURCE_LINK = Regex("\\]\\(hkh:([A-Za-z0-9_-]{1,40})/([A-Za-z0-9_.-]{1,64})\\)")
    }
}
