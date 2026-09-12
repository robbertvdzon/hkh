package nl.vdzon.hkh.dossier

import nl.vdzon.hkh.auth.AuthenticatedUser
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

@Service
class ArticleService(
    private val repository: DossierRepository,
    private val dossiers: DossierService,
    private val renderer: MarkdownRenderer,
    private val jobs: DossierAiJobs,
) {
    fun list(dossierId: String, user: AuthenticatedUser): List<ArticleSummaryView> {
        dossiers.access(dossierId, user)
        return dossiers.articleSummaries(dossierId)
    }

    fun get(articleId: String, user: AuthenticatedUser): ArticleDetailView {
        val (article, access) = load(articleId, user)
        return article.toDetail(access)
    }

    fun create(dossierId: String, user: AuthenticatedUser, title: String, contentMarkdown: String): ArticleDetailView {
        val access = dossiers.requireRole(dossierId, user, DossierRole::canEdit, "Alleen bewerkers mogen artikelen maken")
        val cleanTitle = validateTitle(title)
        val article = repository.createArticle(dossierId, cleanTitle, user.email)
        val version = repository.createVersion(
            articleId = article.id,
            title = cleanTitle,
            contentMarkdown = validateContent(contentMarkdown),
            authorKind = AuthorKind.USER,
            authorEmail = user.email,
            aiInstruction = null,
            changeSummary = "Artikel aangemaakt",
            state = VersionState.ACCEPTED,
            basedOnVersionId = null,
            jobStatus = null,
        )
        repository.setCurrentVersion(article.id, version.id, cleanTitle)
        repository.touch(dossierId)
        return requireNotNull(repository.findArticle(article.id)).toDetail(access)
    }

    fun generate(dossierId: String, user: AuthenticatedUser, title: String, instruction: String): ArticleDetailView {
        val access = dossiers.requireRole(dossierId, user, DossierRole::canEdit, "Alleen bewerkers mogen artikelen laten schrijven")
        dossiers.ensureAiAvailable()
        dossiers.ensureUserJobCapacity(user)
        val cleanTitle = validateTitle(title)
        val cleanInstruction = validateInstruction(instruction)
        val article = repository.createArticle(dossierId, cleanTitle, user.email)
        val empty = repository.createVersion(
            articleId = article.id,
            title = cleanTitle,
            contentMarkdown = "",
            authorKind = AuthorKind.USER,
            authorEmail = user.email,
            aiInstruction = null,
            changeSummary = "Artikel aangemaakt",
            state = VersionState.ACCEPTED,
            basedOnVersionId = null,
            jobStatus = null,
        )
        repository.setCurrentVersion(article.id, empty.id, cleanTitle)
        val proposal = repository.createVersion(
            articleId = article.id,
            title = cleanTitle,
            contentMarkdown = "",
            authorKind = AuthorKind.AI,
            authorEmail = user.email,
            aiInstruction = cleanInstruction,
            changeSummary = null,
            state = VersionState.PROPOSED,
            basedOnVersionId = empty.id,
            jobStatus = JobStatus.SUBMITTING,
            progressMessage = "De schrijfopdracht wordt voorbereid",
        )
        repository.touch(dossierId)
        jobs.scheduleArticleJob(proposal.id)
        return requireNotNull(repository.findArticle(article.id)).toDetail(access)
    }

    fun save(articleId: String, user: AuthenticatedUser, title: String, contentMarkdown: String, basedOnVersionId: String?): ArticleDetailView {
        val (article, access) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen artikelen bewerken")
        val current = requireCurrent(article)
        if (basedOnVersionId != null && basedOnVersionId != current.id) throw conflict(current)
        val cleanTitle = validateTitle(title)
        val cleanContent = validateContent(contentMarkdown)
        if (cleanTitle == current.title && cleanContent == current.contentMarkdown) return article.toDetail(access)
        val version = repository.createVersion(
            articleId = article.id,
            title = cleanTitle,
            contentMarkdown = cleanContent,
            authorKind = AuthorKind.USER,
            authorEmail = user.email,
            aiInstruction = null,
            changeSummary = "Handmatig bewerkt",
            state = VersionState.ACCEPTED,
            basedOnVersionId = current.id,
            jobStatus = null,
        )
        repository.setCurrentVersion(article.id, version.id, cleanTitle)
        repository.touch(article.dossierId)
        return requireNotNull(repository.findArticle(article.id)).toDetail(access)
    }

    fun propose(articleId: String, user: AuthenticatedUser, instruction: String, basedOnVersionId: String?): ArticleDetailView {
        val (article, access) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen AI-voorstellen vragen")
        dossiers.ensureAiAvailable()
        val current = requireCurrent(article)
        if (basedOnVersionId != null && basedOnVersionId != current.id) throw conflict(current)
        if (repository.openProposal(article.id) != null) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Er staat al een voorstel open. Beoordeel dat eerst.")
        }
        dossiers.ensureUserJobCapacity(user)
        val proposal = repository.createVersion(
            articleId = article.id,
            title = current.title,
            contentMarkdown = "",
            authorKind = AuthorKind.AI,
            authorEmail = user.email,
            aiInstruction = validateInstruction(instruction),
            changeSummary = null,
            state = VersionState.PROPOSED,
            basedOnVersionId = current.id,
            jobStatus = JobStatus.SUBMITTING,
            progressMessage = "De schrijfopdracht wordt voorbereid",
        )
        jobs.scheduleArticleJob(proposal.id)
        return article.toDetail(access)
    }

    fun accept(articleId: String, user: AuthenticatedUser, versionId: String): ArticleDetailView {
        val (article, access) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen voorstellen beoordelen")
        val proposal = repository.findVersion(versionId)?.takeIf { it.articleId == article.id && it.state == VersionState.PROPOSED }
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Voorstel niet gevonden")
        if (proposal.jobStatus != JobStatus.SUCCEEDED) throw ResponseStatusException(HttpStatus.CONFLICT, "Het voorstel is nog niet klaar")
        repository.decideVersion(proposal.id, VersionState.ACCEPTED, user.email)
        repository.setCurrentVersion(article.id, proposal.id, proposal.title)
        repository.touch(article.dossierId)
        return requireNotNull(repository.findArticle(article.id)).toDetail(access)
    }

    fun reject(articleId: String, user: AuthenticatedUser, versionId: String): ArticleDetailView {
        val (article, access) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen voorstellen beoordelen")
        val proposal = repository.findVersion(versionId)?.takeIf { it.articleId == article.id && it.state == VersionState.PROPOSED }
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Voorstel niet gevonden")
        if (proposal.isActiveJob) {
            jobs.cancelArticleJob(proposal)
        } else {
            repository.decideVersion(proposal.id, VersionState.REJECTED, user.email)
        }
        return article.toDetail(access)
    }

    fun restore(articleId: String, user: AuthenticatedUser, versionNumber: Int): ArticleDetailView {
        val (article, access) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen een versie terugzetten")
        val target = repository.findVersion(article.id, versionNumber)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Versie niet gevonden")
        if (target.isActiveJob) throw ResponseStatusException(HttpStatus.CONFLICT, "Deze versie is nog niet klaar")
        val current = requireCurrent(article)
        val version = repository.createVersion(
            articleId = article.id,
            title = target.title,
            contentMarkdown = target.contentMarkdown,
            authorKind = AuthorKind.USER,
            authorEmail = user.email,
            aiInstruction = null,
            changeSummary = "Teruggezet naar versie ${target.versionNumber}",
            state = VersionState.ACCEPTED,
            basedOnVersionId = current.id,
            jobStatus = null,
        )
        repository.setCurrentVersion(article.id, version.id, target.title)
        repository.touch(article.dossierId)
        return requireNotNull(repository.findArticle(article.id)).toDetail(access)
    }

    fun versions(articleId: String, user: AuthenticatedUser): List<VersionSummaryView> {
        val (article, _) = load(articleId, user)
        val versions = repository.versions(article.id)
        val numbers = versions.associate { it.id to it.versionNumber }
        return versions.map { version ->
            VersionSummaryView(
                id = version.id,
                versionNumber = version.versionNumber,
                title = version.title,
                authorKind = version.authorKind,
                authorEmail = version.authorEmail,
                aiInstruction = version.aiInstruction,
                changeSummary = version.changeSummary,
                state = version.state,
                jobStatus = version.jobStatus,
                errorMessage = version.errorMessage,
                basedOnVersionNumber = version.basedOnVersionId?.let(numbers::get),
                isCurrent = version.id == article.currentVersionId,
                createdAt = version.createdAt,
                decidedAt = version.decidedAt,
                decidedByEmail = version.decidedByEmail,
            )
        }
    }

    fun version(articleId: String, user: AuthenticatedUser, versionNumber: Int): VersionView {
        val (article, _) = load(articleId, user)
        val version = repository.findVersion(article.id, versionNumber)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Versie niet gevonden")
        return version.toView()
    }

    fun diff(articleId: String, user: AuthenticatedUser, fromNumber: Int, toNumber: Int): DiffView {
        val (article, _) = load(articleId, user)
        val from = repository.findVersion(article.id, fromNumber) ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Versie niet gevonden")
        val to = repository.findVersion(article.id, toNumber) ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Versie niet gevonden")
        return DiffView(from.versionNumber, to.versionNumber, ArticleDiff.lines(from.contentMarkdown, to.contentMarkdown))
    }

    fun delete(articleId: String, user: AuthenticatedUser) {
        val (article, _) = load(articleId, user, DossierRole::canEdit, "Alleen bewerkers mogen artikelen verwijderen")
        repository.openProposal(article.id)?.takeIf { it.isActiveJob }?.let(jobs::cancelArticleJob)
        repository.deleteArticle(article.id)
        repository.touch(article.dossierId)
    }

    // ---- Intern ----

    private fun load(
        articleId: String,
        user: AuthenticatedUser,
        check: (DossierRole) -> Boolean = { true },
        message: String = "",
    ): Pair<Article, DossierAccess> {
        val article = repository.findArticle(articleId) ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Artikel niet gevonden")
        val access = runCatching { dossiers.access(article.dossierId, user) }
            .getOrElse { throw ResponseStatusException(HttpStatus.NOT_FOUND, "Artikel niet gevonden") }
        if (!check(access.role)) throw ResponseStatusException(HttpStatus.FORBIDDEN, message)
        return article to access
    }

    private fun requireCurrent(article: Article): ArticleVersion =
        article.currentVersionId?.let(repository::findVersion) ?: error("Article ${article.id} has no current version")

    private fun conflict(current: ArticleVersion) = ResponseStatusException(
        HttpStatus.CONFLICT,
        "Iemand anders heeft ondertussen versie ${current.versionNumber} opgeslagen. Laad het artikel opnieuw.",
    )

    private fun Article.toDetail(access: DossierAccess): ArticleDetailView {
        val versions = repository.versions(id)
        val current = versions.firstOrNull { it.id == currentVersionId } ?: error("Article $id has no current version")
        val proposal = repository.openProposal(id)
        return ArticleDetailView(
            id = id,
            dossierId = dossierId,
            dossierTitle = access.dossier.title,
            title = title,
            role = access.role,
            current = current.toView(versions),
            proposal = proposal?.toView(versions),
            versionCount = versions.size,
            createdAt = createdAt,
            updatedAt = updatedAt,
        )
    }

    private fun ArticleVersion.toView(all: List<ArticleVersion>? = null): VersionView {
        val rendered = renderer.render(contentMarkdown)
        val numbers = (all ?: repository.versions(articleId)).associate { it.id to it.versionNumber }
        return VersionView(
            id = id,
            versionNumber = versionNumber,
            title = title,
            contentMarkdown = contentMarkdown,
            contentHtml = rendered.html,
            sources = rendered.sources.map(RenderedSource::toView),
            unknownSources = rendered.unknownSources,
            authorKind = authorKind,
            authorEmail = authorEmail,
            aiInstruction = aiInstruction,
            changeSummary = changeSummary,
            state = state,
            jobStatus = jobStatus,
            progressMessage = progressMessage,
            errorMessage = errorMessage,
            basedOnVersionNumber = basedOnVersionId?.let(numbers::get),
            createdAt = createdAt,
            decidedAt = decidedAt,
            decidedByEmail = decidedByEmail,
        )
    }

    private fun validateTitle(title: String): String {
        val cleaned = title.trim()
        if (cleaned.isEmpty()) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Geef het artikel een titel")
        if (cleaned.length > 200) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De titel mag maximaal 200 tekens bevatten")
        return cleaned
    }

    private fun validateContent(content: String): String {
        if (content.length > MAX_CONTENT_LENGTH) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Het artikel is te lang")
        return content.replace("\r\n", "\n").trimEnd()
    }

    private fun validateInstruction(instruction: String): String {
        val cleaned = instruction.trim()
        if (cleaned.length < 3) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Beschrijf wat de AI moet doen")
        if (cleaned.length > 4000) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De opdracht mag maximaal 4000 tekens bevatten")
        return cleaned
    }

    companion object {
        const val MAX_CONTENT_LENGTH = 200_000
    }
}
