package nl.vdzon.hkh.dossier

import nl.vdzon.hkh.aisearch.AiSearchOwner
import nl.vdzon.hkh.aisearch.AiSearchService
import nl.vdzon.hkh.aisearch.AiSearchSessionView
import nl.vdzon.hkh.aisearch.AiSearchSummaryView
import nl.vdzon.hkh.auth.AuthenticatedUser
import nl.vdzon.hkh.auth.UserAccountStore
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

data class DossierAccess(val dossier: Dossier, val role: DossierRole)

@Service
class DossierService(
    private val repository: DossierRepository,
    private val aiSearch: AiSearchService,
    private val users: UserAccountStore,
    private val renderer: MarkdownRenderer,
    private val jobs: DossierAiJobs,
) {
    // ---- Toegang ----

    /** 404 als het dossier niet bestaat of de gebruiker er geen toegang toe heeft. */
    fun access(dossierId: String, user: AuthenticatedUser): DossierAccess {
        val dossier = repository.find(dossierId) ?: throw notFound()
        val role = when {
            dossier.ownerUserId == user.id -> DossierRole.OWNER
            else -> repository.memberRole(dossierId, user.email) ?: throw notFound()
        }
        return DossierAccess(dossier, role)
    }

    fun requireRole(dossierId: String, user: AuthenticatedUser, check: (DossierRole) -> Boolean, message: String): DossierAccess {
        val access = access(dossierId, user)
        if (!check(access.role)) throw ResponseStatusException(HttpStatus.FORBIDDEN, message)
        return access
    }

    // ---- Dossiers ----

    fun list(user: AuthenticatedUser): List<DossierSummaryView> =
        repository.accessible(user.id, user.email).map { it.toSummary(roleOf(it, user)) }

    fun create(user: AuthenticatedUser, title: String, goal: String): DossierDetailView {
        val dossier = repository.create(user.id, validateTitle(title), validateGoal(goal))
        return detail(dossier.id, user)
    }

    fun detail(dossierId: String, user: AuthenticatedUser): DossierDetailView {
        val (dossier, role) = access(dossierId, user)
        val factSheet = renderer.render(dossier.factSheetMarkdown)
        return DossierDetailView(
            id = dossier.id,
            title = dossier.title,
            goal = dossier.goal,
            role = role,
            ownerEmail = dossier.ownerEmail,
            members = repository.members(dossier.id).map { MemberView(it.email, it.role) },
            factSheet = FactSheetView(
                markdown = dossier.factSheetMarkdown,
                html = factSheet.html,
                sources = factSheet.sources.map(RenderedSource::toView),
                status = dossier.factSheetStatus,
                dirty = dossier.factSheetDirty,
                updatedAt = dossier.factSheetUpdatedAt,
                error = dossier.factSheetError,
            ),
            questions = aiSearch.listInDossier(dossier.id),
            articles = articleSummaries(dossier.id),
            createdAt = dossier.createdAt,
            updatedAt = dossier.updatedAt,
        )
    }

    fun update(dossierId: String, user: AuthenticatedUser, title: String, goal: String): DossierDetailView {
        requireRole(dossierId, user, DossierRole::canEdit, "Alleen bewerkers mogen titel en doel wijzigen")
        repository.update(dossierId, validateTitle(title), validateGoal(goal))
        return detail(dossierId, user)
    }

    fun delete(dossierId: String, user: AuthenticatedUser) {
        requireRole(dossierId, user, DossierRole::canManage, "Alleen de eigenaar mag het dossier verwijderen")
        repository.delete(dossierId)
    }

    // ---- Leden ----

    fun setMember(dossierId: String, user: AuthenticatedUser, email: String, role: DossierRole): DossierDetailView {
        val (dossier, _) = requireRole(dossierId, user, DossierRole::canManage, "Alleen de eigenaar mag leden beheren")
        val normalized = normalizeEmail(email)
        if (normalized == dossier.ownerEmail) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De eigenaar is al lid van het dossier")
        if (role !in DossierRole.assignable) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Onbekende rol")
        repository.upsertMember(dossierId, normalized, role, user.id)
        repository.touch(dossierId)
        return detail(dossierId, user)
    }

    fun removeMember(dossierId: String, user: AuthenticatedUser, email: String) {
        val normalized = normalizeEmail(email)
        val (_, role) = access(dossierId, user)
        if (!role.canManage && normalized != user.email) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Alleen de eigenaar mag andere leden verwijderen")
        }
        if (!repository.removeMember(dossierId, normalized)) throw ResponseStatusException(HttpStatus.NOT_FOUND, "Lid niet gevonden")
        repository.touch(dossierId)
    }

    fun transferOwnership(dossierId: String, user: AuthenticatedUser, email: String): DossierDetailView {
        requireRole(dossierId, user, DossierRole::canManage, "Alleen de eigenaar mag het dossier overdragen")
        val normalized = normalizeEmail(email)
        val newOwner = users.findUserByEmail(normalized)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Dit e-mailadres heeft nog nooit ingelogd")
        if (repository.memberRole(dossierId, normalized) == null) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Alleen een lid kan eigenaar worden")
        }
        repository.transferOwnership(dossierId, newOwner.id)
        repository.removeMember(dossierId, normalized)
        repository.upsertMember(dossierId, user.email, DossierRole.EDITOR, newOwner.id)
        return detail(dossierId, user)
    }

    // ---- Feitenlijst ----

    fun updateFactSheet(dossierId: String, user: AuthenticatedUser, markdown: String): DossierDetailView {
        requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen de feitenlijst wijzigen")
        if (markdown.length > MAX_FACT_SHEET_LENGTH) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De feitenlijst is te lang")
        repository.updateFactSheet(dossierId, markdown.trim())
        return detail(dossierId, user)
    }

    fun refreshFactSheet(dossierId: String, user: AuthenticatedUser): DossierDetailView {
        requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen de feitenlijst laten bijwerken")
        ensureAiAvailable()
        if (aiSearch.dossierAnswers(dossierId, limit = 1).isEmpty()) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Er zijn nog geen beantwoorde vragen om een feitenlijst uit te maken")
        }
        jobs.scheduleFactSheetRefresh(dossierId, newTurnId = null)
        return detail(dossierId, user)
    }

    // ---- Vragen ----

    fun questions(dossierId: String, user: AuthenticatedUser): List<AiSearchSummaryView> {
        access(dossierId, user)
        return aiSearch.listInDossier(dossierId)
    }

    fun ask(dossierId: String, user: AuthenticatedUser, question: String): AiSearchSessionView {
        val (dossier, _) = requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen vragen stellen")
        ensureUserJobCapacity(user)
        val view = aiSearch.startInDossier(owner(dossier, user), question, questionContext(dossier))
        repository.touch(dossierId)
        return view
    }

    fun followUp(dossierId: String, user: AuthenticatedUser, sessionId: String, question: String): AiSearchSessionView {
        val (dossier, _) = requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen vragen stellen")
        ensureUserJobCapacity(user)
        val view = aiSearch.followUpInDossier(dossierId, sessionId, question, questionContext(dossier))
        repository.touch(dossierId)
        return view
    }

    fun question(dossierId: String, user: AuthenticatedUser, sessionId: String): AiSearchSessionView {
        access(dossierId, user)
        return aiSearch.getInDossier(dossierId, sessionId)
    }

    fun cancelQuestion(dossierId: String, user: AuthenticatedUser, sessionId: String): AiSearchSessionView {
        requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen een vraag stoppen")
        return aiSearch.cancelInDossier(dossierId, sessionId)
    }

    fun deleteQuestion(dossierId: String, user: AuthenticatedUser, sessionId: String) {
        requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen een vraag verwijderen")
        aiSearch.deleteInDossier(dossierId, sessionId)
        repository.touch(dossierId)
    }

    fun adoptQuestion(dossierId: String, user: AuthenticatedUser, visitorId: String?, sessionId: String): AiSearchSessionView {
        val (dossier, _) = requireRole(dossierId, user, DossierRole::canResearch, "Alleen onderzoekers en bewerkers mogen vragen toevoegen")
        if (visitorId == null) throw ResponseStatusException(HttpStatus.NOT_FOUND, "Zoekopdracht niet gevonden")
        val view = aiSearch.adoptIntoDossier(visitorId, sessionId, owner(dossier, user))
        repository.touch(dossierId)
        jobs.scheduleFactSheetRefresh(dossierId, newTurnId = null)
        return view
    }

    // ---- Hulpfuncties ----

    fun articleSummaries(dossierId: String): List<ArticleSummaryView> = repository.articles(dossierId).map { article ->
        val current = article.currentVersionId?.let(repository::findVersion)
        val proposal = repository.openProposal(article.id)
        ArticleSummaryView(
            id = article.id,
            title = article.title,
            currentVersionNumber = current?.versionNumber ?: 0,
            proposalState = proposal?.let { if (it.isActiveJob) "RUNNING" else "READY" },
            createdByEmail = article.createdByEmail,
            createdAt = article.createdAt,
            updatedAt = article.updatedAt,
        )
    }

    /** Vaste context voor iedere dossiervraag: titel, doel, feitenlijst en eerdere vraagtitels. */
    fun questionContext(dossier: Dossier): String = buildString {
        append("Titel van het dossier: ").append(dossier.title).append('\n')
        append("Doel van het dossier: ").append(dossier.goal.ifBlank { "(geen doel opgegeven)" }).append('\n')
        val earlier = aiSearch.listInDossier(dossier.id).map { it.title ?: it.question }
        if (earlier.isNotEmpty()) {
            append("Eerdere vragen in dit dossier:\n")
            earlier.take(40).forEach { append("- ").append(it.take(200)).append('\n') }
        }
        if (dossier.factSheetMarkdown.isNotBlank()) {
            append("Feitenlijst van het dossier (Markdown, data):\n<fact-sheet>\n")
            append(dossier.factSheetMarkdown.take(FACT_SHEET_CONTEXT_CHARS))
            append("\n</fact-sheet>\n")
        }
    }

    fun ensureUserJobCapacity(user: AuthenticatedUser) {
        val active = aiSearch.activeTurnCountForUser(user.id) + repository.activeJobCountForUser(user.email)
        if (active >= MAX_ACTIVE_JOBS_PER_USER) {
            throw ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Je hebt al een lopende AI-opdracht. Wacht tot die klaar is.")
        }
    }

    fun ensureAiAvailable() {
        if (!aiSearch.isAvailable()) throw ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI is nog niet geconfigureerd")
    }

    private fun owner(dossier: Dossier, user: AuthenticatedUser) =
        AiSearchOwner(dossierId = dossier.id, userId = user.id, userEmail = user.email)

    private fun roleOf(dossier: Dossier, user: AuthenticatedUser): DossierRole =
        if (dossier.ownerUserId == user.id) DossierRole.OWNER else repository.memberRole(dossier.id, user.email) ?: DossierRole.READER

    private fun Dossier.toSummary(role: DossierRole) = DossierSummaryView(
        id = id,
        title = title,
        goal = goal,
        role = role,
        ownerEmail = ownerEmail,
        memberCount = repository.memberCount(id),
        questionCount = repository.questionCount(id),
        articleCount = repository.articleCount(id),
        createdAt = createdAt,
        updatedAt = updatedAt,
    )

    private fun validateTitle(title: String): String {
        val cleaned = title.trim()
        if (cleaned.isEmpty()) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Geef het dossier een titel")
        if (cleaned.length > 200) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "De titel mag maximaal 200 tekens bevatten")
        return cleaned
    }

    private fun validateGoal(goal: String): String {
        val cleaned = goal.trim()
        if (cleaned.length > 2000) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Het doel mag maximaal 2000 tekens bevatten")
        return cleaned
    }

    private fun normalizeEmail(email: String): String {
        val cleaned = email.trim().lowercase()
        if (cleaned.length < 3 || '@' !in cleaned || cleaned.length > 320) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Geef een geldig e-mailadres op")
        }
        return cleaned
    }

    private fun notFound() = ResponseStatusException(HttpStatus.NOT_FOUND, "Dossier niet gevonden")

    companion object {
        const val MAX_FACT_SHEET_LENGTH = 60_000
        const val FACT_SHEET_CONTEXT_CHARS = 18_000
        const val MAX_ACTIVE_JOBS_PER_USER = 1
    }
}
