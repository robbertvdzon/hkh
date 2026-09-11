package nl.vdzon.hkh.collection

import java.net.URI
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.http.client.ClientHttpRequestInterceptor
import org.springframework.mock.http.client.MockClientHttpResponse
import org.springframework.web.client.HttpClientErrorException
import org.springframework.web.client.RestClient

/**
 * The HKH server occasionally answers a scrape request with a transient 502/503/504 (seen in
 * production under load from a long-running scrape). Without a retry, that single hiccup used
 * to abort the entire run and discard everything already fetched for that collection.
 */
class ZcbsClientRetryTest {
    @Test
    fun `retries a transient 502 twice and then succeeds`() {
        val attempts = AtomicInteger(0)
        val interceptor = ClientHttpRequestInterceptor { _, _, _ ->
            if (attempts.getAndIncrement() < 2) {
                MockClientHttpResponse(ByteArray(0), HttpStatus.BAD_GATEWAY)
            } else {
                MockClientHttpResponse("ok".toByteArray(), HttpStatus.OK)
            }
        }
        val client = ZcbsClient(
            ZcbsProperties(),
            RestClient.builder().requestInterceptor(interceptor).build(),
        )

        val result = client.getWithRetry(URI("https://example.test/x"))

        assertEquals("ok", String(result))
        assertEquals(3, attempts.get())
    }

    @Test
    fun `gives up after exhausting its retries`() {
        val attempts = AtomicInteger(0)
        val interceptor = ClientHttpRequestInterceptor { _, _, _ ->
            attempts.incrementAndGet()
            MockClientHttpResponse(ByteArray(0), HttpStatus.BAD_GATEWAY)
        }
        val client = ZcbsClient(
            ZcbsProperties(),
            RestClient.builder().requestInterceptor(interceptor).build(),
        )

        assertFailsWith<org.springframework.web.client.HttpServerErrorException> {
            client.getWithRetry(URI("https://example.test/x"))
        }
        assertEquals(4, attempts.get())
    }

    @Test
    fun `does not retry a non-transient client error`() {
        val attempts = AtomicInteger(0)
        val interceptor = ClientHttpRequestInterceptor { _, _, _ ->
            attempts.incrementAndGet()
            MockClientHttpResponse(ByteArray(0), HttpStatus.NOT_FOUND)
        }
        val client = ZcbsClient(
            ZcbsProperties(),
            RestClient.builder().requestInterceptor(interceptor).build(),
        )

        assertFailsWith<HttpClientErrorException> {
            client.getWithRetry(URI("https://example.test/x"))
        }
        assertEquals(1, attempts.get())
    }
}
