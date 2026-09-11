package nl.vdzon.hkh.collection

import org.springframework.stereotype.Service

@Service
class CollectionSearchService(private val store: CollectionItemStore) {

    fun collections(): List<CollectionCount> = store.counts()

    fun total(): Long = store.totalCount()

    fun detail(collection: String, ident: String): CollectionItem? = store.find(collection, ident)

    /** Namen van velden die daadwerkelijk voorkomen (optioneel beperkt tot één collectie), voor de veld-kiezer. */
    fun fields(collection: String?): List<String> = store.distinctFields(collection?.trim()?.takeIf { it.isNotEmpty() })

    fun search(query: String?, collection: String?, field: String?, page: Int, pageSize: Int): SearchResult {
        val safePage = page.coerceAtLeast(0)
        val safeSize = pageSize.coerceIn(1, MAX_PAGE_SIZE)
        val cleanedQuery = query?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedCollection = collection?.trim()?.takeIf { it.isNotEmpty() }
        val cleanedField = field?.trim()?.takeIf { it.isNotEmpty() }
        val items = store.search(cleanedQuery, cleanedCollection, cleanedField, safeSize, safePage * safeSize)
        val total = store.searchCount(cleanedQuery, cleanedCollection, cleanedField)
        return SearchResult(items, total, safePage, safeSize)
    }

    private companion object {
        const val MAX_PAGE_SIZE = 100
    }
}
