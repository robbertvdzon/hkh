package nl.vdzon.hkh.news.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import nl.vdzon.hkh.auth.AdminAuthenticator
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.news.LatestNews
import nl.vdzon.hkh.news.LatestNewsService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

data class LatestNewsResponse(
    val id: Long,
    val title: String,
    val message: String,
    val publishedAt: Instant,
    val createdAt: Instant,
)

data class CreateLatestNewsRequest(
    @field:NotBlank @field:Size(max = 160) val title: String,
    @field:NotBlank @field:Size(max = 10_000) val message: String,
)

@RestController
@RequestMapping("/api/news")
class LatestNewsController(private val service: LatestNewsService) {
    @GetMapping
    fun findAll(): List<LatestNewsResponse> = service.findAll().map(LatestNews::toResponse)
}

@RestController
@RequestMapping("/api/admin/news")
class AdminLatestNewsController(
    private val service: LatestNewsService,
    private val authenticator: AdminAuthenticator,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @Valid @RequestBody request: CreateLatestNewsRequest,
        @RequestHeader("Authorization", required = false) authorization: String?,
        @RequestHeader(PreviewRuntimeConfig.ADMIN_HEADER, required = false) previewHeader: String?,
    ): LatestNewsResponse {
        val admin = authenticator.authenticate(authorization, previewHeader)
        return service.create(request.title, request.message, admin.email).toResponse()
    }
}

private fun LatestNews.toResponse() = LatestNewsResponse(id, title, message, publishedAt, createdAt)
