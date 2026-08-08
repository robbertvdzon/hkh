package nl.vdzon.hkh.auth

import kotlin.test.Test
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PreviewRuntimeConfigTest {
    @Test
    fun `accepts preview admin with marker and isolated database`() {
        val config = PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://database:5432/hkh", "42")

        assertTrue(config.accepts(PreviewRuntimeConfig.ADMIN_HEADER_VALUE))
        assertFalse(config.accepts("wrong"))
    }

    @Test
    fun `rejects preview mode with an external database`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://prod.example/hkh", "42")
        }
    }

    @Test
    fun `rejects a preview marker in production mode`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(false, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://database:5432/hkh", "")
        }
    }

    @Test
    fun `rejects preview mode without a positive PR number`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://database:5432/hkh", "0")
        }
    }

    @Test
    fun `rejects a preview PR number in production mode`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(false, "", "jdbc:postgresql://database:5432/hkh", "42")
        }
    }

    @Test
    fun `accepts the acceptance marker without a pr number`() {
        val config = PreviewRuntimeConfig(true, PreviewRuntimeConfig.ACCEPTANCE_MARKER, "jdbc:postgresql://database:5432/hkh", "")

        assertTrue(config.accepts(PreviewRuntimeConfig.ADMIN_HEADER_VALUE))
        assertTrue(config.requireSeedingAllowed() == 0)
    }

    @Test
    fun `rejects a pr number with the acceptance marker`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(true, PreviewRuntimeConfig.ACCEPTANCE_MARKER, "jdbc:postgresql://database:5432/hkh", "42")
        }
    }
}
