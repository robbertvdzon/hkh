package nl.vdzon.hkh.collection

import org.springframework.boot.context.properties.ConfigurationProperties

/**
 * Instellingen voor het scrapen van de publieke ZCBS-beeldbanken op de HKH-website.
 * Standaardwaarden werken tegen de productie-site; alles is te overschrijven via env.
 */
@ConfigurationProperties(prefix = "hkh.zcbs")
data class ZcbsProperties(
    val baseUrl: String = "https://www.historischekringheemskerk.nl",
    val collections: List<String> = listOf(
        "artikelen", "archief", "beeldbank", "library", "bidprent", "objecten", "transcripties",
    ),
    /** Wachttijd tussen twee record-requests, zodat de HKH-server niet belast wordt. */
    val requestDelayMs: Long = 300,
    /** Veiligheidslimiet op het aantal lijstpagina's per collectie. */
    val maxPagesPerCollection: Int = 5000,
    val timeoutSeconds: Long = 20,
)
