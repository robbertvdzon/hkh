package nl.vdzon.hkh.aisearch

import jakarta.annotation.PreDestroy
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.transaction.support.TransactionTemplate
import tools.jackson.databind.JsonNode

@Component
class AiCapacityScheduler(
    private val store: AiCapacityStore,
    private val service: AiCapacityService,
    private val search: AiSearchService,
    private val runtime: AgentRuntimeClient,
    private val transactions: TransactionTemplate,
) {
    private val owner = UUID.randomUUID().toString()
    private val executor = Executors.newVirtualThreadPerTaskExecutor()
    private val processing = ConcurrentHashMap.newKeySet<String>()
    private val log = LoggerFactory.getLogger(javaClass)

    @PreDestroy fun close() { executor.shutdownNow() }

    /** The lease is renewed independently of slow provider polls. PostgreSQL arbitrates replicas. */
    @Scheduled(fixedDelayString = "\${hkh.capacity.poll-ms:2000}")
    fun tick() {
        if (!runtime.isConfigured()) return
        val ids = try { store.jdbc.queryForList("""UPDATE ai_capacity_campaign SET lease_owner=?,lease_until=now()+interval '90 seconds'
            WHERE status IN ('RUNNING','WAITING_LIMIT','PAUSING','STOPPING','DRAINING')
            AND (lease_owner=? OR lease_until IS NULL OR lease_until < now()) RETURNING id::text""", String::class.java, owner, owner) } catch (ex: org.springframework.dao.DataAccessException) {
            log.debug("Campagnescheduler wacht op de database: {}", ex.javaClass.simpleName)
            return
        }
        ids.forEach { id ->
            if (processing.add(id)) executor.submit {
                try { advance(id) } catch (ex: Exception) { log.warn("Capaciteitstest {}: {}", id, ex.javaClass.simpleName) }
                finally { processing.remove(id) }
            }
        }
    }

    fun advance(id: String) {
        val campaignStatus = store.jdbc.queryForObject("SELECT status FROM ai_capacity_campaign WHERE id=?::uuid", String::class.java, id)
        if (campaignStatus in setOf("STOPPING", "DRAINING")) {
            val unlinked = store.rows("""SELECT p.* FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
                WHERE r.campaign_id=?::uuid AND p.job_id IS NULL AND p.status='SUBMITTING'""", id)
            for (phase in unlinked) {
                if (phase["dispatch_body"] != null) {
                    // Re-submit the identical persisted body: this recovers a lost create response.
                    val job = runtime.recoverCapacityJob(phase["phase_key"].toString())
                    runtime.cancel(job.id)
                } else store.jdbc.update("""UPDATE ai_capacity_phase SET status='CANCELLED',collected=true
                    WHERE turn_id=?::uuid AND phase_key=? AND generation=? AND dispatch_body IS NULL AND job_id IS NULL""",
                    phase["turn_id"].toString(), phase["phase_key"], phase["generation"])
            }
        }
        // Include terminal phases until their usage and late events have been collected.
        val phases = store.rows("""SELECT p.* FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
            WHERE r.campaign_id=?::uuid AND p.job_id IS NOT NULL AND NOT p.collected ORDER BY p.created_at""", id)
        for (phase in phases) {
            if (Thread.currentThread().isInterrupted) return
            val job = phase["job_id"].toString()
            val cursor = (phase["event_cursor"] as Number).toLong()
            val current = runtime.getJob(job)
            val events = runtime.jobEvents(job, cursor)
            var next = cursor
            for (event in events.path("items")) {
                next = maxOf(next, event.path("sequence").asLong())
                val limit = event.path("providerLimit")
                if (!limit.isMissingNode && !limit.isNull) recordLimit(id, job, event, limit)
            }
            val terminal = current.status in setOf("SUCCEEDED", "FAILED", "CANCELLED")
            val priorTerminal = phase["status"] in setOf("SUCCEEDED", "FAILED", "CANCELLED", "RETRY")
            val usage = if (terminal || !priorTerminal || phase["usage"] == null) runtime.jobUsage(job) else null
            val attempts = if (terminal) runtime.jobAttempts(job) else null
            store.jdbc.update("""UPDATE ai_capacity_phase SET event_cursor=GREATEST(event_cursor,?),
                status=CASE WHEN status='RETRY' THEN status ELSE ? END,
                usage=COALESCE(?::jsonb,usage),attempts=COALESCE(?::jsonb,attempts),error_code=?,error_message=?,collected=?,updated_at=now() WHERE job_id=?""",
                next, current.status, usage?.toString(), attempts?.toString(), current.errorCode, current.errorMessage, terminal && events.path("items").size() < 100, job)
            if (current.status == "SUCCEEDED" && phase["result"] == null) {
                val result = runtime.getResultEnvelope(job)
                store.jdbc.update("UPDATE ai_capacity_phase SET result=?::jsonb WHERE job_id=?", result.toString(), job)
            }
        }
        // Drain all queued event pages before counting final outcomes or dispatching more work.
        if (store.jdbc.queryForObject("""SELECT EXISTS(SELECT 1 FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
            WHERE r.campaign_id=?::uuid AND NOT p.collected AND p.status IN ('SUCCEEDED','FAILED','CANCELLED'))""", Boolean::class.java, id) == true) return
        val toRun = transactions.execute {
            val campaign = store.rows("SELECT * FROM ai_capacity_campaign WHERE id=?::uuid AND lease_owner=? AND lease_until>now() FOR UPDATE", id, owner).singleOrNull()
                ?: return@execute emptyList<String>()
            var status = campaign["status"].toString()
            val config = store.mapper.treeToValue(store.node(campaign, "config"), CapacityConfig::class.java)
            if (status in setOf("RUNNING", "PAUSING")) service.advanceScenario(id, config)
            // A turn is counted once, independently of its number of phases/attempts.
            service.reconcile(id)
            // Only provider limits make a failed phase eligible for an explicit campaign retry.
            store.jdbc.update("""UPDATE ai_capacity_run r SET status='RETRY',completed_at=NULL WHERE r.campaign_id=?::uuid AND r.status='FAILED'
                AND EXISTS(SELECT 1 FROM ai_capacity_phase p JOIN ai_capacity_limit l ON l.job_id=p.job_id
                    WHERE p.turn_id=r.current_turn_id AND p.status='FAILED' AND (l.observation->>'blocked')::boolean
                    AND l.observation->>'kind' IN ('SHORT_WINDOW','UNKNOWN'))""", id)
            if (status == "WAITING_LIMIT") {
                val reset = campaign["next_dispatch_at"]?.toString()?.let(Instant::parse)
                if (reset != null && !reset.isAfter(Instant.now())) {
                    store.jdbc.update("UPDATE ai_capacity_campaign SET status='RUNNING',next_dispatch_at=NULL WHERE id=?::uuid", id)
                    store.event(id, "Wachttermijn verstreken; onvoltooide scenario's worden hervat.")
                    status = "RUNNING"
                }
            }
            if (status in setOf("RUNNING", "WAITING_LIMIT", "PAUSING") && !config.endsAt.isAfter(Instant.now())) {
                status = "DRAINING"
                store.jdbc.update("UPDATE ai_capacity_campaign SET status='DRAINING',reason='Eindtijd bereikt; limiet niet bereikt' WHERE id=?::uuid", id)
            }
            if (status == "RUNNING" && config.maxCostUsd != null && knownCost(id) >= config.maxCostUsd) {
                status = "DRAINING"
                store.jdbc.update("UPDATE ai_capacity_campaign SET status='DRAINING',reason='Kostenbudget bereikt (API-equivalent)' WHERE id=?::uuid", id)
            }
            if (status == "RUNNING") {
                store.jdbc.update("""UPDATE ai_capacity_phase p SET status='RETRY' FROM ai_capacity_run r
                    WHERE p.turn_id=r.current_turn_id AND r.campaign_id=?::uuid AND r.status='RETRY' AND p.status='FAILED'""", id)
                store.jdbc.update("""UPDATE ai_search_turn t SET status='SUBMITTING',error_message=NULL,completed_at=NULL,
                    runtime_job_id=CASE WHEN research_method='AGENT' THEN NULL ELSE runtime_job_id END
                    FROM ai_capacity_run r WHERE r.current_turn_id=t.id AND r.campaign_id=?::uuid AND r.status='RETRY'""", id)
                store.jdbc.update("UPDATE ai_capacity_run SET status='ACTIVE',error_message=NULL WHERE campaign_id=?::uuid AND status='RETRY'", id)
                service.allocate(id, config)
            }
            if (status == "PAUSING" && campaign["next_dispatch_at"] != null) {
                // A manual pause during provider cooldown must not issue recovery probes.
                store.jdbc.update("""UPDATE ai_capacity_run r SET status='RETRY' WHERE r.campaign_id=?::uuid AND r.status='ACTIVE'
                    AND NOT EXISTS(SELECT 1 FROM ai_capacity_phase p JOIN ai_capacity_turn ct ON ct.turn_id=p.turn_id
                        WHERE ct.id=r.id AND p.status NOT IN ('SUCCEEDED','FAILED','CANCELLED','RETRY'))""", id)
            }
            val counts = service.counts(id)
            val active = counts["ACTIVE"] ?: 0L
            if (status == "PAUSING" && active == 0L) finish(id, "PAUSED", null)
            if (status in setOf("STOPPING", "DRAINING")) {
                // Do not free the provider while a runtime job can still consume quota.
                val live = store.jdbc.queryForObject("""SELECT count(*) FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
                    WHERE r.campaign_id=?::uuid AND p.status NOT IN ('SUCCEEDED','FAILED','CANCELLED','RETRY')""", Int::class.java, id)!!
                if (live == 0) {
                    store.jdbc.update("UPDATE ai_capacity_run SET status='CANCELLED',completed_at=now() WHERE campaign_id=?::uuid AND status IN ('ACTIVE','RETRY')", id)
                    store.jdbc.update("""UPDATE ai_search_turn t SET status='CANCELLED',completed_at=now() FROM ai_capacity_turn r
                        WHERE r.turn_id=t.id AND r.campaign_id=?::uuid AND t.status IN ('SUBMITTING','QUEUED','RUNNING')""", id)
                    val reason = campaign["reason"]?.toString().orEmpty()
                    finish(id, if (status == "STOPPING") "STOPPED" else if (reason.startsWith("Providergrens")) "LIMIT_REACHED" else "COMPLETED", null)
                }
            }
            if (status == "RUNNING" && active == 0L && (counts["RETRY"] ?: 0L) == 0L) {
                val total = counts.values.sum()
                if (total >= config.maxScenarios) finish(id, "COMPLETED", "Aantallimiet bereikt; limiet niet bereikt")
                else finish(id, "COMPLETED", "Vragenlijst uitgeput; limiet niet bereikt")
            }
            if (status in setOf("RUNNING", "PAUSING")) store.jdbc.queryForList("SELECT current_turn_id::text FROM ai_capacity_run WHERE campaign_id=?::uuid AND status='ACTIVE'", String::class.java, id)
            else emptyList<String>()
        }.orEmpty()
        // Cancellation and scheduling are outside the database transaction.
        val state = store.jdbc.queryForObject("SELECT status FROM ai_capacity_campaign WHERE id=?::uuid", String::class.java, id)
        if (state in setOf("STOPPING", "DRAINING")) {
            store.jdbc.queryForList("""SELECT p.job_id FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id
                WHERE r.campaign_id=?::uuid AND p.job_id IS NOT NULL AND p.status NOT IN ('SUCCEEDED','FAILED','CANCELLED','RETRY')""", String::class.java, id)
                .forEach(runtime::cancel)
        }
        toRun.forEach(search::scheduleCapacity)
    }

    private fun countsAt(id: String, observedAt: String): Map<String, Any?> {
        val at = runCatching { Instant.parse(observedAt) }.getOrDefault(Instant.now()).toString()
        return store.rows("""SELECT count(*) AS started,
            count(*) FILTER (WHERE r.status='SUCCEEDED' AND r.completed_at<=?::timestamptz) AS succeeded,
            count(*) FILTER (WHERE r.status='FAILED' AND r.completed_at<=?::timestamptz) AS failed,
            count(*) FILTER (WHERE r.completed_at IS NULL OR r.completed_at>?::timestamptz) AS active
            FROM ai_capacity_run r JOIN ai_search_turn t ON t.id=r.turn_id
            WHERE r.campaign_id=?::uuid AND r.created_at<=?::timestamptz""", at, at, at, id, at).single()
    }

    private fun knownCost(id: String): java.math.BigDecimal = store.jdbc.queryForObject("""SELECT COALESCE(sum((cost->>'amount')::numeric),0)
        FROM ai_capacity_phase p JOIN ai_capacity_turn r ON r.turn_id=p.turn_id,
        LATERAL jsonb_array_elements(COALESCE(p.usage->'costs','[]'::jsonb)) cost
        WHERE r.campaign_id=?::uuid AND cost->>'currency'='USD'""", java.math.BigDecimal::class.java, id)!!

    private fun finish(id: String, status: String, reason: String?) {
        store.jdbc.update("UPDATE ai_capacity_campaign SET status=?,holds_provider=false,reason=COALESCE(?,reason),completed_at=CASE WHEN ?='PAUSED' THEN NULL ELSE now() END WHERE id=?::uuid", status, reason, status, id)
        store.event(id, "$status${reason?.let { ": $it" }.orEmpty()}")
    }

    fun recordLimit(id: String, job: String, event: JsonNode, limit: JsonNode) {
        transactions.executeWithoutResult {
            val c = store.rows("SELECT * FROM ai_capacity_campaign WHERE id=?::uuid FOR UPDATE", id).single()
            if (c["status"] in setOf("RUNNING", "PAUSING")) service.advanceScenario(id, store.mapper.treeToValue(store.node(c,"config"),CapacityConfig::class.java))
            service.reconcile(id)
            val inserted = store.jdbc.update("""INSERT INTO ai_capacity_limit(campaign_id,job_id,event_id,attempt_id,observation,counts)
                VALUES (?::uuid,?,?,?,?::jsonb,?::jsonb) ON CONFLICT DO NOTHING""",
                id, job, limit.path("eventId").asText(), event.path("attemptId").asText(null), limit.toString(), store.json(countsAt(id, limit.path("observedAt").asText())))
            if (inserted == 0 || !limit.path("blocked").asBoolean(true)) return@executeWithoutResult
            val kind = limit.path("kind").asText("UNKNOWN")
            store.event(id, "Providerlimiet $kind bij job $job; tellerstand opgeslagen.")
            if (c["status"] !in setOf("RUNNING", "WAITING_LIMIT", "PAUSING")) return@executeWithoutResult
            if (kind in setOf("WEEK", "MONTH")) {
                store.jdbc.update("UPDATE ai_capacity_campaign SET status='DRAINING',reason=? WHERE id=?::uuid", "Providergrens $kind waargenomen", id)
            } else {
                val observed = runCatching { Instant.parse(limit.path("observedAt").asText()) }.getOrDefault(Instant.now())
                val resets = runCatching { Instant.parse(limit.path("resetsAt").asText()) }.getOrNull()
                val retry = limit.path("retryAfterSeconds").takeUnless { it.isMissingNode || it.isNull }?.asLong()
                val probes = store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_limit WHERE campaign_id=?::uuid", Int::class.java, id)!!
                val fallback = (60L * (1L shl probes.coerceAtMost(8))).coerceAtMost(21_600L) + (id.hashCode().toLong() and 15L)
                val next = maxOf(resets ?: Instant.MIN, if (retry != null) observed.plusSeconds(retry) else if (resets == null) observed.plusSeconds(fallback) else Instant.MIN, Instant.now().plusSeconds(1))
                store.jdbc.update("""UPDATE ai_capacity_campaign SET status=CASE WHEN status='PAUSING' THEN 'PAUSING' ELSE 'WAITING_LIMIT' END,reason=?,next_dispatch_at=GREATEST(next_dispatch_at,?::timestamptz) WHERE id=?::uuid""",
                    "Providerlimiet $kind; wacht op herstel", next.toString(), id)
            }
        }
    }
}
