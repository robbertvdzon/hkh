package nl.vdzon.hkh.auth

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component

@Component
class AdminAuthConfig(
    @param:Value("\${hkh.auth.google-client-id:}") val googleClientId: String,
    @Value("\${hkh.auth.admin-allowed-emails:}") rawAllowedEmails: String,
) {
    val allowedEmails: Set<String> = parseAllowedEmails(rawAllowedEmails)
    val enabled: Boolean = googleClientId.isNotBlank() && allowedEmails.isNotEmpty()

    init {
        require(googleClientId.isBlank() == allowedEmails.isEmpty()) {
            "HKH_GOOGLE_CLIENT_ID and HKH_ADMIN_ALLOWED_EMAILS must either both be set or both be empty"
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
