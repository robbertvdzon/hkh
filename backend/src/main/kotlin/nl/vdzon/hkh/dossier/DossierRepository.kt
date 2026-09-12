package nl.vdzon.hkh.dossier

import java.sql.ResultSet
import java.sql.Timestamp
import java.util.UUID
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository

@Repository
class DossierRepository(private val jdbc: JdbcTemplate) {
    // ---- Dossiers ----

    fun create(ownerUserId: String, title: String, goal: String): Dossier {
        val id = UUID.randomUUID().toString()
        jdbc.update(
            "INSERT INTO dossier (id, owner_user_id, title, goal) VALUES (?::uuid, ?::uuid, ?, ?)",
            id, ownerUserId, title, goal,
        )
        return requireNotNull(find(id))
    }

    fun find(id: String): Dossier? = jdbc.query("$DOSSIER_SELECT WHERE d.id = ?::uuid", dossierMapper, id).singleOrNull()

    /** Eigen dossiers en dossiers waarvan de gebruiker lid is, laatst gewijzigd eerst. */
    fun accessible(userId: String, email: String): List<Dossier> = jdbc.query(
        """
        $DOSSIER_SELECT
        WHERE d.owner_user_id = ?::uuid
           OR EXISTS (SELECT 1 FROM dossier_member m WHERE m.dossier_id = d.id AND m.user_email = ?)
        ORDER BY d.updated_at DESC
        """.trimIndent(),
        dossierMapper,
        userId, email,
    )

    fun update(id: String, title: String, goal: String) {
        jdbc.update("UPDATE dossier SET title = ?, goal = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid", title, goal, id)
    }

    fun touch(id: String) {
        jdbc.update("UPDATE dossier SET updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid", id)
    }

    fun delete(id: String) {
        jdbc.update("DELETE FROM dossier WHERE id = ?::uuid", id)
    }

    fun transferOwnership(id: String, newOwnerUserId: String) {
        jdbc.update("UPDATE dossier SET owner_user_id = ?::uuid, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid", newOwnerUserId, id)
    }

    // ---- Feitenlijst ----

    fun updateFactSheet(id: String, markdown: String) {
        jdbc.update(
            """
            UPDATE dossier SET fact_sheet_md = ?, fact_sheet_updated_at = CURRENT_TIMESTAMP,
                fact_sheet_error = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?::uuid
            """.trimIndent(),
            markdown, id,
        )
    }

    /** Claimt de feitenlijst-job; false als er al een loopt (dan wordt alleen dirty gezet). */
    fun claimFactSheetJob(id: String): Boolean {
        val claimed = jdbc.update(
            """
            UPDATE dossier SET fact_sheet_status = 'RUNNING', fact_sheet_job_id = NULL, fact_sheet_dirty = FALSE,
                fact_sheet_error = NULL
            WHERE id = ?::uuid AND fact_sheet_status <> 'RUNNING'
            """.trimIndent(),
            id,
        ) > 0
        if (!claimed) jdbc.update("UPDATE dossier SET fact_sheet_dirty = TRUE WHERE id = ?::uuid AND fact_sheet_status = 'RUNNING'", id)
        return claimed
    }

    fun attachFactSheetJob(id: String, jobId: String) {
        jdbc.update("UPDATE dossier SET fact_sheet_job_id = ? WHERE id = ?::uuid", jobId, id)
    }

    fun finishFactSheetJob(id: String, markdown: String?, error: String?) {
        if (markdown != null) {
            jdbc.update(
                """
                UPDATE dossier SET fact_sheet_md = ?, fact_sheet_status = 'IDLE', fact_sheet_job_id = NULL,
                    fact_sheet_error = NULL, fact_sheet_updated_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?::uuid
                """.trimIndent(),
                markdown, id,
            )
        } else {
            jdbc.update(
                "UPDATE dossier SET fact_sheet_status = 'FAILED', fact_sheet_job_id = NULL, fact_sheet_error = ? WHERE id = ?::uuid",
                error?.take(1000), id,
            )
        }
    }

    fun runningFactSheetDossierIds(): List<String> =
        jdbc.queryForList("SELECT id::text FROM dossier WHERE fact_sheet_status = 'RUNNING'", String::class.java)

    // ---- Leden ----

    fun members(dossierId: String): List<DossierMember> = jdbc.query(
        "SELECT user_email, role, created_at FROM dossier_member WHERE dossier_id = ?::uuid ORDER BY created_at",
        { rs, _ -> DossierMember(rs.getString("user_email"), DossierRole.valueOf(rs.getString("role")), rs.getTimestamp("created_at").toInstant()) },
        dossierId,
    )

    fun memberRole(dossierId: String, email: String): DossierRole? = jdbc.queryForList(
        "SELECT role FROM dossier_member WHERE dossier_id = ?::uuid AND user_email = ?",
        String::class.java,
        dossierId, email,
    ).singleOrNull()?.let(DossierRole::valueOf)

