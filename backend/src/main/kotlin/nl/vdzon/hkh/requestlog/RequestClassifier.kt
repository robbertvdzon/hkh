package nl.vdzon.hkh.requestlog

import java.net.InetAddress

/**
 * Herkent bots en testverkeer aan het browsertype en kapt IP-adressen af. Zonder afhankelijkheden,
 * zodat het los te testen is.
 */
object RequestClassifier {
    /** Aanroepen van de beheerder of van Claude die zichzelf zo noemen tellen mee, maar als testverkeer. */
    const val TEST_AGENT_PREFIX = "HKH-Test"

    private val BOT_MARKERS = listOf(
        "bot", "crawl", "spider", "slurp", "scrape", "headless", "curl/", "wget", "python-requests", "python-urllib", "aiohttp",
        "go-http-client", "java/", "libwww", "httpclient", "axios", "node-fetch", "undici", "postman", "monitor", "uptime",
        "preview", "facebookexternalhit", "embedly", "pingdom", "lighthouse", "bytespider", "perplexity", "scanner", "nmap",
    )

    fun isTestAgent(userAgent: String?): Boolean = userAgent?.trim()?.startsWith(TEST_AGENT_PREFIX, ignoreCase = true) == true

    /** Een leeg browsertype is een script; testverkeer is nooit een bot. De HKH-app zelf (Dart) telt als gewone bezoeker. */
    fun isBot(userAgent: String?): Boolean {
        if (isTestAgent(userAgent)) return false
        val agent = userAgent?.trim()?.lowercase().orEmpty()
        if (agent.isEmpty()) return true
        return BOT_MARKERS.any { it in agent }
    }

    /** IPv4 naar /24 (laatste deel 0), IPv6 naar /48; geen geldig adres geeft null. */
    fun anonymizeIp(ip: String?): String? {
        val trimmed = ip?.trim().orEmpty()
        if (trimmed.isEmpty() || !Regex("[0-9a-fA-F:.]+").matches(trimmed)) return null
        val bytes = runCatching { InetAddress.getByName(trimmed).address }.getOrNull() ?: return null
        return when (bytes.size) {
            4 -> "${bytes[0].toInt() and 255}.${bytes[1].toInt() and 255}.${bytes[2].toInt() and 255}.0"
            16 -> (0 until 3).joinToString(":") { i ->
                "%x".format(((bytes[2 * i].toInt() and 255) shl 8) or (bytes[2 * i + 1].toInt() and 255))
            } + "::"
            else -> null
        }
    }
}
