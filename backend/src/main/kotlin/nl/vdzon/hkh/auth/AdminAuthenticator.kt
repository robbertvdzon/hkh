package nl.vdzon.hkh.auth

import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.server.ResponseStatusException

data class AuthenticatedAdmin(val email: String)

@Component
class AdminAuthenticator(
    private val config: AdminAuthConfig,
    private val tokenVerifier: GoogleIdTokenVerifier,
    private val preview: PreviewRuntimeConfig,
) {
    fun authenticate(authorization: String?, previewHeader: String?): AuthenticatedAdmin {
        if (preview.accepts(previewHeader)) return AuthenticatedAdmin(PreviewRuntimeConfig.ADMIN_EMAIL)
        if (!config.enabled) throw ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Admin login is not configured")
        val idToken = authorization
            ?.takeIf { it.startsWith(BEARER_PREFIX) }
            ?.removePrefix(BEARER_PREFIX)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "A Google ID token is required")
        val identity = tokenVerifier.verify(idToken)
        if (!identity.emailVerified) throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Google e-mail is not verified")
        if (!config.isAllowed(identity.email)) throw ResponseStatusException(HttpStatus.FORBIDDEN, "Account is not an HKH administrator")
        return AuthenticatedAdmin(identity.email)
    }

    companion object {
        private const val BEARER_PREFIX = "Bearer "
    }
}
