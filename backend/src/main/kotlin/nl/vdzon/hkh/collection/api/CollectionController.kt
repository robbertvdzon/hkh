package nl.vdzon.hkh.collection.api

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
    val hasPdf: Boolean,
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
    fun search(
        @RequestParam(name = "q", required = false) query: String?,
        @RequestParam(name = "collection", required = false) collection: String?,
        @RequestParam(name = "fq", required = false) fieldQueries: List<String>?,
        @RequestParam(name = "year", required = false) year: Int?,
        @RequestParam(name = "page", defaultValue = "0") page: Int,
        @RequestParam(name = "size", defaultValue = "20") size: Int,
    ): SearchResponse {
        val result = service.search(query, collection, parseFieldQueries(fieldQueries), page, size, year)
        return SearchResponse(
            items = result.items.map(CollectionItem::toSummary),
            total = result.total,
            page = result.page,
            pageSize = result.pageSize,
        )
    }

    /** Elke `fq`-parameter heeft de vorm `veldnaam:zoekterm`, bv. `fq=Auteur(s):Jansen`. */
    private fun parseFieldQueries(raw: List<String>?): Map<String, String> =
        raw.orEmpty()
            .mapNotNull { entry ->
                val colon = entry.indexOf(':')
                if (colon <= 0) null else entry.substring(0, colon) to entry.substring(colon + 1)
            }
            .toMap()

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
    hasPdf = pdfUrl != null,
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
