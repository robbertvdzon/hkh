package nl.vdzon.hkh.auth

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

/**
 * Google-login voor de publieke app staat aan zodra er een client-id is. De allowlist bepaalt
 * alleen wie daarnaast beheerder is; een allowlist zonder client-id is een configuratiefout.
 */
@Component
class AdminAuthConfig(
    @param:Value("\${hkh.auth.google-client-id:}") val googleClientId: String,
    @Value("\${hkh.auth.admin-allowed-emails:}") rawAllowedEmails: String,
) {
    val allowedEmails: Set<String> = parseAllowedEmails(rawAllowedEmails)

    /** Google-login is beschikbaar (publieke app én beheer). */
    val loginEnabled: Boolean = googleClientId.isNotBlank()

    /** Er zijn beheerders geconfigureerd; alleen dan werkt het beheerscherm. */
    val enabled: Boolean = loginEnabled && allowedEmails.isNotEmpty()

    init {
        require(allowedEmails.isEmpty() || loginEnabled) {
            "HKH_ADMIN_ALLOWED_EMAILS requires HKH_GOOGLE_CLIENT_ID"
        }
    }

    fun isAllowed(email: String): Boolean = email.trim().lowercase() in allowedEmails

    companion object {
        fun parseAllowedEmails(raw: String): Set<String> = raw
            .split(',')
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .onEach { require('@' in it) { "HKH_ADMIN_ALLOWED_EMAILS contains an invalid e-mail address" } }
            .toCollection(linkedSetOf())
    }
}
