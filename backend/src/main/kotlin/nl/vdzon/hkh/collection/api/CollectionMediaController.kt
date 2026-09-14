package nl.vdzon.hkh.collection.api

import nl.vdzon.hkh.collection.CollectionLinks
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import java.util.Base64
import org.springframework.http.CacheControl
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody

/** Fixed import-host allowlist, bounded redirects; never redirects the browser to the import site. */
@RestController
class CollectionMediaController {
    private val client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15))
        .followRedirects(HttpClient.Redirect.NEVER).build()

    @GetMapping("/api/collection-media/{token}")
    fun get(@PathVariable token: String): ResponseEntity<StreamingResponseBody> {
        var url = runCatching {
            require(token.length <= 8192)
            String(Base64.getUrlDecoder().decode(token), Charsets.UTF_8)
        }.getOrElse { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Ongeldige mediaverwijzing") }
        repeat(4) {
            if (!CollectionLinks.isImportUrl(url)) throw ResponseStatusException(HttpStatus.NOT_FOUND)
            val upstream = try {
                client.send(HttpRequest.newBuilder(URI(url)).timeout(Duration.ofSeconds(30)).GET().build(),
                    HttpResponse.BodyHandlers.ofInputStream())
            } catch (_: Exception) {
                throw ResponseStatusException(HttpStatus.BAD_GATEWAY, "Media kon niet worden geladen")
            }
            if (upstream.statusCode() in 300..399) {
                upstream.body().close()
                url = URI(url).resolve(upstream.headers().firstValue("Location").orElse("")).toString()
            } else {
                val type = upstream.headers().firstValue("Content-Type").orElse("").substringBefore(';').lowercase()
                if (upstream.statusCode() != 200 || type !in setOf("image/jpeg", "image/png", "image/gif", "image/webp", "application/pdf")) {
                    upstream.body().close()
                    throw ResponseStatusException(HttpStatus.NOT_FOUND, "Media niet beschikbaar")
                }
                val stream = StreamingResponseBody { output -> upstream.body().use { it.copyTo(output) } }
                return ResponseEntity.ok().contentType(MediaType.parseMediaType(type))
                    .cacheControl(CacheControl.maxAge(Duration.ofHours(24)).cachePublic())
                    .header("X-Content-Type-Options", "nosniff").body(stream)
            }
        }
        throw ResponseStatusException(HttpStatus.BAD_GATEWAY, "Media kon niet worden geladen")
    }
}
