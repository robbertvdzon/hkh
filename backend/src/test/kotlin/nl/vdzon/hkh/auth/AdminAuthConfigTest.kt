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
        assertTrue(config.isAllowed("admin@example.com"))
        assertEquals(2, config.allowedEmails.size)
    }

    @Test
    fun `empty configuration disables login`() {
        assertFalse(AdminAuthConfig("", "").enabled)
    }

    @Test
    fun `partial configuration is rejected`() {
        assertFailsWith<IllegalArgumentException> { AdminAuthConfig("client-id", "") }
    }
}
