package nl.vdzon.hkh.auth

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

/**
 * Fail-closed boundary for disposable PR environments and the standing acceptance environment.
 *
 * Preview authentication may only be enabled with one of the two expected markers and the
 * own database on the shared non-production server or the legacy in-namespace service. A copied production database URL therefore prevents the backend
 * from starting instead of silently exposing production. Only the per-PR marker requires a positive
 * pull-request number; the acceptance environment is not tied to a PR.
 */
@Component
class PreviewRuntimeConfig(
    @param:Value("\${hkh.preview.enabled:false}") val enabled: Boolean,
    @param:Value("\${hkh.preview.marker:}") val marker: String,
    @param:Value("\${HKH_DATABASE_URL:}") databaseUrl: String,
    @param:Value("\${hkh.preview.pr-number:}") previewPrNumber: String,
) {
    val prNumber: Int? = previewPrNumber.toIntOrNull()?.takeIf { it > 0 }

    init {
        if (enabled) {
            require(marker == REQUIRED_MARKER || marker == ACCEPTANCE_MARKER) {
                "Preview mode requires the expected preview or acceptance marker"
            }
            require(isIsolatedDatabase(databaseUrl)) {
                "Preview mode requires its own verified non-production database"
            }
            if (marker == REQUIRED_MARKER) {
                requireNotNull(prNumber) { "Preview mode requires a positive pull-request number" }
            } else {
                require(previewPrNumber.isBlank()) { "The acceptance environment is not tied to a pull-request number" }
            }
        } else {
            require(marker.isBlank()) { "The preview marker may not be set outside preview mode" }
            require(previewPrNumber.isBlank()) { "The preview PR number may not be set outside preview mode" }
        }
    }

    private fun isIsolatedDatabase(jdbcUrl: String): Boolean = runCatching {
        if (!jdbcUrl.startsWith("jdbc:postgresql://")) return false
        val uri = URI(jdbcUrl.removePrefix("jdbc:"))
        if (uri.rawUserInfo != null || uri.rawFragment != null || uri.port !in listOf(-1, 5432)) return false
        val parameters = uri.rawQuery?.split("&")?.map { part ->
            val pair = part.split("=", limit = 2)
            if (pair.size != 2) return false
            URLDecoder.decode(pair[0], StandardCharsets.UTF_8) to URLDecoder.decode(pair[1], StandardCharsets.UTF_8)
        } ?: emptyList()
        if (parameters.map { it.first }.distinct().size != parameters.size) return false
        if (parameters.any { it.first !in setOf("sslmode", "sslrootcert") }) return false
        if (uri.host == "database" && uri.rawPath == "/hkh") return true
        if (uri.host !in setOf("postgres.postgres-nonproduction.svc", "postgres.postgres-nonproduction.svc.cluster.local")) return false
        val expected = if (marker == ACCEPTANCE_MARKER) Regex("/hkh_acc")
            else Regex("/hkh_pr_${prNumber}_[a-f0-9]{8}")
        val query = parameters.toMap()
        expected.matches(uri.rawPath) && query["sslmode"] == "verify-full" &&
            query["sslrootcert"] == "/etc/postgres-ca/ca.crt"
    }.getOrDefault(false)

    fun accepts(header: String?): Boolean = enabled && header == ADMIN_HEADER_VALUE

    /** Null voor de acceptatieomgeving: die is niet aan een PR gebonden en heeft geen pr_number. */
    fun requireSeedingAllowed(): Int? {
        require(enabled) { "Preview test data may only be generated inside a verified preview environment" }
        return prNumber
    }

    companion object {
        const val REQUIRED_MARKER = "hkh-pr-preview"
        const val ACCEPTANCE_MARKER = "hkh-acceptance"
        const val ADMIN_HEADER = "X-HKH-Preview-Admin"
        const val ADMIN_HEADER_VALUE = "enabled"
        const val ADMIN_EMAIL = "preview-admin@hkh.invalid"

    }
}
