package nl.vdzon.hkh.aisearch

/** Eigenaar van persoonlijke vragen; dossierrollen worden afzonderlijk gecontroleerd. */
data class AiSearchIdentity(val visitorId: String? = null, val userId: String? = null, val userEmail: String? = null) {
    init { require((visitorId == null) != (userId == null)) }

    val id: String get() = userId ?: requireNotNull(visitorId)
    internal fun predicate(alias: String = ""): String {
        val prefix = if (alias.isEmpty()) "" else "$alias."
        return if (userId != null) "${prefix}user_id = ?::uuid AND ${prefix}dossier_id IS NULL"
        else "${prefix}visitor_id = ?::uuid AND ${prefix}user_id IS NULL AND ${prefix}dossier_id IS NULL"
    }
}
