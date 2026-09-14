package nl.vdzon.hkh.collection

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets.UTF_8
import java.util.Base64

/** Public links never expose the import server. Also translates historical saved answers. */
object CollectionLinks {
    const val PUBLIC_ORIGIN = "https://hkh.vdzonsoftware.nl"
    private const val LEGACY_HOST = "historischekringheemskerk.nl"
    private val legacyUrl = Regex("""(?i)(?:https?://|//)?(?:[a-z0-9-]+\.)*historischekringheemskerk\.nl(?::\d+)?(?:/[^\s<>"'\[\]{}]*)?""")
    private val recordPath = Regex("/cgi-bin/([A-Za-z0-9_-]+)\\.pl", RegexOption.IGNORE_CASE)

    fun detail(collection: String, ident: String): String =
        "$PUBLIC_ORIGIN/#/objecten/${encode(collection)}/${encode(ident)}"

    fun isImportUrl(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme in listOf("http", "https") && uri.userInfo == null && uri.port == -1 &&
            (uri.host.equals(LEGACY_HOST, true) || uri.host.equals("www.$LEGACY_HOST", true))
    }.getOrDefault(false)

    fun media(value: String?): String? = value?.let {
        if (isImportUrl(it)) "$PUBLIC_ORIGIN/api/collection-media/${Base64.getUrlEncoder().withoutPadding().encodeToString(it.toByteArray(UTF_8))}"
        else it
    }

    fun safeMedia(value: String?): String? = value?.takeIf { url ->
        isImportUrl(url) || runCatching {
            val uri = URI(url)
            uri.scheme == "https" && uri.host == "hkh.vdzonsoftware.nl" && uri.userInfo == null
        }.getOrDefault(false)
    }?.let(::media)

    fun rewrite(text: String): String = legacyUrl.replace(text) { match ->
        val original = match.value
        // Closing punctuation belongs to prose / Markdown, not to the URL.
        val url = original.trimEnd(')', '.', ',', ';')
        val suffix = original.substring(url.length)
        val absolute = when {
            url.startsWith("//") -> "https:$url"
            url.startsWith("http", true) -> url
            else -> "https://$url"
        }
        val replacement = runCatching {
            val uri = URI(absolute.replace("&amp;", "&"))
            val collection = recordPath.matchEntire(uri.path.orEmpty())?.groupValues?.get(1)
            val ident = uri.rawQuery.orEmpty().split('&').firstOrNull { it.startsWith("ident=") }
                ?.substringAfter('=')?.let { URLDecoder.decode(it, UTF_8) }
            when {
                collection != null && !ident.isNullOrBlank() -> detail(collection, ident)
                collection != null -> "$PUBLIC_ORIGIN/#/zoeken?collection=${encode(collection)}"
                uri.path.orEmpty().matches(Regex("(?i).*\\.(jpg|jpeg|png|gif|webp|pdf)")) && isImportUrl(absolute) -> media(absolute)!!
                else -> "$PUBLIC_ORIGIN/#/zoeken"
            }
        }.getOrDefault("$PUBLIC_ORIGIN/#/zoeken")
        replacement + suffix
    }

    private fun encode(value: String) = URLEncoder.encode(value, UTF_8).replace("+", "%20")
}
