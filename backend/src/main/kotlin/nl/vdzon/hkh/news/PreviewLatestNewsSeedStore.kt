package nl.vdzon.hkh.news

import java.time.Instant

data class PreviewLatestNewsSeed(
    val id: Long,
    val title: String,
    val message: String,
    val publishedAt: Instant,
    val createdAt: Instant,
    val createdBy: String,
)

interface PreviewLatestNewsSeedStore {
    fun upsert(records: List<PreviewLatestNewsSeed>)
}
