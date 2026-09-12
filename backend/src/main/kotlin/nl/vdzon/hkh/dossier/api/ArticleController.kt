package nl.vdzon.hkh.dossier.api

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import nl.vdzon.hkh.auth.SessionService
import nl.vdzon.hkh.dossier.ArticleDetailView
import nl.vdzon.hkh.dossier.ArticleService
import nl.vdzon.hkh.dossier.ArticleSummaryView
import nl.vdzon.hkh.dossier.DiffView
import nl.vdzon.hkh.dossier.VersionSummaryView
import nl.vdzon.hkh.dossier.VersionView
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

data class CreateArticleRequest(
    @field:NotBlank @field:Size(max = 200) val title: String,
    @field:Size(max = 200_000) val contentMarkdown: String = "",
)

data class GenerateArticleRequest(
    @field:NotBlank @field:Size(max = 200) val title: String,
    @field:NotBlank @field:Size(min = 3, max = 4000) val instruction: String,
)

data class SaveArticleRequest(
    @field:NotBlank @field:Size(max = 200) val title: String,
    @field:Size(max = 200_000) val contentMarkdown: String,
    val basedOnVersionId: String? = null,
)

data class ProposalRequest(
    @field:NotBlank @field:Size(min = 3, max = 4000) val instruction: String,
    val basedOnVersionId: String? = null,
)

@RestController
class ArticleController(
    private val sessions: SessionService,
    private val service: ArticleService,
) {
    @GetMapping("/api/dossiers/{dossierId}/articles")
    fun list(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
    ): List<ArticleSummaryView> = service.list(dossierId, sessions.requireUser(authorization))

    @PostMapping("/api/dossiers/{dossierId}/articles")
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: CreateArticleRequest,
    ): ArticleDetailView = service.create(dossierId, sessions.requireUser(authorization), request.title, request.contentMarkdown)

    @PostMapping("/api/dossiers/{dossierId}/articles/generate")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun generate(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable dossierId: String,
        @Valid @RequestBody request: GenerateArticleRequest,
    ): ArticleDetailView = service.generate(dossierId, sessions.requireUser(authorization), request.title, request.instruction)

    @GetMapping("/api/articles/{articleId}")
    fun get(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
    ): ArticleDetailView = service.get(articleId, sessions.requireUser(authorization))

    @PutMapping("/api/articles/{articleId}")
    fun save(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @Valid @RequestBody request: SaveArticleRequest,
    ): ArticleDetailView = service.save(
        articleId, sessions.requireUser(authorization), request.title, request.contentMarkdown, request.basedOnVersionId,
    )

    @DeleteMapping("/api/articles/{articleId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
    ) = service.delete(articleId, sessions.requireUser(authorization))

    @GetMapping("/api/articles/{articleId}/versions")
    fun versions(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
    ): List<VersionSummaryView> = service.versions(articleId, sessions.requireUser(authorization))

    @GetMapping("/api/articles/{articleId}/versions/{number}")
    fun version(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @PathVariable number: Int,
    ): VersionView = service.version(articleId, sessions.requireUser(authorization), number)

    @GetMapping("/api/articles/{articleId}/versions/{number}/diff")
    fun diff(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @PathVariable number: Int,
        @RequestParam("against") against: Int,
    ): DiffView = service.diff(articleId, sessions.requireUser(authorization), against, number)

    @PostMapping("/api/articles/{articleId}/versions/{number}/restore")
    fun restore(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @PathVariable number: Int,
    ): ArticleDetailView = service.restore(articleId, sessions.requireUser(authorization), number)

    @PostMapping("/api/articles/{articleId}/proposals")
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun propose(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @Valid @RequestBody request: ProposalRequest,
    ): ArticleDetailView = service.propose(articleId, sessions.requireUser(authorization), request.instruction, request.basedOnVersionId)

    @PostMapping("/api/articles/{articleId}/proposals/{versionId}/accept")
    fun accept(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @PathVariable versionId: String,
    ): ArticleDetailView = service.accept(articleId, sessions.requireUser(authorization), versionId)

    @PostMapping("/api/articles/{articleId}/proposals/{versionId}/reject")
    fun reject(
        @RequestHeader(AUTH, required = false) authorization: String?,
        @PathVariable articleId: String,
        @PathVariable versionId: String,
    ): ArticleDetailView = service.reject(articleId, sessions.requireUser(authorization), versionId)

    private companion object {
        const val AUTH = "Authorization"
    }
}
