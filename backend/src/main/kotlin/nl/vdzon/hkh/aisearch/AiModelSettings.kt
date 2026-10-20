package nl.vdzon.hkh.aisearch

import java.time.Instant
import nl.vdzon.hkh.research.AiRole
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Service
import tools.jackson.databind.ObjectMapper

/** Leverancier, model en uitvoeringswijze waarmee de digitale onderzoeker bij de runtime draait. */
data class AiExecution(val vendorId: String, val model: String, val mode: String) {
    val label: String get() = "$vendorId · $model · ${mode.lowercase()}"
}

/** Een keuze uit de runtime-catalogus, met of er nu een worker voor online is. */
data class AiExecutionOption(val execution: AiExecution, val available: Boolean, val onlineWorkers: Int)

/** De actieve keuze: uit de database (door een beheerder gekozen) of uit de configuratie. */
data class AiModelChoice(val execution: AiExecution, val fromSetting: Boolean, val updatedAt: Instant?, val updatedBy: String?)

/**
 * Het tekstbudget van de schrijver: hoeveel tekens aan bronnen hij hoogstens krijgt. Zonder eigen
 * keuze hangt de standaard af van het schrijfmodel (een klein model schrijft traag bij veel invoer).
 */
data class AiWriteBudget(val chars: Int, val fromSetting: Boolean, val default: Int)

/**
 * Het model van de digitale onderzoeker is in het beheerscherm te wisselen zonder uitrol. De
 * keuze staat in `app_setting`; zonder keuze geldt de configuratie (`hkh.ai-search.*`).
 */
