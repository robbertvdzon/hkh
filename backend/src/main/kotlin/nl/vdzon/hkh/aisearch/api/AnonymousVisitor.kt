package nl.vdzon.hkh.aisearch.api

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import java.time.Duration
import java.util.UUID
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie

/** De anonieme sleutel voor alle publieke AI-zoekroutes, inclusief de PDF-export. */
const val VISITOR_COOKIE = "hkh_ai_visitor"

/**
 * Geeft de bezoeker uit de cookie terug, of maakt er een nieuwe aan en zet die op de response.
 * Zonder geldige cookie hoort een bestaande zoekopdracht niet bij deze bezoeker.
 */
internal fun anonymousVisitorId(
    cookieValue: String?,
    request: HttpServletRequest,
    response: HttpServletResponse,
): String {
    val existing = runCatching { UUID.fromString(cookieValue) }.getOrNull()
    val id = existing ?: UUID.randomUUID()
    if (existing == null) {
        val localDevelopment = request.serverName.equals("localhost", ignoreCase = true) ||
            request.serverName == "127.0.0.1"
        val secure = !localDevelopment || request.isSecure ||
            request.getHeader("X-Forwarded-Proto").equals("https", ignoreCase = true)
        response.addHeader(
            HttpHeaders.SET_COOKIE,
            ResponseCookie.from(VISITOR_COOKIE, id.toString())
                .httpOnly(true)
                .secure(secure)
                .sameSite("Lax")
                .path("/")
                .maxAge(Duration.ofDays(365))
                .build()
                .toString(),
        )
    }
    return id.toString()
}
