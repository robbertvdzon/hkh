package nl.vdzon.hkh.collection.api

import nl.vdzon.hkh.collection.CollectionCatalog
import nl.vdzon.hkh.collection.CollectionFacet
import nl.vdzon.hkh.collection.CollectionSearchOptions
import org.springframework.util.MultiValueMap
import nl.vdzon.hkh.collection.CollectionLinks
import nl.vdzon.hkh.collection.CollectionItem
import nl.vdzon.hkh.collection.CollectionSearchService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

data class CollectionSummaryResponse(
    val total: Long,
    val collections: List<CollectionCountResponse>,
)

data class CollectionCountResponse(val collection: String, val count: Long)

data class CollectionItemSummary(
    val collection: String,
    val ident: String,
    val title: String,
    val description: String,
    val year: Int?,
    val imageUrl: String?,
    val thumbnailUrl: String?,
    val hasPdf: Boolean,
    val fields: Map<String, String>,
)

data class CollectionItemDetail(
    val collection: String,
    val ident: String,
    val title: String,
    val description: String,
    val year: Int?,
    val imageUrl: String?,
    val pdfUrl: String?,
    val detailUrl: String,
    val fields: Map<String, String>,
)

data class SearchResponse(
    val items: List<CollectionItemSummary>,
    val total: Long,
    val page: Int,
    val pageSize: Int,
    val documentTextAvailable: Boolean,
    val collectionCounts: List<CollectionCountResponse>,
)

@RestController
@RequestMapping("/api/collections")
class CollectionController(private val service: CollectionSearchService) {

    @GetMapping
    fun overview(): CollectionSummaryResponse =
        CollectionSummaryResponse(
            total = service.total(),
            collections = service.collections().map { CollectionCountResponse(it.collection, it.count) },
        )

    @GetMapping("/search")
    fun search(@RequestParam params: MultiValueMap<String, String>): SearchResponse {
        val input = SearchInput(params)
        val result = service.search(input.query, input.collection, input.fields,
            input.integer("page") ?: 0, input.integer("size") ?: 20, input.year, input.options)
        return SearchResponse(result.items.map(CollectionItem::toSummary), result.total, result.page,
            result.pageSize, service.documentTextAvailable(),
            result.collectionCounts.map { CollectionCountResponse(it.collection, it.count) })
    }

    @GetMapping("/facets")
    fun facet(@RequestParam params: MultiValueMap<String, String>): CollectionFacet {
        val input = SearchInput(params)
        val collection = input.collection ?: badRequest("Kies een collectie voor dit filter.")
        val field = params.getFirst("facet") ?: badRequest("Filter ontbreekt.")
        if (field !in CollectionCatalog.facets[collection].orEmpty()) badRequest("Onbekend filter.")
        val valueQuery = params.getFirst("facetQuery").orEmpty().take(200)
        return service.facet(input.query, collection, input.fields, input.year, input.options, field, valueQuery)
    }

    @GetMapping("/{collection}/{ident}")
    fun detail(
        @PathVariable collection: String,
        @PathVariable ident: String,
    ): CollectionItemDetail =
        service.detail(collection, ident)?.toDetail()
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Record niet gevonden")
}

private fun CollectionItem.toSummary() = CollectionItemSummary(
    collection = collection,
    ident = ident,
    title = title,
    description = description,
    year = year,
    imageUrl = CollectionLinks.media(imageUrl),
    thumbnailUrl = if (imageUrl == null) CollectionLinks.thumbnail(pdfUrl) else null,
    hasPdf = pdfUrl != null,
    fields = fields.filterKeys { key -> CollectionCatalog.documentFields.none { it.equals(key, ignoreCase = true) } },
)

private fun CollectionItem.toDetail() = CollectionItemDetail(
    collection = collection,
    ident = ident,
    title = title,
    description = description,
    year = year,
    imageUrl = CollectionLinks.media(imageUrl),
    pdfUrl = CollectionLinks.media(pdfUrl),
    detailUrl = CollectionLinks.detail(collection, ident),
    fields = fields,
)

/** All user values stay JDBC parameters. Reject malformed ranges/settings instead of silently broadening a search. */
private class SearchInput(private val params: MultiValueMap<String, String>) {
    val query = params.getFirst("q")?.trim()?.takeIf { it.isNotEmpty() }
    val collection = params.getFirst("collection")?.takeIf { it.isNotBlank() }
    val fields = pairs("fq").associate { it }
    val year = integer("year")
    val options: CollectionSearchOptions

    init {
        if (query.orEmpty().length > 2000 || fields.size > 20 || fields.values.any { it.length > 2000 }) badRequest("Zoekopdracht is te lang.")
        val mode = params.getFirst("mode") ?: "web"
        if (mode !in setOf("web", "and", "or", "phrase")) badRequest("Onbekende zoekwijze.")
        val sort = params.getFirst("sort") ?: "relevance"
        if (sort !in setOf("relevance", "number", "title", "newest", "oldest", "author", "added")) badRequest("Onbekende sortering.")
        val from = integer("from")
        val to = integer("to")
        if (listOfNotNull(from, to, year).any { it !in 1..2100 } || (from != null && to != null && from > to)) badRequest("Ongeldige periode.")
        val recent = integer("recent")
        if (recent != null && recent !in 1..3650) badRequest("Ongeldige toevoegperiode.")
        val filters = pairs("filter").groupBy({ it.first }, { it.second }).mapValues { it.value.distinct() }
        if (filters.size > 10 || filters.values.sumOf { it.size } > 50) badRequest("Te veel filters.")
        if (filters.keys.any { it !in CollectionCatalog.facets.values.flatten() }) badRequest("Dit filter hoort niet bij de gekozen collectie.")
        options = CollectionSearchOptions(mode, boolean("partial", false), params.getFirst("field") ?: "all",
            from, to, filters, sort, recent, boolean("documentText", true))
    }

    fun integer(key: String): Int? = params.getFirst(key)?.let { it.toIntOrNull() ?: badRequest("Ongeldige waarde voor $key.") }
    private fun boolean(key: String, default: Boolean): Boolean = params.getFirst(key)?.let {
        it.toBooleanStrictOrNull() ?: badRequest("Ongeldige waarde voor $key.")
    } ?: default
    private fun pairs(key: String): List<Pair<String, String>> = params[key].orEmpty().map { raw ->
        val colon = raw.indexOf(':')
        if (colon <= 0 || colon > 100 || raw.length > 2200) badRequest("Ongeldig zoekveld.")
        raw.substring(0, colon) to raw.substring(colon + 1).trim()
    }.filter { it.second.isNotEmpty() }
}

private fun badRequest(message: String): Nothing = throw ResponseStatusException(HttpStatus.BAD_REQUEST, message)
