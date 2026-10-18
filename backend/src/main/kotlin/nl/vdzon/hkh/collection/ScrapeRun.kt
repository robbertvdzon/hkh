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
    /** Documentteksten die in deze run uit PDF's zijn gehaald, en hoeveel daarvan mislukten. */
    val documents: Int = 0,
    val documentsFailed: Int = 0,
    /** AI-kaarten die in deze run zijn gemaakt, en hoeveel daarvan mislukten. */
    val cards: Int = 0,
    val cardsFailed: Int = 0,
)
