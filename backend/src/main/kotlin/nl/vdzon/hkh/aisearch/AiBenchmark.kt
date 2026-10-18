package nl.vdzon.hkh.aisearch

import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.slf4j.LoggerFactory
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service

data class AiBenchmarkQuestion(val id: Long, val question: String, val depth: AiResearchDepth, val createdAt: Instant, val createdBy: String?)

@Repository
class AiBenchmarkRepository(private val jdbc: JdbcTemplate) {
    fun list(): List<AiBenchmarkQuestion> = jdbc.query(
        "SELECT id, question, depth, created_at, created_by FROM ai_benchmark_question ORDER BY id",
    ) { rs, _ ->
        AiBenchmarkQuestion(rs.getLong("id"), rs.getString("question"), AiResearchDepth.parse(rs.getString("depth")), rs.getTimestamp("created_at").toInstant(), rs.getString("created_by"))
    }

    fun add(question: String, depth: AiResearchDepth, createdBy: String): AiBenchmarkQuestion {
        val id = jdbc.queryForObject(
            "INSERT INTO ai_benchmark_question (question, depth, created_by) VALUES (?, ?, ?) RETURNING id",
            Long::class.java, question, depth.name, createdBy.take(320),
        )!!
        return list().first { it.id == id }
    }

    fun delete(id: Long): Boolean = jdbc.update("DELETE FROM ai_benchmark_question WHERE id = ?", id) > 0
}

/**
 * Draait de testset: iedere vraag opnieuw met de nu ingestelde methode en modellen, één tegelijk
 * zodat de runtime niet overloopt en de doorlooptijden vergelijkbaar blijven. De antwoorden komen
 * in sessies van de testset-eigenaar en verschijnen in het vergelijkingsoverzicht.
 */
@Service
class AiBenchmarkService(
    private val questions: AiBenchmarkRepository,
    private val search: AiSearchService,
    private val repository: AiSearchRepository,
) {
    private val logger = LoggerFactory.getLogger(javaClass)
    private val executor = Executors.newVirtualThreadPerTaskExecutor()
    private val running = AtomicBoolean(false)

    fun isRunning(): Boolean = running.get()

    /** Start de run op de achtergrond; false als er al één loopt. */
    fun run(startedBy: String, questionIds: List<Long>? = null): Boolean {
        if (!running.compareAndSet(false, true)) return false
        val selected = questions.list().filter { questionIds == null || it.id in questionIds }
        executor.submit {
            try {
                for (question in selected) {
                    val turnId = search.startBenchmark(question, startedBy)
                    logger.info("Testsetvraag {} gestart als beurt {}", question.id, turnId)
                    waitUntilDone(turnId)
                }
            } catch (ex: Exception) {
                logger.warn("Testsetrun afgebroken: {}", ex.message)
            } finally {
                running.set(false)
            }
        }
        return true
    }

    private fun waitUntilDone(turnId: String) {
        val deadline = System.currentTimeMillis() + MAX_TURN_MILLIS
        while (System.currentTimeMillis() < deadline) {
            val turn = repository.findTurn(turnId) ?: return
            if (turn.status in setOf(AiTurnStatus.SUCCEEDED, AiTurnStatus.FAILED, AiTurnStatus.CANCELLED)) return
            Thread.sleep(5_000)
        }
    }

    private companion object {
        const val MAX_TURN_MILLIS = 45 * 60 * 1000L
    }
}
