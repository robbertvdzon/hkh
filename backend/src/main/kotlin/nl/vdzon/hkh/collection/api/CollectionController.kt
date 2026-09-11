package nl.vdzon.hkh.collection.api

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

data class FieldsResponse(val fields: List<String>)

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
        @RequestParam(name = "field", required = false) field: String?,
        @RequestParam(name = "page", defaultValue = "0") page: Int,
        @RequestParam(name = "size", defaultValue = "20") size: Int,
    ): SearchResponse {
        val result = service.search(query, collection, field, page, size)
        return SearchResponse(
            items = result.items.map(CollectionItem::toSummary),
            total = result.total,
            page = result.page,
            pageSize = result.pageSize,
        )
    }

    /** Namen van velden waarop gericht gezocht kan worden (optioneel beperkt tot één collectie). */
    @GetMapping("/fields")
    fun fields(@RequestParam(name = "collection", required = false) collection: String?): FieldsResponse =
        FieldsResponse(service.fields(collection))

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
    imageUrl = imageUrl,
    hasPdf = pdfUrl != null,
)

private fun CollectionItem.toDetail() = CollectionItemDetail(
    collection = collection,
    ident = ident,
    title = title,
    description = description,
    year = year,
    imageUrl = imageUrl,
    pdfUrl = pdfUrl,
    detailUrl = detailUrl,
    fields = fields,
)