@Service
class AiModelSettings(
    private val jdbc: JdbcTemplate,
    private val objectMapper: ObjectMapper,
    private val properties: AiSearchProperties,
) {
    fun current(): AiModelChoice = current(AiRole.AGENT)

    /**
     * De keuze per rol. Zonder eigen keuze erft een rol van AGENT (de instelling in het
     * beheerscherm); EXTRACTION krijgt standaard het kleine extractiemodel uit de configuratie,
     * en AGENT valt terug op de configuratie.
     */
    fun current(role: AiRole): AiModelChoice {
        val row = jdbc.query("SELECT value, updated_at, updated_by FROM app_setting WHERE key = ?", { rs, _ ->
            Triple(rs.getString("value"), rs.getTimestamp("updated_at")?.toInstant(), rs.getString("updated_by"))
        }, key(role)).singleOrNull()
        val stored = row?.let { (value, _, _) ->
            runCatching {
                val node = objectMapper.readTree(value)
                AiExecution(node.path("vendorId").asText(), node.path("model").asText(), node.path("mode").asText())
            }.getOrNull()
        }?.takeIf { it.vendorId.isNotBlank() && it.model.isNotBlank() && it.mode.isNotBlank() }
        if (stored != null) return AiModelChoice(stored, fromSetting = true, updatedAt = row.second, updatedBy = row.third)
        if (role == AiRole.EXTRACTION) {
            // Bulkwerk: standaard een klein model met dezelfde leverancier en modus als de onderzoeker.
            val base = current(AiRole.AGENT).execution
            val execution = if (base.vendorId == properties.vendorId) base.copy(model = properties.extractionModel) else base
            return AiModelChoice(execution, fromSetting = false, updatedAt = null, updatedBy = null)
        }
        if (role != AiRole.AGENT) return current(AiRole.AGENT).copy(fromSetting = false, updatedAt = null, updatedBy = null)
        return AiModelChoice(AiExecution(properties.vendorId, properties.model, properties.mode), fromSetting = false, updatedAt = null, updatedBy = null)
    }

    /** De uitvoering voor een nieuwe job: altijd de meest recente keuze, zonder cache. */
    fun execution(): AiExecution = current().execution

    fun execution(role: AiRole): AiExecution = current(role).execution

    fun update(execution: AiExecution, updatedBy: String): AiModelChoice = update(AiRole.AGENT, execution, updatedBy)

    fun update(role: AiRole, execution: AiExecution, updatedBy: String): AiModelChoice {
        val value = objectMapper.writeValueAsString(mapOf("vendorId" to execution.vendorId, "model" to execution.model, "mode" to execution.mode))
        jdbc.update(
            """
            INSERT INTO app_setting (key, value, updated_at, updated_by) VALUES (?, ?, CURRENT_TIMESTAMP, ?)
            ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP, updated_by = EXCLUDED.updated_by
            """.trimIndent(),
            key(role), value, updatedBy.take(320),
        )
        return current(role)
    }

    /** Terug naar de configuratie (AGENT) of naar de AGENT-keuze (andere rollen). */
    fun reset(): AiModelChoice = reset(AiRole.AGENT)

    fun reset(role: AiRole): AiModelChoice {
        jdbc.update("DELETE FROM app_setting WHERE key = ?", key(role))
        return current(role)
    }

    /** Het tekstbudget voor de schrijver (rol WRITER); zonder eigen keuze de standaard voor het schrijfmodel. */
    fun writeBudget(): AiWriteBudget {
        val default = defaultWriteBudget(execution(AiRole.WRITER).model)
        val stored = jdbc.queryForList("SELECT value FROM app_setting WHERE key = ?", String::class.java, WRITE_BUDGET_KEY)
            .singleOrNull()?.trim()?.toIntOrNull()?.takeIf { it in WRITE_BUDGET_RANGE }
        return AiWriteBudget(stored ?: default, fromSetting = stored != null, default = default)
    }

    fun updateWriteBudget(chars: Int, updatedBy: String): AiWriteBudget {
        require(chars in WRITE_BUDGET_RANGE) { "Het tekstbudget moet tussen ${WRITE_BUDGET_RANGE.first} en ${WRITE_BUDGET_RANGE.last} tekens liggen." }
        jdbc.update(
            """
            INSERT INTO app_setting (key, value, updated_at, updated_by) VALUES (?, ?, CURRENT_TIMESTAMP, ?)
            ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP, updated_by = EXCLUDED.updated_by
            """.trimIndent(),
            WRITE_BUDGET_KEY, chars.toString(), updatedBy.take(320),
        )
        return writeBudget()
    }

    fun resetWriteBudget(): AiWriteBudget {
        jdbc.update("DELETE FROM app_setting WHERE key = ?", WRITE_BUDGET_KEY)
        return writeBudget()
    }

    /** De onderzoeksmethode voor nieuwe vragen; zonder keuze de agent. */
    fun method(): AiResearchMethod = jdbc.queryForList("SELECT value FROM app_setting WHERE key = ?", String::class.java, METHOD_KEY)
        .singleOrNull()?.let(AiResearchMethod::parse) ?: AiResearchMethod.AGENT

    fun updateMethod(method: AiResearchMethod, updatedBy: String) {
        jdbc.update(
            """
            INSERT INTO app_setting (key, value, updated_at, updated_by) VALUES (?, ?, CURRENT_TIMESTAMP, ?)
            ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP, updated_by = EXCLUDED.updated_by
            """.trimIndent(),
            METHOD_KEY, method.name, updatedBy.take(320),
        )
    }

    private fun key(role: AiRole) = if (role == AiRole.AGENT) KEY else "$KEY.${role.name.lowercase()}"

    companion object {
        const val KEY = "ai-search.execution"
        const val METHOD_KEY = "ai-search.method"
        const val WRITE_BUDGET_KEY = "ai-search.write-budget"
        val WRITE_BUDGET_RANGE = 50_000..2_000_000
        const val WRITE_BUDGET_LARGE = 450_000
        const val WRITE_BUDGET_SMALL = 250_000

        /** Kleine modellen (haiku, mini, nano, flash) schrijven traag bij veel invoer en krijgen een kleiner budget. */
        fun defaultWriteBudget(model: String): Int =
            if (Regex("haiku|mini|nano|flash|lite", RegexOption.IGNORE_CASE).containsMatchIn(model)) WRITE_BUDGET_SMALL else WRITE_BUDGET_LARGE
    }
}
