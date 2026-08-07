package nl.vdzon.hkh.auth

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

/**
 * Fail-closed boundary for disposable PR environments.
 *
 * Preview authentication may only be enabled with the explicit marker and an
 * in-namespace database service. A copied production database URL therefore
 * prevents the backend from starting instead of silently exposing production.
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
            require(marker == REQUIRED_MARKER) { "Preview mode requires the expected preview marker" }
            require(PREVIEW_DATABASE.matches(databaseUrl)) {
                "Preview mode may only use the in-namespace preview database"
            }
            requireNotNull(prNumber) { "Preview mode requires a positive pull-request number" }
        } else {
            require(marker.isBlank()) { "The preview marker may not be set outside preview mode" }
            require(previewPrNumber.isBlank()) { "The preview PR number may not be set outside preview mode" }
        }
    }

    fun accepts(header: String?): Boolean = enabled && header == ADMIN_HEADER_VALUE

    fun requireSeedingAllowed(): Int = requireNotNull(prNumber) {
        "Preview test data may only be generated inside a verified preview environment"
    }

    companion object {
        const val REQUIRED_MARKER = "hkh-pr-preview"
        const val ADMIN_HEADER = "X-HKH-Preview-Admin"
        const val ADMIN_HEADER_VALUE = "enabled"
        const val ADMIN_EMAIL = "preview-admin@hkh.invalid"

        private val PREVIEW_DATABASE =
            Regex("^jdbc:postgresql://database(?::5432)?/hkh(?:\\?.*)?$")
    }
}
