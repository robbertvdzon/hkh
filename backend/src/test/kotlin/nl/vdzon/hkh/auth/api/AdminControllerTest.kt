package nl.vdzon.hkh.auth.api

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import nl.vdzon.hkh.auth.AdminAuthConfig
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.GoogleIdentity
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.InMemoryUserAccountStore
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.auth.SessionService
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

class AdminControllerTest {
    private val config = AdminAuthConfig("client-id", "admin@example.com")
    private val production = PreviewRuntimeConfig(false, "", "jdbc:postgresql://production:5432/hkh", "")

    @Test
    fun `allows a session of an allowlisted administrator`() {
        val sessions = sessions(GoogleIdentity("admin@example.com", true))
        val token = sessions.loginWithGoogle("google-token").token

        assertEquals(AdminIdentityResponse("admin@example.com"), controller(sessions).me("Bearer $token", null))
    }

    @Test
    fun `rejects a session of a non allowlisted user`() {
        val sessions = sessions(GoogleIdentity("other@example.com", true))
        val token = sessions.loginWithGoogle("google-token").token

        val exception = assertFailsWith<ResponseStatusException> { controller(sessions).me("Bearer $token", null) }
        assertEquals(HttpStatus.FORBIDDEN, exception.statusCode)
    }

    @Test
    fun `rejects a raw Google token or missing session`() {
        val sessions = sessions(GoogleIdentity("admin@example.com", true))

        val exception = assertFailsWith<ResponseStatusException> { controller(sessions).me("Bearer raw-google-token", null) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.statusCode)
        val missing = assertFailsWith<ResponseStatusException> { controller(sessions).me(null, null) }
        assertEquals(HttpStatus.UNAUTHORIZED, missing.statusCode)
    }

    @Test
    fun `allows the preview administrator only in guarded preview mode`() {
        val preview = PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://database:5432/hkh", "42")
        val unconfigured = AdminAuthConfig("", "")
        val controller = AdminController(
            AdminAuthenticator(
                unconfigured,
                SessionService(unconfigured, GoogleIdTokenVerifier { error("not used") }, InMemoryUserAccountStore(), 365),
                preview,
            ),
        )

        assertEquals(
            AdminIdentityResponse(PreviewRuntimeConfig.ADMIN_EMAIL),
            controller.me(null, PreviewRuntimeConfig.ADMIN_HEADER_VALUE),
        )
    }

    private fun sessions(identity: GoogleIdentity) =
        SessionService(config, GoogleIdTokenVerifier { identity }, InMemoryUserAccountStore(), 365)

    private fun controller(sessions: SessionService) =
        AdminController(AdminAuthenticator(config, sessions, production))
}
