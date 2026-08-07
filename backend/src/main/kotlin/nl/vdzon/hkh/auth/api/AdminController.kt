package nl.vdzon.hkh.auth.api

import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class AdminIdentityResponse(val email: String, val role: String = "admin")

@RestController
@RequestMapping("/api/admin")
class AdminController(
    private val authenticator: AdminAuthenticator,
) {
    @GetMapping("/me")
    fun me(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): AdminIdentityResponse {
        val admin = authenticator.authenticate(authorization, previewHeader)
        return AdminIdentityResponse(admin.email)
    }
}
