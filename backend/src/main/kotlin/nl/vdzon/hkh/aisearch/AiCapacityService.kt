package nl.vdzon.hkh.aisearch

import java.time.Instant
import java.util.UUID
import org.springframework.dao.DuplicateKeyException
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionTemplate
import org.springframework.web.server.ResponseStatusException

@Service
class AiCapacityService(
    private val store: AiCapacityStore,
    private val runtime: AgentRuntimeClient,
    private val settings: AiModelSettings,
    private val turns: AiSearchRepository,
    private val transactions: TransactionTemplate,
    @param:org.springframework.beans.factory.annotation.Value("\${hkh.commit:local}") private val codeVersion: String = "local",
) {
    fun datasets() = store.rows("SELECT id,name,checksum,jsonb_array_length(questions) AS count,created_at,created_by FROM ai_capacity_dataset ORDER BY created_at DESC")
    fun importDataset(name: String, questions: List<CapacityQuestion>, user: String): String {
        require(name.isNotBlank() && name.length <= 160) { "Geef een naam van maximaal 160 tekens." }
        require(questions.size in 1..10_000) { "Importeer 1 tot 10.000 vragen." }
        val normalized = questions.map { it.copy(question = it.question.trim(), category = it.category.trim().take(100)) }
        require(normalized.all { it.question.length in 3..1000 }) { "Iedere vraag moet 3 tot 1000 tekens hebben." }
        require(normalized.map { it.question.lowercase().replace(Regex("\\s+"), " ") }.distinct().size == normalized.size) { "De lijst bevat dubbele vragen." }
        val json = store.json(normalized)
        val hash = java.security.MessageDigest.getInstance("SHA-256").digest(json.toByteArray()).joinToString("") { "%02x".format(it) }
        val id = UUID.randomUUID().toString()
        store.jdbc.update("INSERT INTO ai_capacity_dataset(id,name,checksum,questions,created_by) VALUES (?::uuid,?,?,?::jsonb,?)", id, name.trim(), hash, json, user.take(320))
        return id
    }

    fun create(name: String, datasetId: String, execution: AiExecution, parallelism: Int, maximum: Int, hours: Int, repeat: Boolean,
               accountAlias: String, datasetVersion: String, maxCostUsd: java.math.BigDecimal?, user: String, expandIfAvailable: Boolean = false, followUpQuestion: String? = null): String {
        require(name.isNotBlank() && name.length <= 160)
        require(parallelism in 1..50 && maximum in 1..100_000 && hours in 1..24*366) { "Kies 1–50 parallel, maximaal 100.000 vragen en 1–8784 uur." }
        require(maxCostUsd == null || maxCostUsd.signum() > 0) { "Het kostenbudget moet positief zijn." }
        require(followUpQuestion == null || followUpQuestion.trim().length in 3..1000) { "De vervolgvraag moet 3 tot 1000 tekens hebben." }
        require(accountAlias.length <= 100 && datasetVersion.length <= 300)
        require(runtime.isConfigured()) { "Agent Runtime is niet ingesteld." }
        require(runtime.executionOptions().any { it.execution == execution }) { "Deze provider/model/uitvoeringswijze ondersteunt geen gestructureerde generatie." }
        val questions = store.jdbc.queryForList("SELECT questions::text FROM ai_capacity_dataset WHERE id=?::uuid", String::class.java, datasetId).singleOrNull()
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Vragenlijst niet gevonden")
        val size = store.mapper.readTree(questions).size()
        val config = CapacityConfig(execution, settings.method(), settings.writeBudget().chars, parallelism, maximum, Instant.now().plusSeconds(hours * 3600L), repeat,
            accountAlias, datasetVersion, codeVersion, maxCostUsd = maxCostUsd, expandIfAvailable = expandIfAvailable, followUpQuestion = followUpQuestion?.trim())
        val id = UUID.randomUUID().toString()
        try {
            transactions.executeWithoutResult {
                store.jdbc.update("INSERT INTO ai_capacity_campaign(id,name,dataset_id,provider,config,created_by) VALUES (?::uuid,?,?::uuid,?,?::jsonb,?)",
                    id, name.trim(), datasetId, execution.vendorId, store.json(config), user.take(320))
                store.event(id, "Gestart: ${execution.label}; ${config.method}; $parallelism parallel; vragenlijst $size vragen. Beginquota en ander accountgebruik zijn onbekend.")
            }
        } catch (_: DuplicateKeyException) { throw ResponseStatusException(HttpStatus.CONFLICT, "Voor deze provider loopt al een campagne, of worden nog jobs afgerond.") }
        return id
    }

    fun campaigns() = store.rows("""SELECT c.*, (SELECT count(*) FROM ai_capacity_run r WHERE r.campaign_id=c.id) AS started,
        (SELECT count(*) FROM ai_capacity_run r WHERE r.campaign_id=c.id AND r.status='SUCCEEDED') AS succeeded,
        (SELECT count(*) FROM ai_capacity_run r WHERE r.campaign_id=c.id AND r.status='FAILED') AS failed,
        (SELECT count(*) FROM ai_capacity_run r WHERE r.campaign_id=c.id AND r.status IN ('ACTIVE','RETRY')) AS active
        FROM ai_capacity_campaign c ORDER BY c.created_at DESC LIMIT 100""")
        .map { it - setOf("lease_owner", "lease_until") }

    fun detail(id: String): Map<String, Any?> {
        val campaign = store.rows("SELECT * FROM ai_capacity_campaign WHERE id=?::uuid", id).singleOrNull()
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Campagne niet gevonden")
        return mapOf("campaign" to (campaign - setOf("lease_owner", "lease_until")),
            "counts" to counts(id),
            "report" to report(id),
            "dataset" to store.rows("SELECT d.id,d.name,d.checksum,d.created_at,jsonb_array_length(d.questions) AS count FROM ai_capacity_campaign c JOIN ai_capacity_dataset d ON d.id=c.dataset_id WHERE c.id=?::uuid", id).single(),
            "selections" to store.rows("""SELECT p.turn_id,p.name,p.value FROM ai_capacity_checkpoint p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
                WHERE r.campaign_id=?::uuid AND p.name IN ('selection','expand-cards')""", id),
            "runs" to store.rows("""SELECT r.*,t.status AS turn_status,t.error_message AS turn_error,t.research_stats,r.created_at AS started_at,r.completed_at AS turn_completed_at
                FROM ai_capacity_run r LEFT JOIN ai_search_turn t ON t.id=r.current_turn_id WHERE r.campaign_id=?::uuid ORDER BY ordinal""", id),
            "phases" to store.rows("""SELECT r.id AS run_id,p.turn_id,p.phase_key,p.generation,p.job_id,p.status,p.usage,p.attempts,p.error_code,p.error_message,p.created_at,p.updated_at
                FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id WHERE r.campaign_id=?::uuid ORDER BY p.created_at""", id),
            "turns" to store.rows("""SELECT t.id,t.session_id,t.turn_number,t.question,t.status,t.sources,t.research_stats,t.created_at,t.completed_at,r.id AS run_id
                FROM ai_capacity_turn r JOIN ai_search_turn t ON t.id=r.turn_id WHERE r.campaign_id=?::uuid ORDER BY r.ordinal,t.turn_number""", id),
            "limits" to store.rows("SELECT * FROM ai_capacity_limit WHERE campaign_id=?::uuid ORDER BY recorded_at", id),
            "events" to store.rows("SELECT created_at,message FROM ai_capacity_event WHERE campaign_id=?::uuid ORDER BY id", id))
    }

    /** Returns only stored, already sanitized answers; reading never creates runtime jobs. */
    fun result(campaignId: String, runId: String): Map<String, Any?> {
        val run = store.rows("""SELECT r.id,r.status,r.ordinal,r.question,c.id AS campaign_id,c.name AS campaign_name,c.config,
            t.session_id FROM ai_capacity_run r JOIN ai_capacity_campaign c ON c.id=r.campaign_id
            JOIN ai_search_turn t ON t.id=r.turn_id WHERE r.campaign_id=?::uuid AND r.id=?::uuid""", campaignId, runId).singleOrNull()
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Testresultaat niet gevonden")
        val answers = turns.turns(run["session_id"].toString()).map { turn -> mapOf(
            "id" to turn.id, "turnNumber" to turn.turnNumber, "question" to turn.question, "status" to turn.status,
            "title" to turn.title, "answerHtml" to turn.answerHtml, "sourcesHtml" to turn.sourcesHtml,
            "errorMessage" to turn.errorMessage, "expandsTurnId" to turn.expandsTurnId,
            "method" to turn.method, "depth" to turn.depth, "createdAt" to turn.createdAt, "completedAt" to turn.completedAt,
        ) }
        return mapOf("run" to (run - "session_id"), "turns" to answers)
    }

    fun report(id: String): Map<String, Any?> {
        val durations = store.jdbc.queryForList("""SELECT EXTRACT(EPOCH FROM (completed_at-created_at))::double precision
            FROM ai_capacity_run WHERE campaign_id=?::uuid AND status='SUCCEEDED' ORDER BY 1""", Double::class.java, id)
        val elapsed = store.jdbc.queryForObject("SELECT GREATEST(0,EXTRACT(EPOCH FROM (COALESCE(completed_at,now())-created_at)))::double precision FROM ai_capacity_campaign WHERE id=?::uuid", Double::class.java, id) ?: 0.0
        fun percentile(fraction: Double): Double? = if (durations.isEmpty()) null else durations[(kotlin.math.ceil(durations.size * fraction).toInt()-1).coerceAtLeast(0)]
        return mapOf("elapsedSeconds" to elapsed, "succeededPerHour" to if (elapsed > 0) durations.size * 3600 / elapsed else null,
            "medianSeconds" to percentile(0.5), "p95Seconds" to percentile(0.95),
            "beginQuota" to "UNKNOWN", "sharedAccountUse" to "UNKNOWN", "collectionSnapshotGuaranteed" to false)
    }

    fun counts(id: String) = store.rows("SELECT status,count(*) AS count FROM ai_capacity_run WHERE campaign_id=?::uuid GROUP BY status", id)
        .associate { it["status"].toString() to (it["count"] as Number).toLong() }

    fun control(id: String, action: String) {
        try {
            transactions.executeWithoutResult {
                val campaign = store.rows("SELECT * FROM ai_capacity_campaign WHERE id=?::uuid FOR UPDATE", id).singleOrNull()
                    ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Campagne niet gevonden")
                val status = campaign["status"].toString()
                when (action) {
                    "pause" -> { require(status in setOf("RUNNING", "WAITING_LIMIT")); store.jdbc.update("UPDATE ai_capacity_campaign SET status='PAUSING',reason='Handmatig gepauzeerd' WHERE id=?::uuid", id) }
                    "resume" -> {
                        require(status == "PAUSED") { "Alleen een gepauzeerde campagne kan hervatten." }
                        store.jdbc.update("UPDATE ai_capacity_campaign SET status=CASE WHEN next_dispatch_at>now() THEN 'WAITING_LIMIT' ELSE 'RUNNING' END,holds_provider=true,reason=CASE WHEN next_dispatch_at>now() THEN reason ELSE NULL END WHERE id=?::uuid", id)
                    }
                    "stop" -> {
                        require(status !in setOf("STOPPED", "COMPLETED", "LIMIT_REACHED"))
                        if (status == "PAUSED") {
                            store.jdbc.update("UPDATE ai_capacity_campaign SET status='STOPPED',completed_at=now(),reason='Handmatig gestopt' WHERE id=?::uuid", id)
                            store.jdbc.update("UPDATE ai_capacity_run SET status='CANCELLED',completed_at=now() WHERE campaign_id=?::uuid AND status IN ('ACTIVE','RETRY')", id)
                        } else store.jdbc.update("UPDATE ai_capacity_campaign SET status='STOPPING',reason='Handmatig gestopt' WHERE id=?::uuid", id)
                    }
                    else -> throw IllegalArgumentException("Onbekende actie")
                }
                if (action == "stop") store.jdbc.update("""UPDATE ai_search_turn t SET status='CANCELLED',completed_at=now()
                    FROM ai_capacity_turn r WHERE r.turn_id=t.id AND r.campaign_id=?::uuid AND t.status IN ('SUBMITTING','QUEUED','RUNNING')""", id)
                store.event(id, "Beheeractie: $action")
            }
        } catch (_: DuplicateKeyException) { throw ResponseStatusException(HttpStatus.CONFLICT, "Deze provider heeft al een actieve campagne.") }
    }

    fun reconcile(id: String) {
        store.jdbc.update("""UPDATE ai_capacity_run r SET status=t.status,error_message=t.error_message,completed_at=t.completed_at
            FROM ai_search_turn t WHERE r.current_turn_id=t.id AND r.campaign_id=?::uuid AND r.status='ACTIVE'
            AND t.status IN ('SUCCEEDED','FAILED','CANCELLED')""", id)
    }

    fun advanceScenario(id: String, config: CapacityConfig) {
        val runs = store.rows("SELECT * FROM ai_capacity_run WHERE campaign_id=?::uuid AND status='ACTIVE'", id)
        for (run in runs) {
            val turn = turns.findTurn(run["current_turn_id"].toString()) ?: continue
            if (turn.status != AiTurnStatus.SUCCEEDED) continue
            val step = (run["scenario_step"] as Number).toInt()
            val next = if (step == 0 && config.expandIfAvailable && turn.method == AiResearchMethod.PIPELINE && turn.moreAvailable) {
                turns.createTurn(turn.sessionId, "Werk het antwoord volledig uit", depth = turn.depth, method = turn.method, expandsTurnId = turn.id) to 1
            } else if (step < 2 && config.followUpQuestion != null) {
                turns.createTurn(turn.sessionId, config.followUpQuestion, depth = turn.depth, method = turn.method) to 2
            } else null
            if (next != null) store.jdbc.update("UPDATE ai_capacity_run SET current_turn_id=?::uuid,scenario_step=? WHERE id=?::uuid", next.first.id, next.second, run["id"].toString())
        }
    }

    /** Called inside the scheduler's locked transaction; scenario/session/turn are atomic. */
    fun allocate(id: String, config: CapacityConfig) {
        val list = store.jdbc.queryForObject("SELECT d.questions::text FROM ai_capacity_campaign c JOIN ai_capacity_dataset d ON d.id=c.dataset_id WHERE c.id=?::uuid", String::class.java, id)!!
        val questions = store.mapper.readTree(list)
        val count = store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_run WHERE campaign_id=?::uuid", Int::class.java, id)!!
        val active = store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_run WHERE campaign_id=?::uuid AND status IN ('ACTIVE','RETRY')", Int::class.java, id)!!
        val end = minOf(count + (config.parallelism - active).coerceAtLeast(0), config.maxScenarios, if (config.repeatQuestions) Int.MAX_VALUE else questions.size())
        for (index in count until end) {
            val q = store.mapper.treeToValue(questions[index % questions.size()], CapacityQuestion::class.java)
            val session = turns.createSession(AiSearchOwner(visitorId = "00000000-0000-4000-8000-00000000ca9a", userEmail = "capaciteitstest"))
            val turn = turns.createTurn(session, q.question, depth = q.depth, method = config.method)
            store.jdbc.update("INSERT INTO ai_capacity_run(id,campaign_id,ordinal,question,turn_id,current_turn_id,status) VALUES (?::uuid,?::uuid,?,?::jsonb,?::uuid,?::uuid,'ACTIVE')",
                UUID.randomUUID().toString(), id, index + 1, store.json(q), turn.id, turn.id)
        }
    }
}
