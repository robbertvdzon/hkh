package nl.vdzon.hkh.collection

import java.net.URI
import java.util.concurrent.atomic.AtomicReference
import kotlin.test.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.http.client.ClientHttpRequestInterceptor
import org.springframework.mock.http.client.MockClientHttpResponse
import org.springframework.web.client.RestClient
import org.springframework.web.util.UriComponentsBuilder

/**
 * RestClient.get().uri(String) treats a path as a template and re-encodes it, so a literal
 * "%" already escaped as "%25" (the ZCBS "search everything" wildcard) becomes "%2525" -
 * which the HKH server reads as a search for the literal text "%25", returning zero results.
 * This bit [ZcbsClient]: its "toon alles" query silently found nothing until it was fixed to
 * build the URI itself via [UriComponentsBuilder] and pass a pre-built java.net.URI instead
 * (see ZcbsClient.get). This test locks in that URI-object approach.
 */
class ZcbsQueryEncodingTest {
    @Test
    fun `building the URI via UriComponentsBuilder avoids double-encoding the wildcard`() {
        val captured = AtomicReference<URI>()
        val interceptor = ClientHttpRequestInterceptor { request, _, _ ->
            captured.set(request.uri)
            MockClientHttpResponse(ByteArray(0), 200)
        }
        val client = RestClient.builder()
            .baseUrl("https://www.historischekringheemskerk.nl")
            .requestInterceptor(interceptor)
            .build()

        val uri = UriComponentsBuilder.fromUriString("https://www.historischekringheemskerk.nl")
            .path("/cgi-bin/archief.pl")
            .queryParam("search", "%")
            .queryParam("veld", "all")
            .queryParam("display", "list")
            .queryParam("istart", 1)
            .build()
            .encode()
            .toUri()

        client.get().uri(uri).retrieve().toBodilessEntity()

        assertEquals("search=%25&veld=all&display=list&istart=1", captured.get().rawQuery)
    }
}
