package nl.vdzon.hkh.aisearch

import java.time.Duration
import java.time.Instant
import nl.vdzon.hkh.research.AiRole
import nl.vdzon.hkh.research.DurationFit
import nl.vdzon.hkh.research.JobDurationEstimator
import nl.vdzon.hkh.research.JobDurationSample
import org.slf4j.LoggerFactory
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Component

/**
 * Schat de duur van een modelaanroep uit eerdere onderzoeken: per geslaagde beurt staat in
 * `research_stats` per job de stap, het model, de duur en (sinds de korte stand) de omvang van de
 * invoer. De metingen van de laatste beurten worden kort onthouden, zodat een lopend onderzoek de
 * database niet bij elke stap bevraagt.
 */
@Component
class StoredJobDurations(private val jdbc: JdbcTemplate, private val modelSettings: AiModelSettings) : JobDurationEstimator {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Volatile private var cached: Pair<Instant, List<JobDurationSample>>? = null

    override fun estimateSeconds(role: AiRole, step: String, inputChars: Int): Int {
        val execution = modelSettings.execution(role)
        return DurationFit.estimate(samples(), step, "${execution.vendorId}/${execution.model}", inputChars)
    }

    private fun samples(): List<JobDurationSample> {
        cached?.takeIf { Duration.between(it.first, Instant.now()) < CACHE }?.let { return it.second }
        val loaded = runCatching {
            jdbc.query(
                """
                SELECT j->>'step' AS step, j->>'model' AS model, j->>'seconds' AS seconds, j->>'inputChars' AS input_chars
                FROM (
                    SELECT research_stats FROM ai_search_turn
                    WHERE research_stats IS NOT NULL AND status = 'SUCCEEDED'
                    ORDER BY created_at DESC LIMIT $TURNS
                ) t, jsonb_array_elements(CASE WHEN jsonb_typeof(t.research_stats->'jobs') = 'array' THEN t.research_stats->'jobs' ELSE '[]'::jsonb END) j
                """.trimIndent(),
            ) { rs, _ ->
                JobDurationSample(
                    step = rs.getString("step").orEmpty(),
                    model = rs.getString("model")?.takeIf { it.isNotBlank() },
                    inputChars = rs.getString("input_chars")?.toDoubleOrNull()?.toInt() ?: 0,
                    seconds = rs.getString("seconds")?.toDoubleOrNull()?.toLong() ?: 0,
                )
            }.filter { it.step.isNotBlank() && it.seconds > 0 }
        }.getOrElse {
            logger.warn("De duur van eerdere modelaanroepen kon niet worden gelezen; de voortgang gebruikt beginwaarden: {}", it.message)
            emptyList()
        }
        cached = Instant.now() to loaded
        return loaded
    }

    private companion object {
        val CACHE: Duration = Duration.ofMinutes(5)
        const val TURNS = 400
    }
}
