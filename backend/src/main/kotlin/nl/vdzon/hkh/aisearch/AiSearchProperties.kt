package nl.vdzon.hkh.aisearch

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "hkh.ai-search")
data class AiSearchProperties(
    val enabled: Boolean = false,
    val runtimeBaseUrl: String = "https://agent-runtime.vdzonsoftware.nl",
    val runtimeToken: String = "",
    val vendorId: String = "anthropic",
    val model: String = "claude-sonnet-5-5",
    val mode: String = "SUBSCRIPTION",
    /** Standaardmodel voor de kaartenextractie (bulkwerk): klein en snel, tenzij een beheerder anders kiest. */
    val extractionModel: String = "claude-haiku-4-5-20251001",
    val executionTimeoutSeconds: Int = 900,
    val pollIntervalMs: Long = 2_000,
    val maxActiveSearches: Int = 3,
)
