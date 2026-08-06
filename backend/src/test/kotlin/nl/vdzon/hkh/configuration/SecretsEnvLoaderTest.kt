package nl.vdzon.hkh.configuration

import java.nio.file.Path
import kotlin.io.path.writeText
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class SecretsEnvLoaderTest {
    @TempDir
    lateinit var tempDir: Path

    @Test
    fun `environment overrides file values`() {
        val file = tempDir.resolve("secrets.env")
        file.writeText("TOKEN=from-file\nQUOTED='safe value'\n")

        val values = SecretsEnvLoader(file, mapOf("TOKEN" to "from-environment")).resolvedValues()

        assertEquals("from-environment", values["TOKEN"])
        assertEquals("safe value", values["QUOTED"])
    }

    @Test
    fun `invalid input reports location without the secret value`() {
        val file = tempDir.resolve("secrets.env")
        file.writeText("not-valid\n")

        val exception = assertFailsWith<IllegalArgumentException> {
            SecretsEnvLoader(file, emptyMap()).resolvedValues()
        }

        assertTrue(exception.message.orEmpty().contains("line 1"))
        assertTrue(!exception.message.orEmpty().contains("not-valid"))
    }

    @Test
    fun `missing required keys report names only`() {
        val file = tempDir.resolve("secrets.env")
        file.writeText("PRESENT=secret-value\n")

        val exception = assertFailsWith<IllegalArgumentException> {
            SecretsEnvLoader(file, emptyMap(), setOf("MISSING")).resolvedValues()
        }

        assertTrue(exception.message.orEmpty().contains("MISSING"))
        assertTrue(!exception.message.orEmpty().contains("secret-value"))
    }

    @Test
    fun `duplicate keys are rejected`() {
        val file = tempDir.resolve("secrets.env")
        file.writeText("TOKEN=first\nTOKEN=second\n")

        assertFailsWith<IllegalArgumentException> {
            SecretsEnvLoader(file, emptyMap()).resolvedValues()
        }
    }
}
