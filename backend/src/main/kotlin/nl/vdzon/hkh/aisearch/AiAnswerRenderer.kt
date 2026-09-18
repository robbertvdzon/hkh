package nl.vdzon.hkh.aisearch

import nl.vdzon.hkh.collection.CollectionLinks
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionSearchService
import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import org.jsoup.safety.Safelist
import org.springframework.stereotype.Component
import tools.jackson.databind.JsonNode

data class RenderedAiAnswer(
    val title: String,
    val html: String,
    val sources: List<AiSourceRef>,
    val suggestedFollowUps: List<String>,
)

@Component
class AiAnswerRenderer(private val collectionSearch: CollectionSearchService,
    @param:org.springframework.beans.factory.annotation.Value("\${hkh.public-origin:https://hkh.vdzonsoftware.nl}")
    private val publicOrigin: String = CollectionLinks.PUBLIC_ORIGIN,
) {
    fun render(result: JsonNode): RenderedAiAnswer {
        val title = result.path("title").asText("Antwoord uit het archief").ifBlank { "Antwoord uit het archief" }
        val requestedSources = mutableListOf<AiSourceRef>()
        for (node in result.path("sources")) {
            val collection = node.path("collection").asText("").trim()
            val ident = node.path("ident").asText("").trim()
            if (collection.isNotBlank() && ident.isNotBlank()) requestedSources += AiSourceRef(collection, ident)
        }
        val uniqueSources = requestedSources.distinct().take(100)
        val records = uniqueSources.mapNotNull { ref ->
            collectionSearch.detail(ref.collection, ref.ident)
                ?.let { ref to it }
        }
        val verified = records.associate { (ref, item) -> "${ref.collection}/${ref.ident}" to item }

        val document = Jsoup.parseBodyFragment(result.path("answerHtml").asText(""))
        document.select("script, style, iframe, form, input, button, svg, object, embed, video, audio, img").remove()
        document.select("a").forEach { link ->
            val item = link.attr("data-hkh-source").takeIf(String::isNotBlank)?.let(verified::get)
            if (item == null) {
                link.removeAttr("href").removeAttr("target").removeAttr("rel")
            } else {
                link.attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin)).attr("target", "_blank").attr("rel", "noopener")
            }
            link.removeAttr("data-hkh-source")
        }
        // De AI kiest de plaats en het bijschrift, nooit de afbeeldings-URL.
        // Alleen opgegeven, bestaande collectiebronnen kunnen een beeld opleveren.
        val inlineImages = mutableSetOf<String>()
        document.select("figure[data-hkh-source]").forEach { placeholder ->
            val ref = placeholder.attr("data-hkh-source").trim()
            val item = verified[ref]
            if (item == null || ref in inlineImages) {
                placeholder.remove()
            } else {
                val caption = placeholder.selectFirst("figcaption")?.text()?.trim()
                    ?.takeIf(String::isNotBlank) ?: item.title.ifBlank { ref }
                val imageUrl = CollectionLinks.safeMedia(item.imageUrl)?.takeIf(String::isNotBlank)
                val figure = Element("figure")
                val link = figure.appendElement("a")
                    .attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin))
                    .attr("target", "_blank").attr("rel", "noopener")
                if (imageUrl != null) {
                    link.appendElement("img").attr("src", imageUrl).attr("alt", caption)
                    inlineImages += ref
                    figure.appendElement("figcaption").text(caption + " — ")
                        .appendElement("a")
                        .attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin))
                        .attr("target", "_blank").attr("rel", "noopener")
                        .text("${item.collection} · ${item.ident}")
                } else {
                    link.text("Afbeelding niet beschikbaar: $caption")
                }
                placeholder.replaceWith(figure)
            }
        }
        val safeList = Safelist.relaxed()
            .addTags("article", "section", "figure", "figcaption")
            .addAttributes("a", "target", "rel")
        val narrative = Jsoup.clean(document.body().html(), "", safeList, org.jsoup.nodes.Document.OutputSettings().prettyPrint(false))
        val html = buildString {
            append(narrative)
            if (records.isNotEmpty()) append(buildSourceSection(records, inlineImages))
        }
        val rawFollowUps = mutableListOf<String>()
        for (node in result.path("suggestedFollowUps")) rawFollowUps += node.asText().trim()
        val followUps = rawFollowUps.filter(String::isNotBlank).distinct().take(4)
        return RenderedAiAnswer(CollectionLinks.rewrite(title), CollectionLinks.rewrite(html), records.map { it.first }, followUps.map(CollectionLinks::rewrite))
    }

    private fun buildSourceSection(records: List<Pair<AiSourceRef, CollectionItem>>, inlineImages: Set<String>): String {
        val section = Element("section")
        section.appendElement("hr")
        section.appendElement("h2").text("Bronnen en afbeeldingen")
        records.forEach { (ref, item) ->
            val article = section.appendElement("article")
            val heading = article.appendElement("h3")
            heading.appendElement("a")
                .attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin))
                .attr("target", "_blank")
                .attr("rel", "noopener")
                .text(item.title.ifBlank { "${ref.collection} ${ref.ident}" })
            CollectionLinks.safeMedia(item.imageUrl)?.takeIf { it.isNotBlank() && "${ref.collection}/${ref.ident}" !in inlineImages }?.let { imageUrl ->
                val figure = article.appendElement("figure")
                figure.appendElement("a")
                    .attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin))
                    .attr("target", "_blank")
                    .attr("rel", "noopener")
                    .appendElement("img")
                    .attr("src", imageUrl)
                    .attr("alt", item.title.ifBlank { "Archiefbeeld" })
                    .attr("loading", "lazy")
                figure.appendElement("figcaption").text("${ref.collection} · ${ref.ident}")
            }
            item.description.takeIf(String::isNotBlank)?.let { article.appendElement("p").text(it) }
            article.appendElement("p").appendElement("a")
                .attr("href", CollectionLinks.detail(item.collection, item.ident, publicOrigin))
                .attr("target", "_blank")
                .attr("rel", "noopener")
                .text("Bekijk dit object in de collectie")
        }
        return section.outerHtml()
    }


}
