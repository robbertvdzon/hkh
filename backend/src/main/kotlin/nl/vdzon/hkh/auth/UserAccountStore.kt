package nl.vdzon.hkh.auth

import java.sql.ResultSet
import java.time.Instant
import java.util.UUID
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.core.RowMapper
import org.springframework.stereotype.Repository

data class UserAccount(
    val id: String,
    val email: String,
    val displayName: String?,
    val createdAt: Instant,
    val lastLoginAt: Instant?,
)

data class StoredSession(
    val id: String,
    val user: UserAccount,
    val lastUsedAt: Instant,
    val expiresAt: Instant,
    val revokedAt: Instant?,
)

interface UserAccountStore {
    fun findOrCreateUser(email: String, displayName: String?): UserAccount
    fun findUser(id: String): UserAccount?
    fun findUserByEmail(email: String): UserAccount?
    fun createSession(userId: String, tokenHash: String, expiresAt: Instant): String
    fun findSession(tokenHash: String): StoredSession?
    fun touchSession(id: String, expiresAt: Instant)
    fun revokeSession(tokenHash: String)
    fun revokeAllSessions(userId: String)
    fun deleteUser(userId: String)
}

@Repository
class JdbcUserAccountStore(private val jdbc: JdbcTemplate) : UserAccountStore {
    override fun findOrCreateUser(email: String, displayName: String?): UserAccount {
        val normalized = email.trim().lowercase()
        val updated = jdbc.update(
            """
            UPDATE app_user SET last_login_at = CURRENT_TIMESTAMP,
                display_name = COALESCE(?, display_name)
            WHERE email = ?
            """.trimIndent(),
            displayName?.take(200), normalized,
        )
        if (updated == 0) {
            jdbc.update(
                "INSERT INTO app_user (id, email, display_name, last_login_at) VALUES (?::uuid, ?, ?, CURRENT_TIMESTAMP)",
                UUID.randomUUID().toString(), normalized, displayName?.take(200),
            )
        }
        return requireNotNull(findUserByEmail(normalized))
    }

    override fun findUser(id: String): UserAccount? =
        jdbc.query("SELECT * FROM app_user WHERE id = ?::uuid", userMapper, id).singleOrNull()

    override fun findUserByEmail(email: String): UserAccount? =
        jdbc.query("SELECT * FROM app_user WHERE email = ?", userMapper, email.trim().lowercase()).singleOrNull()

    override fun createSession(userId: String, tokenHash: String, expiresAt: Instant): String {
        val id = UUID.randomUUID().toString()
        jdbc.update(
            "INSERT INTO user_session (id, user_id, token_hash, expires_at) VALUES (?::uuid, ?::uuid, ?, ?)",
            id, userId, tokenHash, java.sql.Timestamp.from(expiresAt),
        )
        return id
    }

    override fun findSession(tokenHash: String): StoredSession? = jdbc.query(
        """
        SELECT s.id AS session_id, s.last_used_at, s.expires_at, s.revoked_at, u.*
        FROM user_session s JOIN app_user u ON u.id = s.user_id
        WHERE s.token_hash = ?
        """.trimIndent(),
        { rs, index ->
            StoredSession(
                id = rs.getString("session_id"),
                user = userMapper.mapRow(rs, index)!!,
                lastUsedAt = rs.getTimestamp("last_used_at").toInstant(),
                expiresAt = rs.getTimestamp("expires_at").toInstant(),
                revokedAt = rs.getTimestamp("revoked_at")?.toInstant(),
            )
        },
        tokenHash,
    ).singleOrNull()

    override fun touchSession(id: String, expiresAt: Instant) {
        jdbc.update(
            "UPDATE user_session SET last_used_at = CURRENT_TIMESTAMP, expires_at = ? WHERE id = ?::uuid",
            java.sql.Timestamp.from(expiresAt), id,
        )
    }

    override fun revokeSession(tokenHash: String) {
        jdbc.update("UPDATE user_session SET revoked_at = CURRENT_TIMESTAMP WHERE token_hash = ? AND revoked_at IS NULL", tokenHash)
    }

    override fun revokeAllSessions(userId: String) {
        jdbc.update("UPDATE user_session SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = ?::uuid AND revoked_at IS NULL", userId)
    }

    override fun deleteUser(userId: String) {
        jdbc.update("DELETE FROM app_user WHERE id = ?::uuid", userId)
    }

    private val userMapper = RowMapper { rs: ResultSet, _: Int ->
        UserAccount(
            id = rs.getString("id"),
            email = rs.getString("email"),
            displayName = rs.getString("display_name"),
            createdAt = rs.getTimestamp("created_at").toInstant(),
            lastLoginAt = rs.getTimestamp("last_login_at")?.toInstant(),
        )
    }
}
