package nl.vdzon.hkh.aisearch

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "hkh.ai-search")
data class AiSearchProperties(
    val enabled: Boolean = false,
    val runtimeBaseUrl: String = "https://agent-runtime.vdzonsoftware.nl",
    val runtimeToken: String = "",
    val vendorId: String = "openai",
    val model: String = "gpt-5.6-sol",
    val mode: String = "SUBSCRIPTION",
    val executionTimeoutSeconds: Int = 900,
    val pollIntervalMs: Long = 2_000,
    val maxActiveSearches: Int = 3,
)
