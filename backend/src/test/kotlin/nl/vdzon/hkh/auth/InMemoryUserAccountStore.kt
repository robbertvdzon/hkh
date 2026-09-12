package nl.vdzon.hkh.auth

import java.time.Instant
import java.util.UUID

/** Eenvoudige geheugenvariant van [UserAccountStore] voor unit-tests van de sessielogica. */
class InMemoryUserAccountStore : UserAccountStore {
    val users = mutableMapOf<String, UserAccount>()
    private val sessions = mutableMapOf<String, MutableSession>()

    private data class MutableSession(
        val id: String,
        val userId: String,
        var lastUsedAt: Instant,
        var expiresAt: Instant,
        var revokedAt: Instant?,
    )

    override fun findOrCreateUser(email: String, displayName: String?): UserAccount {
        val normalized = email.trim().lowercase()
        val existing = users.values.firstOrNull { it.email == normalized }
        val user = existing?.copy(displayName = displayName ?: existing.displayName, lastLoginAt = Instant.now())
            ?: UserAccount(UUID.randomUUID().toString(), normalized, displayName, Instant.now(), Instant.now())
        users[user.id] = user
        return user
    }

    override fun findUser(id: String): UserAccount? = users[id]

    override fun findUserByEmail(email: String): UserAccount? = users.values.firstOrNull { it.email == email.trim().lowercase() }

    override fun createSession(userId: String, tokenHash: String, expiresAt: Instant): String {
        val id = UUID.randomUUID().toString()
        sessions[tokenHash] = MutableSession(id, userId, Instant.now(), expiresAt, null)
        return id
    }

    override fun findSession(tokenHash: String): StoredSession? = sessions[tokenHash]?.let {
        StoredSession(it.id, users.getValue(it.userId), it.lastUsedAt, it.expiresAt, it.revokedAt)
    }

    override fun touchSession(id: String, expiresAt: Instant) {
        sessions.values.firstOrNull { it.id == id }?.apply {
            lastUsedAt = Instant.now()
            this.expiresAt = expiresAt
        }
    }

    override fun revokeSession(tokenHash: String) {
        sessions[tokenHash]?.let { if (it.revokedAt == null) it.revokedAt = Instant.now() }
    }

    override fun revokeAllSessions(userId: String) {
        sessions.values.filter { it.userId == userId && it.revokedAt == null }.forEach { it.revokedAt = Instant.now() }
    }

    override fun deleteUser(userId: String) {
        users.remove(userId)
        sessions.values.removeIf { it.userId == userId }
    }

    fun expireSession(tokenHash: String) {
        sessions[tokenHash]?.expiresAt = Instant.now().minusSeconds(1)
    }
}
