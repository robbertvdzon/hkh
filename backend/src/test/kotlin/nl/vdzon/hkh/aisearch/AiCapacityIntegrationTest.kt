package nl.vdzon.hkh.aisearch

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.test.*
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.research.JobAttachment
import nl.vdzon.hkh.research.AiRole
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer
import tools.jackson.databind.JsonNode
import tools.jackson.module.kotlin.jacksonObjectMapper

/** Real PostgreSQL, HTTP runtime contract and complete HKH flows; never calls a real provider. */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AiCapacityIntegrationTest(
    @param:Autowired private val service: AiCapacityService,
    @param:Autowired private val store: AiCapacityStore,
    @param:Autowired private val scheduler: AiCapacityScheduler,
    @param:Autowired private val settings: AiModelSettings,
    @param:Autowired private val runtime: AgentRuntimeClient,
    @param:Autowired private val turns: AiSearchRepository,
    @param:Autowired private val mvc: MockMvc,
) {
    private val admin = PreviewRuntimeConfig.ADMIN_HEADER to PreviewRuntimeConfig.ADMIN_HEADER_VALUE
    private fun execution(provider: String = "openai") = AiExecution(provider, "$provider-test", "SUBSCRIPTION")
    private lateinit var dataset: String

    @BeforeEach fun reset() {
        // Previous test's campaigns have no live jobs when deleted.
        store.jdbc.update("DELETE FROM ai_capacity_limit")
        store.jdbc.update("DELETE FROM ai_capacity_event")
        store.jdbc.update("DELETE FROM ai_capacity_phase")
        store.jdbc.update("DELETE FROM ai_capacity_checkpoint")
        store.jdbc.update("DELETE FROM ai_capacity_run")
        store.jdbc.update("DELETE FROM ai_capacity_campaign")
        fake.reset()
        settings.updateMethod(AiResearchMethod.PIPELINE, "test")
        settings.update(AiRole.AGENT, AiExecution("original", "unchanged", "API"), "test")
        dataset = service.importDataset("test", listOf(CapacityQuestion("Wat weet je over Kapelstraat?"), CapacityQuestion("Wie woonde er aan de Kerklaan?")), "test")
        store.jdbc.update("""INSERT INTO collection_item(collection,ident,title,detail_url,search_text,document_text)
            VALUES ('beeldbank','capacity-test','Kapelstraat','https://example.org/test','Kapelstraat','Een historische straat.') ON CONFLICT DO NOTHING""")
    }

    private fun campaign(provider: String = "openai", max: Int = 2, parallel: Int = 1, repeat: Boolean = false): String = service.create(
        "test $provider", dataset, execution(provider), parallel, max, 24, repeat, "same-account", "test-copy", null, "admin")
    private fun status(id: String) = store.jdbc.queryForObject("SELECT status FROM ai_capacity_campaign WHERE id=?::uuid", String::class.java, id)
    private fun waitFor(seconds: Int = 20, predicate: () -> Boolean) {
        val deadline = System.currentTimeMillis() + seconds * 1000L
        while (System.currentTimeMillis() < deadline) { scheduler.tick(); if (predicate()) return; Thread.sleep(75) }
        fail("Timed out; campaigns=${service.campaigns()}, phases=${store.rows("SELECT phase_key,status,error_message FROM ai_capacity_phase")}")
    }

    @Test fun `complete pipeline scenarios use the selected model in every phase and count once`() {
        val id = campaign(parallel = 2)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(mapOf("SUCCEEDED" to 2L), service.counts(id))
        val requests = fake.jobs.values.toList()
        assertTrue(requests.size >= 4)
        assertTrue(requests.all { it.path("execution").path("model").asText() == "openai-test" })
        assertTrue(requests.any { it.path("idempotencyKey").asText().contains("-direct-") })
        assertTrue(requests.any { it.path("idempotencyKey").asText().contains("-plan-") })
        assertEquals("original", settings.execution().vendorId)
        assertEquals(0, turns.activeTurnCount())
        assertEquals(0, store.jdbc.queryForObject("SELECT count(*) FROM request_log WHERE reference IN (SELECT turn_id::text FROM ai_capacity_run)", Int::class.java))
        val details = service.detail(id)
        assertEquals(2, (details["runs"] as List<*>).size)
        assertTrue(store.rows("SELECT usage FROM ai_capacity_phase").all { store.node(it,"usage").path("metrics").size() == 4 })
    }

    @Test fun `follow up and expansion retain the override and together count as one scenario`() {
        fake.expandAvailable = true
        val id = service.create("vervolg", dataset, execution(),1,1,24,false,"account","test",null,"test", true,"Wat gebeurde er in de Kerklaan?")
        waitFor { status(id) == "COMPLETED" }
        assertEquals(mapOf("SUCCEEDED" to 1L),service.counts(id))
        assertEquals(3,store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_turn WHERE campaign_id=?::uuid",Int::class.java,id))
        assertTrue(fake.jobs.values.any { it.path("idempotencyKey").asText().contains("-expand-") })
        assertTrue(fake.jobs.values.all { it.path("execution").path("model").asText()=="openai-test" })
        assertEquals(1,store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_run WHERE campaign_id=?::uuid",Int::class.java,id))
    }

    @Test fun `stored scenario answers have an admin only result route without exposing control tokens`() {
        val id = campaign(max=1)
        waitFor { status(id) == "COMPLETED" }
        val run = store.jdbc.queryForObject("SELECT id::text FROM ai_capacity_run WHERE campaign_id=?::uuid",String::class.java,id)!!
        val jobs = fake.jobs.size
        val path = "/api/admin/ai-search/capacity/campaigns/$id/runs/$run/result"
        mvc.get(path).andExpect { status { isServiceUnavailable() } }
        val response = mvc.get(path) { header(admin.first,admin.second) }.andExpect {
            status { isOk() }
            header { string("Cache-Control","no-store") }
            jsonPath("$.run.id") { value(run) }
            jsonPath("$.turns[0].status") { value("SUCCEEDED") }
            jsonPath("$.turns[0].answerHtml") { value("<p>Testantwoord</p>") }
            jsonPath("$.turns[0].controlToken") { doesNotExist() }
            jsonPath("$.turns[0].runtimeJobId") { doesNotExist() }
        }.andReturn().response.contentAsString
        assertFalse(response.contains("control_token"))
        assertEquals(jobs,fake.jobs.size)
        mvc.get("/api/admin/ai-search/capacity/campaigns/${UUID.randomUUID()}/runs/$run/result") { header(admin.first,admin.second) }.andExpect { status { isNotFound() } }
    }

    @Test fun `database serializes provider starts while other providers run independently`() {
        fake.hold = true
        val executor = Executors.newVirtualThreadPerTaskExecutor()
        val attempts = (1..8).map { executor.submit<Boolean> { runCatching { campaign() }.isSuccess } }.map { it.get() }
        executor.shutdown()
        assertEquals(1, attempts.count { it })
        val other = campaign("anthropic")
        waitFor { fake.jobs.values.any { it.path("execution").path("vendorId").asText() == "openai" } && fake.jobs.values.any { it.path("execution").path("vendorId").asText() == "anthropic" } }
        assertFails { service.create("same provider other model", dataset, execution().copy(model="another"),1,2,24,false,"other-account","test",null,"test") }
        fake.hold = false
        waitFor { status(other) == "COMPLETED" && service.campaigns().all { it["status"] == "COMPLETED" } }
    }

    @Test fun `short limit pauses dispatch and resumes the same scenario with saved successful phases`() {
        fake.limitKind = "SHORT_WINDOW"
        fake.limitStep = "write"
        val id = campaign(max = 1)
        waitFor { status(id) == "WAITING_LIMIT" }
        assertFails { campaign() }
        val count = fake.jobs.size
        Thread.sleep(150)
        scheduler.tick()
        assertEquals(count, fake.jobs.size)
        fake.limitKind = null
        store.jdbc.update("UPDATE ai_capacity_campaign SET next_dispatch_at=now()-interval '1 second' WHERE id=?::uuid", id)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(mapOf("SUCCEEDED" to 1L), service.counts(id))
        assertEquals(1, fake.jobs.values.count { it.path("idempotencyKey").asText().contains("-direct-") })
        assertEquals(2, fake.jobs.values.count { it.path("idempotencyKey").asText().contains("-write-") })
        assertEquals(1, store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_limit", Int::class.java))
    }

    @Test fun `pausing during provider cooldown releases the provider without probing before reset`() {
        fake.limitKind = "SHORT_WINDOW"
        val id = campaign(max=1)
        waitFor { status(id) == "WAITING_LIMIT" }
        service.control(id,"pause")
        waitFor { status(id) == "PAUSED" }
        val before = fake.jobs.size
        service.control(id,"resume")
        assertEquals("WAITING_LIMIT",status(id))
        scheduler.tick(); Thread.sleep(150)
        assertEquals(before,fake.jobs.size)
        fake.limitKind=null
        store.jdbc.update("UPDATE ai_capacity_campaign SET next_dispatch_at=now()-interval '1 second' WHERE id=?::uuid",id)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(1L,service.counts(id)["SUCCEEDED"])
    }

    @Test fun `exhaustion and deliberate repeats stay distinct from a provider limit`() {
        val once = campaign(max=3)
        waitFor { status(once) == "COMPLETED" }
        assertEquals(2L,service.counts(once)["SUCCEEDED"])
        assertTrue(service.detail(once).toString().contains("Vragenlijst uitgeput"))
        val repeat = campaign(max=3,repeat=true)
        waitFor { status(repeat) == "COMPLETED" }
        assertEquals(3L,service.counts(repeat)["SUCCEEDED"])
        assertEquals(0,store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_limit",Int::class.java))
    }

    @Test fun `a foreign live lease prevents dispatch and expiry permits takeover`() {
        val id = campaign(max=1)
        store.jdbc.update("UPDATE ai_capacity_campaign SET lease_owner='other-instance',lease_until=now()+interval '90 seconds' WHERE id=?::uuid",id)
        scheduler.tick(); Thread.sleep(150)
        assertEquals(0,fake.jobs.size)
        store.jdbc.update("UPDATE ai_capacity_campaign SET lease_until=now()-interval '1 second' WHERE id=?::uuid",id)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(1L,service.counts(id)["SUCCEEDED"])
    }

    @Test fun `weekly and monthly evidence stops campaigns and retains failed usage`() {
        for (kind in listOf("WEEK", "MONTH")) {
            fake.limitKind = kind
            fake.limitStep = "write"
            val id = campaign(max = 1)
            waitFor { status(id) == "LIMIT_REACHED" }
            assertEquals(1, store.jdbc.queryForObject("SELECT count(*) FROM ai_capacity_run WHERE campaign_id=?::uuid", Int::class.java, id))
            assertTrue(service.detail(id).toString().contains(kind))
            assertTrue(store.rows("SELECT usage FROM ai_capacity_phase WHERE status='FAILED'").all { !store.node(it,"usage").isNull })
        }
    }

    @Test fun `unknown limits remain unknown and ordinary schema failures do not trigger quota retries`() {
        fake.limitKind = "UNKNOWN"
        val id = campaign(max = 1)
        waitFor { status(id) == "WAITING_LIMIT" }
        assertTrue(service.detail(id).toString().contains("UNKNOWN"))
        service.control(id, "stop")
        waitFor { status(id) == "STOPPED" }
        fake.limitKind = null
        fake.failure = "RESULT_SCHEMA_INVALID"
        val schema = campaign(max = 1)
        waitFor { status(schema) == "COMPLETED" }
        assertEquals(mapOf("FAILED" to 1L), service.counts(schema))
        assertTrue(service.detail(schema).toString().contains("RESULT_SCHEMA_INVALID"))
    }

    @Test fun `pause drains existing scenarios and releases provider only after runtime completes`() {
        fake.hold = true
        val id = campaign()
        waitFor { fake.jobs.isNotEmpty() }
        service.control(id, "pause")
        assertFails { campaign() }
        fake.hold = false
        waitFor { status(id) == "PAUSED" }
        assertEquals(1L, service.counts(id)["SUCCEEDED"])
        val other = campaign(max=1)
        assertFails { service.control(id,"resume") }
        waitFor { status(other) == "COMPLETED" }
        service.control(id,"resume")
        waitFor { status(id) == "COMPLETED" }
        assertEquals(2L, service.counts(id)["SUCCEEDED"])
    }

    @Test fun `stop cancels runtime jobs before releasing provider and cannot be undone by late completion`() {
        fake.hold = true
        val id = campaign(parallel = 2)
        waitFor { fake.jobs.size == 2 }
        service.control(id, "stop")
        waitFor { status(id) == "STOPPED" }
        assertEquals(2, fake.cancelled.size)
        assertEquals(mapOf("CANCELLED" to 2L), service.counts(id))
        assertTrue(fake.jobs.keys.all { it in fake.cancelled })
    }

    @Test fun `backend recovery reuses persisted phase request and successful result`() {
        val id = campaign(max=1)
        fake.hold = true
        waitFor { fake.jobs.size == 1 }
        val phase = store.rows("SELECT * FROM ai_capacity_phase").single()
        val key = phase["phase_key"].toString()
        val original = fake.jobs.values.single()
        // Simulate a process losing the create response; the persisted dispatch body survives.
        store.jdbc.update("UPDATE ai_capacity_phase SET job_id=NULL WHERE phase_key=?", key)
        val recovered = runtime.createJob(key, "this replacement prompt must not be used")
        assertEquals(1, fake.jobs.size)
        assertEquals(original.toString(), fake.jobs[recovered.id].toString())
        val attachedKey = "$key-attachments"
        val attached = runtime.createJob(attachedKey,"Lees de bijlage",attachments=listOf(JobAttachment("bronnen","Vaste brontekst")))
        val exact = fake.jobs[attached.id].toString()
        store.jdbc.update("UPDATE ai_capacity_phase SET job_id=NULL WHERE phase_key=?",attachedKey)
        val again = runtime.createJob(attachedKey,"Andere instructie",attachments=listOf(JobAttachment("anders","Mag niet worden geüpload")))
        assertEquals(attached.id,again.id)
        assertEquals(exact,fake.jobs[again.id].toString())
        val checkpoint = store.checkpoint(phase["turn_id"].toString(), "proof", CapacityQuestion::class.java) { CapacityQuestion("Oorspronkelijke vraag") }
        assertEquals(checkpoint, store.checkpoint(phase["turn_id"].toString(), "proof", CapacityQuestion::class.java) { error("must not recompute") })
        fake.hold = false
        waitFor { status(id) == "COMPLETED" }
        val before = fake.jobs.size
        // Resume the complete pipeline with all database checkpoints and job results.
        val turnId = store.jdbc.queryForObject("SELECT turn_id::text FROM ai_capacity_run WHERE campaign_id=?::uuid", String::class.java, id)!!
        store.jdbc.update("UPDATE ai_search_turn SET status='SUBMITTING',completed_at=NULL WHERE id=?::uuid", turnId)
        store.jdbc.update("UPDATE ai_capacity_run SET status='ACTIVE' WHERE campaign_id=?::uuid", id)
        store.jdbc.update("UPDATE ai_capacity_campaign SET status='RUNNING',holds_provider=true WHERE id=?::uuid", id)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(before, fake.jobs.size)
    }

    @Test fun `admin imports bundled questions and public requests cannot select test models`() {
        mvc.get("/api/admin/ai-search/capacity").andExpect { status { isServiceUnavailable() } }
        mvc.post("/api/admin/ai-search/capacity/datasets/bundled") { header(admin.first,admin.second) }.andExpect { status { isOk() } }
        assertTrue(service.datasets().any { (it["count"] as Number).toInt() == 1000 })
        mvc.post("/api/admin/ai-search/capacity/datasets") { header(admin.first,admin.second); contentType=MediaType.APPLICATION_JSON; content="""{"name":"duplicates","questions":["zelfde vraag","zelfde vraag"]}""" }.andExpect { status { isBadRequest() } }
        settings.updateMethod(AiResearchMethod.AGENT,"test")
        val id = campaign(max=1)
        waitFor { status(id) == "COMPLETED" }
        assertEquals(1, fake.jobs.size)
        assertEquals("openai", fake.jobs.values.single().path("execution").path("vendorId").asText())
        assertEquals("original", settings.execution().vendorId)
        val response = mvc.post("/api/ai-search/sessions") {
            contentType=MediaType.APPLICATION_JSON
            content="""{"question":"Publieke synthetische vraag","execution":{"vendorId":"anthropic","model":"anthropic-test","mode":"SUBSCRIPTION"}}"""
        }.andExpect { status { isAccepted() } }.andReturn().response.contentAsString
        val publicTurn = store.mapper.readTree(response).path("turns")[0].path("id").asText()
        waitFor { turns.findTurn(publicTurn)?.status == AiTurnStatus.SUCCEEDED }
        assertTrue(fake.jobs.values.filter { !it.path("idempotencyKey").asText().startsWith("hkh-capacity-") }
            .all { it.path("execution").path("vendorId").asText()=="original" })
    }

    companion object {
        @Container @ServiceConnection @JvmField val postgres = PostgreSQLContainer("postgres:16-alpine")
        private val fake = FakeRuntime()
        @JvmStatic @DynamicPropertySource fun properties(registry: DynamicPropertyRegistry) {
            registry.add("hkh.preview.enabled") { "true" }
            registry.add("hkh.preview.marker") { "hkh-acceptance" }
            registry.add("HKH_DATABASE_URL") { "jdbc:postgresql://database:5432/hkh" }
            registry.add("hkh.ai-search.enabled") { "true" }
            registry.add("hkh.ai-search.runtime-token") { "synthetic-local-token" }
            registry.add("hkh.ai-search.runtime-base-url") { "http://localhost:${fake.port}" }
            registry.add("hkh.ai-search.poll-interval-ms") { "500" }
            registry.add("hkh.capacity.poll-ms") { "600000" }
        }
    }
}

private class FakeRuntime {
    val mapper = jacksonObjectMapper()
    val jobs = ConcurrentHashMap<String, JsonNode>()
    val cancelled = ConcurrentHashMap.newKeySet<String>()
    private val limits = ConcurrentHashMap<String, String>()
    private val failures = ConcurrentHashMap<String, String>()
    @Volatile var hold = false
    @Volatile var limitKind: String? = null
    @Volatile var limitStep = "direct"
    @Volatile var failure: String? = null
    @Volatile var expandAvailable = false
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1",0),0).apply {
        executor = Executors.newVirtualThreadPerTaskExecutor()
        createContext("/") { exchange ->
            try {
                val path = exchange.requestURI.path
                val suffix = path.substringAfter("/v2/jobs/", "").split('/')
                val id = suffix.first()
                val request = jobs[id]
                val result: Any = when {
                    path == "/v2/uploads" -> mapOf("uploadId" to UUID.randomUUID().toString())
                    path.startsWith("/v2/uploads/") && path.endsWith("/complete") -> mapOf("objectId" to UUID.randomUUID().toString())
                    path.startsWith("/v2/uploads/") -> emptyMap<String,Any>()
                    path == "/v2/execution-options" -> listOf("openai","anthropic").flatMap { provider -> listOf("$provider-test","another").map { model -> mapOf("execution" to mapOf("vendorId" to provider, "model" to model, "mode" to "SUBSCRIPTION"),"available" to true,"matchingOnlineWorkers" to 1) } }
                    path == "/v2/jobs" && exchange.requestMethod == "POST" -> {
                        val body = mapper.readTree(exchange.requestBody)
                        val key = body.path("idempotencyKey").asText()
                        val found = jobs.entries.firstOrNull { it.value.path("idempotencyKey").asText() == key }
                        val jobId = found?.key ?: UUID.randomUUID().toString()
                        if (found != null) require(found.value == body) { "idempotency body changed" }
                        else {
                            jobs[jobId] = body
                            if (key.contains("-$limitStep-") && limitKind != null) limits[jobId] = limitKind!!
                            failure?.let { failures[jobId] = it }
                        }
                        job(jobId)
                    }
                    suffix.last() == "cancel" -> { cancelled += id; job(id) }
                    suffix.last() == "events" -> {
                        val after = exchange.requestURI.query.substringAfter("afterSequence=","0").substringBefore('&').toLong()
                        mapOf("items" to if (limits.containsKey(id) && after == 0L) listOf(mapOf("sequence" to 1,"attemptId" to "attempt-$id","providerLimit" to mapOf("eventId" to "event-$id","kind" to limits[id],"blocked" to true,"observedAt" to Instant.now().toString(),"retryAfterSeconds" to 600,"source" to "PROVIDER_STRUCTURED"))) else emptyList<Any>())
                    }
                    suffix.last() == "usage" -> usage()
                    suffix.last() == "attempts" -> listOf(mapOf("id" to "attempt-$id", "number" to 1,"usageSummary" to usage()))
                    suffix.last() == "result" -> mapOf("result" to result(request!!), "usageSummary" to usage())
                    request != null -> job(id)
                    else -> error("Unexpected endpoint $path")
                }
                val bytes = mapper.writeValueAsBytes(result)
                exchange.responseHeaders.add("Content-Type","application/json")
                exchange.sendResponseHeaders(200,bytes.size.toLong()); exchange.responseBody.use { it.write(bytes) }
            } catch (ex: Exception) {
                val bytes=ex.toString().toByteArray(); exchange.sendResponseHeaders(500,bytes.size.toLong()); exchange.responseBody.use { it.write(bytes) }
            } finally { exchange.close() }
        }
        start()
    }
    val port get() = server.address.port
    fun reset() { jobs.clear(); cancelled.clear(); limits.clear(); failures.clear(); hold=false; limitKind=null; limitStep="direct"; failure=null; expandAvailable=false }
    private fun job(id: String) = mapOf("id" to id,"status" to when { id in cancelled -> "CANCELLED"; limits.containsKey(id) || failures.containsKey(id) -> "FAILED"; hold -> "WAITING_FOR_WORKER"; else -> "SUCCEEDED" },"phase" to "TEST","errorCode" to failures[id],"errorMessage" to if (limits.containsKey(id)) "provider limit" else failures[id])
    private fun usage() = mapOf("attemptCount" to 1,"usageQuality" to "COMPLETE","metrics" to listOf("INPUT_TOKENS","CACHED_INPUT_TOKENS","CACHE_WRITE_TOKENS","OUTPUT_TOKENS").map { mapOf("metric" to it,"quantity" to "100","unit" to "TOKENS") },"costs" to listOf(mapOf("currency" to "USD","amount" to "0.01")))
    private fun result(request: JsonNode): JsonNode {
        val props = request.path("output").path("resultSchema").path("properties")
        return mapper.readTree(when {
            props.has("query") -> """{"conclusionSoFar":"Test","query":{"terms":[],"includeRecords":[],"yearFrom":0,"yearTo":0,"collections":[],"withImage":false,"sortByYear":"none","reason":""}}"""
            props.has("queries") -> """{"queries":[],"conclusionSoFar":""}"""
            else -> """{"title":"Test","answerHtml":"<p>Testantwoord</p>","sources":[1],"suggestedFollowUps":[],"moreAvailable":$expandAvailable,"moreSummary":"Meer"}"""
        })
    }
}
