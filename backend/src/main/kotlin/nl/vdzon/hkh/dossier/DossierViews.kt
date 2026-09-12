package nl.vdzon.hkh.dossier

import java.time.Instant
import nl.vdzon.hkh.aisearch.AiSearchSummaryView

data class MemberView(val email: String, val role: DossierRole)

data class FactSheetView(
    val markdown: String,
    val html: String,
    val sources: List<SourceView>,
    val status: FactSheetStatus,
    val dirty: Boolean,
    val updatedAt: Instant?,
    val error: String?,
)

data class DossierSummaryView(
    val id: String,
    val title: String,
    val goal: String,
    val role: DossierRole,
    val ownerEmail: String,
    val memberCount: Int,
    val questionCount: Int,
    val articleCount: Int,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class ArticleSummaryView(
    val id: String,
    val title: String,
    val currentVersionNumber: Int,
    /** null zonder open voorstel, anders RUNNING (AI schrijft nog) of READY (wacht op beoordeling). */
    val proposalState: String?,
    val createdByEmail: String?,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class DossierDetailView(
    val id: String,
    val title: String,
    val goal: String,
    val role: DossierRole,
    val ownerEmail: String,
    val members: List<MemberView>,
    val factSheet: FactSheetView,
    val questions: List<AiSearchSummaryView>,
    val articles: List<ArticleSummaryView>,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class SourceView(
    val collection: String,
    val ident: String,
    val title: String,
    val detailUrl: String,
    val imageUrl: String?,
)

data class VersionView(
    val id: String,
    val versionNumber: Int,
    val title: String,
    val contentMarkdown: String,
    val contentHtml: String,
    val sources: List<SourceView>,
    val unknownSources: List<String>,
    val authorKind: AuthorKind,
    val authorEmail: String?,
    val aiInstruction: String?,
    val changeSummary: String?,
    val state: VersionState,
    val jobStatus: JobStatus?,
    val progressMessage: String?,
    val errorMessage: String?,
    val basedOnVersionNumber: Int?,
    val createdAt: Instant,
    val decidedAt: Instant?,
    val decidedByEmail: String?,
)

data class VersionSummaryView(
    val id: String,
    val versionNumber: Int,
    val title: String,
    val authorKind: AuthorKind,
    val authorEmail: String?,
    val aiInstruction: String?,
    val changeSummary: String?,
    val state: VersionState,
    val jobStatus: JobStatus?,
    val errorMessage: String?,
    val basedOnVersionNumber: Int?,
    val isCurrent: Boolean,
    val createdAt: Instant,
    val decidedAt: Instant?,
    val decidedByEmail: String?,
)

data class ArticleDetailView(
    val id: String,
    val dossierId: String,
    val dossierTitle: String,
    val title: String,
    val role: DossierRole,
    val current: VersionView,
    val proposal: VersionView?,
    val versionCount: Int,
    val createdAt: Instant,
    val updatedAt: Instant,
)

data class DiffView(val fromVersion: Int, val toVersion: Int, val lines: List<DiffLine>)

fun RenderedSource.toView() = SourceView(collection, ident, title, detailUrl, imageUrl)
