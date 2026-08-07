package nl.vdzon.hkh

import java.nio.file.Path
import kotlin.io.path.readText
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.modulith.core.ApplicationModules

class ModulithArchitectureTest {
    private val modules = setOf("auth", "configuration", "news", "previewdata", "system")
    private val sourceRoot = Path.of("src/main/kotlin/nl/vdzon/hkh")

    @Test
    fun `application module boundaries are valid`() {
        ApplicationModules.of(HkhApplication::class.java).verify()
    }

    @Test
    fun `every module declares fail closed dependencies`() {
        modules.forEach { module ->
            val metadata = sourceRoot.resolve("$module/package-info.java")
            assertTrue(metadata.toFile().isFile, "Module $module has no package-info.java")
            val text = metadata.readText()
            assertTrue(text.contains("@org.springframework.modulith.ApplicationModule"))
            assertTrue(text.contains("allowedDependencies"))
            assertFalse(text.contains("\"*\""), "Module $module uses a dependency wildcard")
        }
    }
}
