package nl.vdzon.hkh.auth

import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Duration
import java.time.Instant
import java.util.Base64
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

data class AuthenticatedUser(
    val id: String,
    val email: String,
    val displayName: String?,
    val isAdmin: Boolean,
)

data class LoginResult(val token: String, val user: AuthenticatedUser)

/**
 * Ruilt een Google ID-token één keer in voor een eigen sessietoken. Het Google-token is maar een
 * uur geldig; de eigen sessie een jaar en schuift bij gebruik op. Alleen de hash van het
 * sessietoken staat in de database.
 */
@Service
class SessionService(
    private val config: AdminAuthConfig,
    private val tokenVerifier: GoogleIdTokenVerifier,
    private val store: UserAccountStore,
    @param:Value("\${hkh.auth.session-days:365}") private val sessionDays: Long,
) {
    private val logger = LoggerFactory.getLogger(javaClass)
    private val random = SecureRandom()

    fun loginWithGoogle(idToken: String): LoginResult {
        if (!config.loginEnabled) throw ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Google-login is niet geconfigureerd")
        val identity = try {
            tokenVerifier.verify(idToken)
        } catch (ex: ResponseStatusException) {
            logger.warn("Google-login geweigerd: {}", ex.reason)
            throw ex
        }
        if (!identity.emailVerified) {
            logger.warn("Google-login geweigerd voor {}: e-mailadres niet geverifieerd", identity.email)
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Google-e-mailadres is niet geverifieerd")
        }
        val user = store.findOrCreateUser(identity.email, identity.displayName)
        val token = newToken()
        store.createSession(user.id, hash(token), Instant.now().plus(sessionDuration()))
        return LoginResult(token, user.toAuthenticated())
    }

    /** Null zonder Authorization-header; 401 bij een ongeldige, verlopen of ingetrokken sessie. */
    fun authenticate(authorization: String?): AuthenticatedUser? {
        val token = bearer(authorization) ?: return null
        val session = store.findSession(hash(token)) ?: throw unauthorized()
        val now = Instant.now()
        if (session.revokedAt != null || session.expiresAt.isBefore(now)) throw unauthorized()
        if (Duration.between(session.lastUsedAt, now) > TOUCH_INTERVAL) {
            store.touchSession(session.id, now.plus(sessionDuration()))
        }
        return session.user.toAuthenticated()
    }

    fun requireUser(authorization: String?): AuthenticatedUser =
        authenticate(authorization) ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Inloggen is vereist")

    fun logout(authorization: String?) {
        bearer(authorization)?.let { store.revokeSession(hash(it)) }
    }

    fun logoutAll(authorization: String?) {
        store.revokeAllSessions(requireUser(authorization).id)
    }

    fun deleteAccount(authorization: String?) {
        store.deleteUser(requireUser(authorization).id)
    }

    private fun UserAccount.toAuthenticated() = AuthenticatedUser(id, email, displayName, config.isAllowed(email))

    private fun sessionDuration(): Duration = Duration.ofDays(sessionDays.coerceIn(1, 3650))

    private fun newToken(): String = ByteArray(32).also(random::nextBytes).let(Base64.getUrlEncoder().withoutPadding()::encodeToString)

    private fun unauthorized() = ResponseStatusException(HttpStatus.UNAUTHORIZED, "De sessie is verlopen. Log opnieuw in.")

    companion object {
        private val TOUCH_INTERVAL: Duration = Duration.ofHours(1)

        fun bearer(authorization: String?): String? = authorization
            ?.takeIf { it.startsWith("Bearer ") }
            ?.removePrefix("Bearer ")
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

        fun hash(token: String): String = MessageDigest.getInstance("SHA-256")
            .digest(token.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
