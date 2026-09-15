package nl.vdzon.hkh.collection.api

import nl.vdzon.hkh.collection.CollectionLinks
import java.io.ByteArrayOutputStream
import java.io.InputStream
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
        val upstream = open(token)
        val stream = StreamingResponseBody { output -> upstream.body.use { it.copyTo(output) } }
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(upstream.type))
            .cacheControl(CacheControl.maxAge(Duration.ofHours(24)).cachePublic())
            .header("X-Content-Type-Options", "nosniff").body(stream)
    }

    @GetMapping("/api/collection-thumbnail/{token}")
    fun thumbnail(@PathVariable token: String): ResponseEntity<ByteArray> {
        val upstream = open(token)
        if (upstream.type != "application/pdf") {
            upstream.body.close()
            throw ResponseStatusException(HttpStatus.NOT_FOUND, "Geen scan beschikbaar")
        }
        val jpeg = try {
            upstream.body.use { PdfThumbnailRenderer.render(readLimited(it)) }
        } catch (_: Exception) {
            throw ResponseStatusException(HttpStatus.NOT_FOUND, "Voorvertoning niet beschikbaar")
        }
        return ResponseEntity.ok().contentType(MediaType.IMAGE_JPEG)
            .cacheControl(CacheControl.maxAge(Duration.ofDays(7)).cachePublic())
            .header("X-Content-Type-Options", "nosniff").body(jpeg)
    }

    private fun open(token: String): RemoteMedia {
        var url = decode(token)
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
                return RemoteMedia(type, upstream.body())
            }
        }
        throw ResponseStatusException(HttpStatus.BAD_GATEWAY, "Media kon niet worden geladen")
    }

    private fun decode(token: String): String = runCatching {
        require(token.length <= 8192)
        String(Base64.getUrlDecoder().decode(token), Charsets.UTF_8)
    }.getOrElse { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Ongeldige mediaverwijzing") }

    private fun readLimited(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read < 0) return output.toByteArray()
            total += read
            if (total > MAX_THUMBNAIL_SOURCE_BYTES) {
                throw ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "Scan is te groot voor een voorvertoning")
            }
            output.write(buffer, 0, read)
        }
    }

    private data class RemoteMedia(val type: String, val body: InputStream)

    private companion object {
        const val MAX_THUMBNAIL_SOURCE_BYTES = 20 * 1024 * 1024
    }
}
