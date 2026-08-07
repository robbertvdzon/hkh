package nl.vdzon.hkh.auth.api

import nl.vdzon.hkh.auth.AdminAuthConfig
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.server.ResponseStatusException

data class AdminIdentityResponse(val email: String, val role: String = "admin")

@RestController
@RequestMapping("/api/admin")
class AdminController(
    private val config: AdminAuthConfig,
    private val tokenVerifier: GoogleIdTokenVerifier,
    private val preview: PreviewRuntimeConfig,
) {
    @GetMapping("/me")
    fun me(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): AdminIdentityResponse {
        if (preview.accepts(previewHeader)) return AdminIdentityResponse(PreviewRuntimeConfig.ADMIN_EMAIL)
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
        return AdminIdentityResponse(identity.email)
    }

    companion object {
        private const val BEARER_PREFIX = "Bearer "
    }
}
