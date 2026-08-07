package nl.vdzon.hkh.auth.api

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import nl.vdzon.hkh.auth.AdminAuthConfig
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.GoogleIdentity
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

class AdminControllerTest {
    private val config = AdminAuthConfig("client-id", "admin@example.com")
    private val production = PreviewRuntimeConfig(false, "", "jdbc:postgresql://production:5432/hkh")

    @Test
    fun `allows a verified allowlisted administrator`() {
        val controller = controller(GoogleIdTokenVerifier { GoogleIdentity("admin@example.com", true) })

        assertEquals(AdminIdentityResponse("admin@example.com"), controller.me("Bearer valid-token", null))
    }

    @Test
    fun `rejects a non allowlisted administrator`() {
        val controller = controller(GoogleIdTokenVerifier { GoogleIdentity("other@example.com", true) })

        val exception = assertFailsWith<ResponseStatusException> { controller.me("Bearer valid-token", null) }
        assertEquals(HttpStatus.FORBIDDEN, exception.statusCode)
    }

    @Test
    fun `rejects an unverified e-mail address`() {
        val controller = controller(GoogleIdTokenVerifier { GoogleIdentity("admin@example.com", false) })

        val exception = assertFailsWith<ResponseStatusException> { controller.me("Bearer valid-token", null) }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.statusCode)
    }

    @Test
    fun `allows the preview administrator only in guarded preview mode`() {
        val preview = PreviewRuntimeConfig(true, PreviewRuntimeConfig.REQUIRED_MARKER, "jdbc:postgresql://database:5432/hkh")
        val controller = AdminController(
            AdminAuthenticator(AdminAuthConfig("", ""), GoogleIdTokenVerifier { error("not used") }, preview),
        )

        assertEquals(
            AdminIdentityResponse(PreviewRuntimeConfig.ADMIN_EMAIL),
            controller.me(null, PreviewRuntimeConfig.ADMIN_HEADER_VALUE),
        )
    }

    private fun controller(verifier: GoogleIdTokenVerifier) =
        AdminController(AdminAuthenticator(config, verifier, production))
}
