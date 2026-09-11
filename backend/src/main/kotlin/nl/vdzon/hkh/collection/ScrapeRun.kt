package nl.vdzon.hkh.collection

import java.time.Instant

enum class ScrapeStatus { RUNNING, COMPLETED, FAILED }

data class ScrapeRun(
    val id: Long,
    val status: ScrapeStatus,
    val startedBy: String,
    val mode: ScrapeMode,
    val force: Boolean,
    val startedAt: Instant,
    val finishedAt: Instant?,
    val total: Int,
    val processed: Int,
    val skipped: Int,
    val failed: Int,
    val currentCollection: String?,
    val message: String?,
    val perCollection: Map<String, Int>,
)
