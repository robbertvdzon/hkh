package nl.vdzon.hkh.dossier

import java.time.Instant

/** Rollen in oplopende volgorde; OWNER is de eigenaar van het dossier zelf. */
enum class DossierRole {
    READER, RESEARCHER, EDITOR, OWNER;

    val canResearch: Boolean get() = this >= RESEARCHER
    val canEdit: Boolean get() = this >= EDITOR
    val canManage: Boolean get() = this == OWNER

    companion object {
        /** Rollen die aan leden toegekend kunnen worden. */
        val assignable: Set<DossierRole> = setOf(READER, RESEARCHER, EDITOR)
    }
}

enum class FactSheetStatus { IDLE, RUNNING, FAILED }

data class Dossier(
    val id: String,
    val ownerUserId: String,
    val ownerEmail: String,
    val title: String,
    val goal: String,
    val factSheetMarkdown: String,
    val factSheetStatus: FactSheetStatus,
    val factSheetJobId: String?,
    val factSheetDirty: Boolean,
    val factSheetError: String?,
    val factSheetUpdatedAt: Instant?,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class DossierMember(val email: String, val role: DossierRole, val createdAt: Instant)

enum class AuthorKind { USER, AI }

enum class VersionState { ACCEPTED, PROPOSED, REJECTED }

enum class JobStatus { SUBMITTING, RUNNING, SUCCEEDED, FAILED, CANCELLED }

data class Article(
    val id: String,
    val dossierId: String,
    val title: String,
    val createdByEmail: String?,
    val currentVersionId: String?,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class ArticleVersion(
    val id: String,
    val articleId: String,
    val versionNumber: Int,
    val title: String,
    val contentMarkdown: String,
    val authorKind: AuthorKind,
    val authorEmail: String?,
    val aiInstruction: String?,
    val changeSummary: String?,
    val state: VersionState,
    val basedOnVersionId: String?,
    val runtimeJobId: String?,
    val jobStatus: JobStatus?,
    val progressMessage: String?,
    val errorMessage: String?,
    val createdAt: Instant,
    val decidedAt: Instant?,
    val decidedByEmail: String?,
) {
    val isActiveJob: Boolean get() = jobStatus == JobStatus.SUBMITTING || jobStatus == JobStatus.RUNNING
}
