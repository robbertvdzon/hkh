package nl.vdzon.hkh.collection

import org.springframework.stereotype.Service

@Service
class CollectionSearchService(private val store: CollectionItemStore) {

    fun collections(): List<CollectionCount> = store.counts()

    fun total(): Long = store.totalCount()

    fun detail(collection: String, ident: String): CollectionItem? = store.find(collection, ident)

    /** Namen van velden die daadwerkelijk voorkomen (optioneel beperkt tot één collectie), voor de veld-kiezer. */
    fun fields(collection: String?): List<String> = store.distinctFields(collection?.trim()?.takeIf { it.isNotEmpty() })

    /**
     * [fieldQueries] bevat per opgegeven veld een eigen zoekterm (bv. "Auteur(s)" -> "Jansen"),
     * ANDed met elkaar en met [query] (dat, indien gezet, over alle velden zoekt).
     */
    fun search(query: String?, collection: String?, fieldQueries: Map<String, String>, page: Int, pageSize: Int): SearchResult {
        val safePage = page.coerceAtLeast(0)
        val safeSize = pageSize.coerceIn(1, MAX_PAGE_SIZE)
        val cleanedQuery = query?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedCollection = collection?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedFieldQueries = fieldQueries
            .mapValues { it.value.trim() }
            .filterKeys { it.isNotBlank() }
            .filterValues { it.isNotEmpty() }
        val items = store.search(cleanedQuery, cleanedCollection, cleanedFieldQueries, safeSize, safePage * safeSize)
        val total = store.searchCount(cleanedQuery, cleanedCollection, cleanedFieldQueries)
        return SearchResult(items, total, safePage, safeSize)
    }

    private companion object {
        const val MAX_PAGE_SIZE = 100
    }
}
