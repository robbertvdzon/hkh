package nl.vdzon.hkh.previewdata.api

import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.previewdata.PreviewDataSeeder
import nl.vdzon.hkh.previewdata.PreviewSeedResult
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/admin/preview/test-data")
@ConditionalOnProperty(prefix = "hkh.preview", name = ["enabled"], havingValue = "true")
class PreviewDataController(
    private val seeder: PreviewDataSeeder,
    private val authenticator: AdminAuthenticator,
) {
    @PostMapping("/ensure")
    fun ensure(
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): PreviewSeedResult {
        authenticator.authenticate(authorization, previewHeader)
        return seeder.ensure()
    }
}
