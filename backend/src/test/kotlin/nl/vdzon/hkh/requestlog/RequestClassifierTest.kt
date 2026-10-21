package nl.vdzon.hkh.requestlog

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class RequestClassifierTest {
    @Test
    fun `scripts and crawlers are bots, browsers and the HKH app are not`() {
        assertTrue(RequestClassifier.isBot(null))
        assertTrue(RequestClassifier.isBot("  "))
        assertTrue(RequestClassifier.isBot("curl/8.7.1"))
        assertTrue(RequestClassifier.isBot("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"))
        assertTrue(RequestClassifier.isBot("python-requests/2.32"))
        assertTrue(RequestClassifier.isBot("Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.1)"))
        assertTrue(RequestClassifier.isBot("Go-http-client/2.0"))
        assertFalse(RequestClassifier.isBot("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"))
        assertFalse(RequestClassifier.isBot("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1"))
        // De Flutter-app op Android meldt zich als Dart en is een gewone bezoeker.
        assertFalse(RequestClassifier.isBot("Dart/3.9 (dart:io)"))
    }

    @Test
    fun `test traffic is recognised by its agent and is never a bot`() {
        assertTrue(RequestClassifier.isTestAgent("HKH-Test/claude"))
        assertTrue(RequestClassifier.isTestAgent("hkh-test"))
        assertFalse(RequestClassifier.isTestAgent("curl/8.7.1"))
        assertFalse(RequestClassifier.isBot("HKH-Test/claude curl/8.7.1"))
    }

    @Test
    fun `addresses are truncated to a network, invalid ones give null`() {
        assertEquals("217.120.100.0", RequestClassifier.anonymizeIp("217.120.100.76"))
        assertEquals("2001:db8:85a3::", RequestClassifier.anonymizeIp("2001:db8:85a3:8d3:1319:8a2e:370:7348"))
        assertEquals("2001:db8:0::", RequestClassifier.anonymizeIp("2001:db8::1"))
        assertEquals("1.2.3.0", RequestClassifier.anonymizeIp("::ffff:1.2.3.4"))
        assertNull(RequestClassifier.anonymizeIp("niet-een-adres"))
        assertNull(RequestClassifier.anonymizeIp(""))
        assertNull(RequestClassifier.anonymizeIp(null))
    }
}
