package nl.vdzon.hkh.collection

/** Explicit literal matching for the collection UI; web preserves existing saved searches. */
data class CollectionSearchOptions(
    val mode: String = "web",
    val partial: Boolean = false,
    val field: String = "all",
    val yearFrom: Int? = null,
    val yearTo: Int? = null,
    val filters: Map<String, List<String>> = emptyMap(),
    val sort: String = "relevance",
    val recentDays: Int? = null,
    val documentText: Boolean = true,
)

data class FacetValue(val value: String, val count: Long)
data class CollectionFacet(val field: String, val values: List<FacetValue>, val totalValues: Long)

object CollectionCatalog {
    val facets = linkedMapOf(
        "archief" to listOf("Type publicatie", "Thema", "Auteur(s)", "Uitgever"),
        "beeldbank" to listOf("Thema", "Wijk in Heemskerk", "Straatnaam", "Fotograaf", "Uit Map of Album"),
        "library" to listOf("Genre", "Medium", "Auteur(s)"),
        "bidprent" to listOf("Geboren te", "Overleden te", "Leeftijd"),
        "artikelen" to listOf("Rubriek", "Auteur(s)", "Medium"),
        "objecten" to listOf("Thema object", "Materiaal"),
    )
    val documentFields = listOf("OCR-tekst", "OCR tekst", "OCR", "Documenttekst", "Tekst publicatie")
}
