package nl.vdzon.hkh.auth

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

class SessionServiceTest {
    private val store = InMemoryUserAccountStore()
    private val config = AdminAuthConfig("client-id", "admin@example.com")

    private fun service(identity: GoogleIdentity = GoogleIdentity("visitor@example.com", true, "Visitor")) =
        SessionService(config, GoogleIdTokenVerifier { identity }, store, 365)

    @Test
    fun `exchanges a Google token for a session and recognises administrators`() {
        val service = service(GoogleIdentity("Admin@Example.com", true, "Admin"))

        val login = service.loginWithGoogle("google-token")

        assertTrue(login.user.isAdmin)
        assertEquals("admin@example.com", login.user.email)
        val user = service.authenticate("Bearer ${login.token}")
        assertEquals("admin@example.com", user?.email)
        assertTrue(user!!.isAdmin)
    }

    @Test
    fun `ordinary visitors get a session without the admin role`() {
        val login = service().loginWithGoogle("google-token")
        assertFalse(login.user.isAdmin)
        assertEquals("Visitor", login.user.displayName)
    }

    @Test
    fun `missing header is anonymous but a bad token is rejected`() {
        val service = service()
        assertNull(service.authenticate(null))
        val error = assertFailsWith<ResponseStatusException> { service.authenticate("Bearer unknown") }
        assertEquals(HttpStatus.UNAUTHORIZED, error.statusCode)
    }

    @Test
    fun `logout revokes the session and expired sessions are refused`() {
        val service = service()
        val login = service.loginWithGoogle("google-token")
        service.logout("Bearer ${login.token}")
        assertFailsWith<ResponseStatusException> { service.authenticate("Bearer ${login.token}") }

        val second = service.loginWithGoogle("google-token")
        store.expireSession(SessionService.hash(second.token))
        assertFailsWith<ResponseStatusException> { service.authenticate("Bearer ${second.token}") }
    }

    @Test
    fun `unverified e-mail and disabled login are refused`() {
        val unverified = service(GoogleIdentity("visitor@example.com", false))
        assertEquals(
            HttpStatus.UNAUTHORIZED,
            assertFailsWith<ResponseStatusException> { unverified.loginWithGoogle("token") }.statusCode,
        )
        val disabled = SessionService(AdminAuthConfig("", ""), GoogleIdTokenVerifier { error("unused") }, store, 365)
        assertEquals(
            HttpStatus.SERVICE_UNAVAILABLE,
            assertFailsWith<ResponseStatusException> { disabled.loginWithGoogle("token") }.statusCode,
        )
    }
}
