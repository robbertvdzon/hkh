package nl.vdzon.hkh.auth

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class AdminAuthConfigTest {
    @Test
    fun `normalizes the admin allowlist`() {
        val config = AdminAuthConfig("client-id", " Admin@Example.com,second@example.com ")

        assertTrue(config.enabled)
        assertTrue(config.loginEnabled)
        assertTrue(config.isAllowed("admin@example.com"))
        assertEquals(2, config.allowedEmails.size)
    }

    @Test
    fun `empty configuration disables login`() {
        val config = AdminAuthConfig("", "")
        assertFalse(config.enabled)
        assertFalse(config.loginEnabled)
    }

    @Test
    fun `a client id alone enables public login without administrators`() {
        val config = AdminAuthConfig("client-id", "")
        assertTrue(config.loginEnabled)
        assertFalse(config.enabled)
        assertFalse(config.isAllowed("anyone@example.com"))
    }

    @Test
    fun `an allowlist without client id is rejected`() {
        assertFailsWith<IllegalArgumentException> { AdminAuthConfig("", "admin@example.com") }
    }
}
