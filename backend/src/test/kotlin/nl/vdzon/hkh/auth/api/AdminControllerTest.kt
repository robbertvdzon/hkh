package nl.vdzon.hkh.auth.api

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import nl.vdzon.hkh.auth.AdminAuthConfig
import nl.vdzon.hkh.auth.GoogleIdentity
import nl.vdzon.hkh.auth.GoogleIdTokenVerifier
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

class AdminControllerTest {
    private val config = AdminAuthConfig("client-id", "admin@example.com")

    @Test
    fun `allows a verified allowlisted administrator`() {
        val controller = AdminController(config, GoogleIdTokenVerifier { GoogleIdentity("admin@example.com", true) })

        assertEquals(AdminIdentityResponse("admin@example.com"), controller.me("Bearer valid-token"))
    }

    @Test
    fun `rejects a non allowlisted administrator`() {
        val controller = AdminController(config, GoogleIdTokenVerifier { GoogleIdentity("other@example.com", true) })

        val exception = assertFailsWith<ResponseStatusException> { controller.me("Bearer valid-token") }
        assertEquals(HttpStatus.FORBIDDEN, exception.statusCode)
    }

    @Test
    fun `rejects an unverified e-mail address`() {
        val controller = AdminController(config, GoogleIdTokenVerifier { GoogleIdentity("admin@example.com", false) })

        val exception = assertFailsWith<ResponseStatusException> { controller.me("Bearer valid-token") }
        assertEquals(HttpStatus.UNAUTHORIZED, exception.statusCode)
    }
}
