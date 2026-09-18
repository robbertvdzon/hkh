package nl.vdzon.hkh.collection

import org.springframework.stereotype.Service

@Service
class CollectionSearchService(private val store: CollectionItemStore) {

    fun collections(): List<CollectionCount> = store.counts()

    fun total(): Long = store.totalCount()

    fun detail(collection: String, ident: String): CollectionItem? = store.find(collection, ident)

    /**
     * [fieldQueries] bevat per opgegeven veld een eigen zoekterm (bv. "Auteur(s)" -> "Jansen"),
     * ANDed met elkaar en met [query] (dat, indien gezet, over alle velden zoekt). [year] is een
     * exacte match op het jaartal (geen tekst-zoekopdracht).
     */
    fun search(
        query: String?,
        collection: String?,
        fieldQueries: Map<String, String>,
        page: Int,
        pageSize: Int,
        year: Int? = null,
        options: CollectionSearchOptions = CollectionSearchOptions(),
    ): SearchResult {
        val safePage = page.coerceIn(0, 100000)
        val safeSize = pageSize.coerceIn(1, MAX_PAGE_SIZE)
        val cleanedQuery = query?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedCollection = collection?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedFieldQueries = fieldQueries
            .mapValues { it.value.trim() }
            .filterKeys { it.isNotBlank() }
            .filterValues { it.isNotEmpty() }
        if (cleanedQuery == null && cleanedFieldQueries.isEmpty() && year == null &&
            options.filters.values.all { it.isEmpty() } && options.yearFrom == null &&
            options.yearTo == null && options.recentDays == null) {
            return SearchResult(emptyList(), 0, safePage, safeSize)
        }
        val items = store.search(cleanedQuery, cleanedCollection, cleanedFieldQueries, safeSize, safePage * safeSize, year, options)
        val counts = store.searchCounts(cleanedQuery, cleanedFieldQueries, year, options)
        val total = if (cleanedCollection == null) counts.sumOf { it.count }
            else counts.find { it.collection == cleanedCollection }?.count ?: 0L
        return SearchResult(items, total, safePage, safeSize, counts)
    }

    fun facet(query: String?, collection: String, fieldQueries: Map<String, String>, year: Int?, options: CollectionSearchOptions, field: String, valueQuery: String) =
        store.facet(query, collection, fieldQueries, year, options, field, valueQuery)

    fun documentTextAvailable() = store.documentTextAvailable()

    private companion object {
        const val MAX_PAGE_SIZE = 100
    }
}
