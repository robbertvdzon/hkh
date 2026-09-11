package nl.vdzon.hkh.collection

import java.time.Instant

/**
 * Eén record uit een ZCBS-collectie (artikelen, foto's, objecten, ...).
 * Alleen metadata; het beeld/de PDF blijft op de HKH-webserver staan en wordt
 * via [imageUrl] / [pdfUrl] on-demand geladen.
 */
data class CollectionItem(
    val id: Long,
    val collection: String,
    val ident: String,
    val title: String,
    val description: String,
    val year: Int?,
    val imageUrl: String?,
    val pdfUrl: String?,
    val detailUrl: String,
    val fields: Map<String, String>,
    val isComplete: Boolean,
    val scrapedAt: Instant,
)

/** Ruwe, geparste weergave van een recordpagina, vóór opslag. */
data class ScrapedRecord(
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

data class CollectionCount(val collection: String, val count: Long)

data class SearchResult(
    val items: List<CollectionItem>,
    val total: Long,
    val page: Int,
    val pageSize: Int,
)