    fun upsertMember(dossierId: String, email: String, role: DossierRole, invitedByUserId: String) {
        jdbc.update(
            """
            INSERT INTO dossier_member (dossier_id, user_email, role, invited_by_user_id)
            VALUES (?::uuid, ?, ?, ?::uuid)
            ON CONFLICT (dossier_id, user_email) DO UPDATE SET role = EXCLUDED.role
            """.trimIndent(),
            dossierId, email, role.name, invitedByUserId,
        )
    }

    fun removeMember(dossierId: String, email: String): Boolean =
        jdbc.update("DELETE FROM dossier_member WHERE dossier_id = ?::uuid AND user_email = ?", dossierId, email) > 0

    fun memberCount(dossierId: String): Int =
        jdbc.queryForObject("SELECT COUNT(*) FROM dossier_member WHERE dossier_id = ?::uuid", Int::class.java, dossierId) ?: 0

    fun questionCount(dossierId: String): Int =
        jdbc.queryForObject("SELECT COUNT(*) FROM ai_search_session WHERE dossier_id = ?::uuid", Int::class.java, dossierId) ?: 0

    // ---- Artikelen ----

    fun createArticle(dossierId: String, title: String, createdByEmail: String?): Article {
        val id = UUID.randomUUID().toString()
        jdbc.update(
            "INSERT INTO article (id, dossier_id, title, created_by_email) VALUES (?::uuid, ?::uuid, ?, ?)",
            id, dossierId, title, createdByEmail,
        )
        return requireNotNull(findArticle(id))
    }

    fun findArticle(id: String): Article? =
        jdbc.query("SELECT * FROM article WHERE id = ?::uuid", articleMapper, id).singleOrNull()

    fun articles(dossierId: String): List<Article> =
        jdbc.query("SELECT * FROM article WHERE dossier_id = ?::uuid ORDER BY updated_at DESC", articleMapper, dossierId)

    fun articleCount(dossierId: String): Int =
        jdbc.queryForObject("SELECT COUNT(*) FROM article WHERE dossier_id = ?::uuid", Int::class.java, dossierId) ?: 0

    fun setCurrentVersion(articleId: String, versionId: String, title: String) {
        jdbc.update(
            "UPDATE article SET current_version_id = ?::uuid, title = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid",
            versionId, title, articleId,
        )
    }

    fun deleteArticle(id: String) {
        jdbc.update("DELETE FROM article WHERE id = ?::uuid", id)
    }

    // ---- Versies ----

    fun createVersion(
        articleId: String,
        title: String,
        contentMarkdown: String,
        authorKind: AuthorKind,
        authorEmail: String?,
        aiInstruction: String?,
        changeSummary: String?,
        state: VersionState,
        basedOnVersionId: String?,
        jobStatus: JobStatus?,
        progressMessage: String? = null,
    ): ArticleVersion {
        val id = UUID.randomUUID().toString()
        val number = jdbc.queryForObject(
            "SELECT COALESCE(MAX(version_number), 0) + 1 FROM article_version WHERE article_id = ?::uuid",
            Int::class.java,
            articleId,
        ) ?: 1
        jdbc.update(
            """
            INSERT INTO article_version (id, article_id, version_number, title, content_md, author_kind, author_email,
                ai_instruction, change_summary, state, based_on_version_id, job_status, progress_message, decided_at, decided_by_email)
            VALUES (?::uuid, ?::uuid, ?, ?, ?, ?, ?, ?, ?, ?, ?::uuid, ?, ?, ?, ?)
            """.trimIndent(),
            id, articleId, number, title, contentMarkdown, authorKind.name, authorEmail,
            aiInstruction, changeSummary?.take(1000), state.name, basedOnVersionId, jobStatus?.name, progressMessage,
            if (state == VersionState.ACCEPTED) Timestamp.from(java.time.Instant.now()) else null,
            if (state == VersionState.ACCEPTED) authorEmail else null,
        )
        return requireNotNull(findVersion(id))
    }

    fun findVersion(id: String): ArticleVersion? =
        jdbc.query("SELECT * FROM article_version WHERE id = ?::uuid", versionMapper, id).singleOrNull()

    fun findVersion(articleId: String, number: Int): ArticleVersion? = jdbc.query(
        "SELECT * FROM article_version WHERE article_id = ?::uuid AND version_number = ?",
        versionMapper, articleId, number,
    ).singleOrNull()

    fun versions(articleId: String): List<ArticleVersion> =
        jdbc.query("SELECT * FROM article_version WHERE article_id = ?::uuid ORDER BY version_number", versionMapper, articleId)

    fun openProposal(articleId: String): ArticleVersion? = jdbc.query(
        "SELECT * FROM article_version WHERE article_id = ?::uuid AND state = 'PROPOSED' ORDER BY version_number DESC LIMIT 1",
        versionMapper, articleId,
    ).firstOrNull()

    fun activeJobVersions(): List<ArticleVersion> = jdbc.query(
        "SELECT * FROM article_version WHERE job_status IN ('SUBMITTING', 'RUNNING') ORDER BY created_at",
        versionMapper,
    )

