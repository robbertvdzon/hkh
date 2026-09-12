package nl.vdzon.hkh.auth.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import nl.vdzon.hkh.auth.AdminAuthConfig
import nl.vdzon.hkh.auth.AuthenticatedUser
import nl.vdzon.hkh.auth.SessionService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

data class GoogleLoginRequest(@field:NotBlank val idToken: String)

data class UserResponse(val email: String, val displayName: String?, val roles: List<String>)

data class LoginResponse(val token: String, val user: UserResponse)

data class AuthConfigResponse(val googleLoginEnabled: Boolean)

@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val sessions: SessionService,
    private val config: AdminAuthConfig,
) {
    @GetMapping("/config")
    fun config(): AuthConfigResponse = AuthConfigResponse(config.loginEnabled)

    @PostMapping("/google")
    fun google(@Valid @RequestBody request: GoogleLoginRequest): LoginResponse {
        val result = sessions.loginWithGoogle(request.idToken)
        return LoginResponse(result.token, result.user.toResponse())
    }

    @GetMapping("/me")
    fun me(@RequestHeader("Authorization", required = false) authorization: String?): UserResponse =
        sessions.requireUser(authorization).toResponse()

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun logout(@RequestHeader("Authorization", required = false) authorization: String?) =
        sessions.logout(authorization)

    @PostMapping("/logout-all")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun logoutAll(@RequestHeader("Authorization", required = false) authorization: String?) =
        sessions.logoutAll(authorization)

    @DeleteMapping("/account")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteAccount(@RequestHeader("Authorization", required = false) authorization: String?) =
        sessions.deleteAccount(authorization)
}

private fun AuthenticatedUser.toResponse() =
    UserResponse(email, displayName, if (isAdmin) listOf("ADMIN") else emptyList())
