package nl.vdzon.hkh.configuration

import java.nio.file.Files
import java.nio.file.Path
import kotlin.io.path.Path
import kotlin.io.path.name
import kotlin.io.path.readLines

/** Safely parses local KEY=value configuration without executing it as shell code. */
class SecretsEnvLoader(
    private val secretsFile: Path = defaultSecretsFile(),
    private val environment: Map<String, String> = System.getenv(),
    private val requiredKeys: Set<String> = emptySet(),
) {
    fun resolvedValues(): Map<String, String> {
        val values = parseEnvFile(secretsFile) + environment.filterValues { it.isNotBlank() }
        val missing = requiredKeys.filter { values[it].isNullOrBlank() }
        require(missing.isEmpty()) {
            "Missing required configuration: ${missing.sorted().joinToString(", ")}"
        }
        return values
    }

    private fun parseEnvFile(file: Path): Map<String, String> {
        if (!Files.exists(file)) return emptyMap()

        val parsed = LinkedHashMap<String, String>()
        file.readLines().forEachIndexed { index, rawLine ->
            parseLine(file, index + 1, rawLine)?.let { (key, value) ->
                require(key !in parsed) { "Duplicate key '$key' in ${file.name} at line ${index + 1}." }
                if (value.isNotBlank()) parsed[key] = value
            }
        }
        return parsed
    }

    private fun parseLine(file: Path, lineNumber: Int, rawLine: String): Pair<String, String>? {
        val line = rawLine.trim()
        if (line.isBlank() || line.startsWith("#")) return null

        val normalized = line.removePrefix("export ").trim()
        val separatorIndex = normalized.indexOf('=')
        require(separatorIndex > 0) {
            "Invalid ${file.name} line $lineNumber: expected KEY=value."
        }

        val key = normalized.substring(0, separatorIndex).trim()
        require(KEY_PATTERN.matches(key)) {
            "Invalid ${file.name} line $lineNumber: invalid key."
        }
        val value = normalized.substring(separatorIndex + 1).trim().stripSurroundingQuotes()
        return key to value
    }

    private fun String.stripSurroundingQuotes(): String {
        val doubleQuoted = startsWith('"') && endsWith('"') && length >= 2
        val singleQuoted = startsWith('\'') && endsWith('\'') && length >= 2
        return if (doubleQuoted || singleQuoted) substring(1, length - 1) else this
    }

    companion object {
        private val KEY_PATTERN = Regex("[A-Za-z_][A-Za-z0-9_]*")

        fun defaultSecretsFile(
            environment: Map<String, String> = System.getenv(),
            workingDirectory: Path = Path("").toAbsolutePath().normalize(),
        ): Path {
            environment["HKH_SECRETS_FILE"]?.takeIf { it.isNotBlank() }?.let { return Path(it) }
            val candidates = listOf(
                workingDirectory.resolve("secrets.env"),
                workingDirectory.resolve("../secrets.env").normalize(),
            )
            return candidates.firstOrNull(Files::exists) ?: candidates.first()
        }
    }
}
