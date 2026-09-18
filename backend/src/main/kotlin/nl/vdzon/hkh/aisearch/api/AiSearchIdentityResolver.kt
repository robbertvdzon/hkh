package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import java.util.UUID
import nl.vdzon.hkh.aisearch.AiSearchIdentity
import nl.vdzon.hkh.aisearch.AiSearchRepository
import nl.vdzon.hkh.auth.SessionService
import org.springframework.stereotype.Component

@Component
class AiSearchIdentityResolver(private val sessions: SessionService, private val repository: AiSearchRepository) {
    fun resolve(cookie: String?, request: HttpServletRequest, response: HttpServletResponse): AiSearchIdentity {
        response.setHeader("Cache-Control", "no-store")
        val authorization = request.getHeader("Authorization")
        if (authorization == null) return AiSearchIdentity(visitorId = anonymousVisitorId(cookie, request, response))
        // Een ongeldig token mag nooit terugvallen op toegang via de browsercookie.
        val user = sessions.requireUser(authorization)
        val identity = AiSearchIdentity(userId = user.id, userEmail = user.email)
        cookie?.let { runCatching { UUID.fromString(it).toString() }.getOrNull() }
            ?.let { repository.claimAnonymousSessions(it, identity) }
        return identity
    }
}
