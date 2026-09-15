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
        assertTrue(config.requireSeedingAllowed() == null)
    }

    @Test
    fun `rejects a pr number with the acceptance marker`() {
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(true, PreviewRuntimeConfig.ACCEPTANCE_MARKER, "jdbc:postgresql://database:5432/hkh", "42")
        }
    }
    private val central = "jdbc:postgresql://postgres.postgres-nonproduction.svc:5432/"
    private val tls = "?sslmode=verify-full&sslrootcert=/etc/postgres-ca/ca.crt"

    @Test
    fun `allows only the own central acceptance and PR databases`() {
        assertTrue(PreviewRuntimeConfig(true, PreviewRuntimeConfig.ACCEPTANCE_MARKER, central + "hkh_acc" + tls, "").enabled)
        assertTrue(PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, central + "hkh_pr_42_abcdef12" + tls, "42").enabled)
    }

    @Test
    fun `rejects cross environment connections and JDBC overrides`() {
        val invalid = listOf(
            central + "hkh_prod" + tls,
            central.replace("nonproduction", "production") + "hkh_acc" + tls,
            central + "pvdd_acc" + tls,
            central + "hkh_pr_43_abcdef12" + tls,
            central + "hkh_acc",
            central + "hkh_acc" + tls.replace("verify-full", "require"),
            central + "hkh_acc" + tls + "&sslmode=disable",
            central + "hkh_acc" + tls + "&host=production",
            central + "hkh_acc" + tls + "&options=unsafe",
            central.replace(":5432", ":5433") + "hkh_acc" + tls,
            central.replace("//", "//user@") + "hkh_acc" + tls,
            central + "hkh_acc" + tls + "#fragment",
            "jdbc:postgresql://database:5432/hkh?host=production",
        )
        invalid.forEach { url ->
            assertFailsWith<IllegalArgumentException> {
                PreviewRuntimeConfig(true, PreviewRuntimeConfig.ACCEPTANCE_MARKER, url, "")
            }
        }
        assertFailsWith<IllegalArgumentException> {
            PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, central + "hkh_pr_43_abcdef12" + tls, "42")
        }
    }
}
