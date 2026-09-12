package nl.vdzon.hkh.auth

import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.server.ResponseStatusException

data class AuthenticatedAdmin(val email: String)

/**
 * Beheerroutes accepteren het eigen sessietoken (zie [SessionService]) van een gebruiker op de
 * allowlist, of de preview-header in een afgeschermde previewomgeving.
 */
@Component
class AdminAuthenticator(
    private val config: AdminAuthConfig,
    private val sessions: SessionService,
    private val preview: PreviewRuntimeConfig,
) {
    fun authenticate(authorization: String?, previewHeader: String?): AuthenticatedAdmin {
        if (preview.accepts(previewHeader)) return AuthenticatedAdmin(PreviewRuntimeConfig.ADMIN_EMAIL)
        if (!config.enabled) throw ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Admin login is not configured")
        val user = sessions.authenticate(authorization)
            ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "A session token is required")
        if (!user.isAdmin) throw ResponseStatusException(HttpStatus.FORBIDDEN, "Account is not an HKH administrator")
        return AuthenticatedAdmin(user.email)
    }
}