    fun activeJobCountForUser(email: String): Int = jdbc.queryForObject(
        "SELECT COUNT(*) FROM article_version WHERE author_email = ? AND job_status IN ('SUBMITTING', 'RUNNING')",
        Int::class.java, email,
    ) ?: 0

    fun attachVersionJob(id: String, jobId: String): Boolean = jdbc.update(
        "UPDATE article_version SET runtime_job_id = ?, job_status = 'RUNNING', progress_message = 'De schrijfopdracht staat klaar' WHERE id = ?::uuid AND job_status = 'SUBMITTING'",
        jobId, id,
    ) > 0

    fun updateVersionProgress(id: String, message: String?) {
        jdbc.update("UPDATE article_version SET progress_message = ? WHERE id = ?::uuid AND job_status IN ('SUBMITTING', 'RUNNING')", message?.take(500), id)
    }

    fun completeVersionJob(id: String, title: String, contentMarkdown: String, changeSummary: String?) {
        jdbc.update(
            """
            UPDATE article_version SET job_status = 'SUCCEEDED', title = ?, content_md = ?, change_summary = ?,
                progress_message = NULL, error_message = NULL
            WHERE id = ?::uuid
            """.trimIndent(),
            title, contentMarkdown, changeSummary?.take(1000), id,
        )
    }

    fun failVersionJob(id: String, error: String, cancelled: Boolean = false) {
        jdbc.update(
            """
            UPDATE article_version SET job_status = ?, state = 'REJECTED', error_message = ?, progress_message = NULL,
                decided_at = CURRENT_TIMESTAMP
            WHERE id = ?::uuid
            """.trimIndent(),
            if (cancelled) "CANCELLED" else "FAILED", error.take(1000), id,
        )
    }

    fun decideVersion(id: String, state: VersionState, decidedByEmail: String) {
        jdbc.update(
            "UPDATE article_version SET state = ?, decided_at = CURRENT_TIMESTAMP, decided_by_email = ? WHERE id = ?::uuid",
            state.name, decidedByEmail, id,
        )
    }

    // ---- Mappers ----

    private val dossierMapper = RowMapper { rs: ResultSet, _: Int ->
        Dossier(
            id = rs.getString("id"),
            ownerUserId = rs.getString("owner_user_id"),
            ownerEmail = rs.getString("owner_email"),
            title = rs.getString("title"),
            goal = rs.getString("goal"),
            factSheetMarkdown = rs.getString("fact_sheet_md"),
            factSheetStatus = FactSheetStatus.valueOf(rs.getString("fact_sheet_status")),
            factSheetJobId = rs.getString("fact_sheet_job_id"),
            factSheetDirty = rs.getBoolean("fact_sheet_dirty"),
            factSheetError = rs.getString("fact_sheet_error"),
            factSheetUpdatedAt = rs.getTimestamp("fact_sheet_updated_at")?.toInstant(),
            createdAt = rs.getTimestamp("created_at").toInstant(),
            updatedAt = rs.getTimestamp("updated_at").toInstant(),
        )
    }

    private val articleMapper = RowMapper { rs: ResultSet, _: Int ->
        Article(
            id = rs.getString("id"),
            dossierId = rs.getString("dossier_id"),
            title = rs.getString("title"),
            createdByEmail = rs.getString("created_by_email"),
            currentVersionId = rs.getString("current_version_id"),
            createdAt = rs.getTimestamp("created_at").toInstant(),
            updatedAt = rs.getTimestamp("updated_at").toInstant(),
        )
    }

    private val versionMapper = RowMapper { rs: ResultSet, _: Int ->
        ArticleVersion(
            id = rs.getString("id"),
            articleId = rs.getString("article_id"),
            versionNumber = rs.getInt("version_number"),
            title = rs.getString("title"),
            contentMarkdown = rs.getString("content_md"),
            authorKind = AuthorKind.valueOf(rs.getString("author_kind")),
            authorEmail = rs.getString("author_email"),
            aiInstruction = rs.getString("ai_instruction"),
            changeSummary = rs.getString("change_summary"),
            state = VersionState.valueOf(rs.getString("state")),
            basedOnVersionId = rs.getString("based_on_version_id"),
            runtimeJobId = rs.getString("runtime_job_id"),
            jobStatus = rs.getString("job_status")?.let(JobStatus::valueOf),
            progressMessage = rs.getString("progress_message"),
            errorMessage = rs.getString("error_message"),
            createdAt = rs.getTimestamp("created_at").toInstant(),
            decidedAt = rs.getTimestamp("decided_at")?.toInstant(),
            decidedByEmail = rs.getString("decided_by_email"),
        )
    }

    private companion object {
        const val DOSSIER_SELECT = """
            SELECT d.*, u.email AS owner_email
            FROM dossier d JOIN app_user u ON u.id = d.owner_user_id
        """
    }
}
