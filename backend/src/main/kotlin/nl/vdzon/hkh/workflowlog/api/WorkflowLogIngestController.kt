package nl.vdzon.hkh.workflowlog.api

import jakarta.servlet.http.HttpServletRequest
import java.security.MessageDigest
import java.util.UUID
import nl.vdzon.hkh.requestlog.RequestLogService
import nl.vdzon.hkh.workflowlog.IngestLimits
import nl.vdzon.hkh.workflowlog.IngestRateLimiter
import nl.vdzon.hkh.workflowlog.WorkflowKind
import nl.vdzon.hkh.workflowlog.WorkflowLogSanitizer
import nl.vdzon.hkh.workflowlog.WorkflowLogService
import nl.vdzon.hkh.workflowlog.WorkflowLoginReport
import nl.vdzon.hkh.workflowlog.WorkflowSessionForbidden
import nl.vdzon.hkh.workflowlog.WorkflowSessionReport
import nl.vdzon.hkh.workflowlog.WorkflowStatus
import java.util.concurrent.atomic.AtomicLong
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper

/**
 * Het open meldpunt van de workflow-app. Er is geen inlog; wel een vaste sleutel in de kop (die bewust in de
 * broncode staat: de gegevens zijn niet gevoelig en de sleutel houdt alleen toevallig verkeer tegen), limieten per
 * adres, per sessie en voor alles samen, een maximale berichtgrootte en een sessiegeheim per sessie.
 */
@RestController
@RequestMapping("/api/workflow-log")
class WorkflowLogIngestController(
    private val service: WorkflowLogService,
    private val limiter: IngestRateLimiter,
    private val objectMapper: ObjectMapper,
    /** Hoeveel adressen aan het eind van X-Forwarded-For door onze eigen proxies zijn toegevoegd (de nginx van het beheerscherm voegt er één toe). */
    @param:Value("\${hkh.workflow-log.forwarded-hops:1}") private val forwardedHops: Int,
) {
    private val sanitizer = WorkflowLogSanitizer(objectMapper)
    private val cachedSessionCount = AtomicLong(0)
    private val countedAtMillis = AtomicLong(0)

    @PostMapping("/logins")
    fun login(@RequestHeader(INGEST_KEY_HEADER, required = false) key: String?, request: HttpServletRequest): ResponseEntity<Map<String, String>> {
        val ip = rateKey(request, forwardedHops)
        if (!limiter.tryAcquire("global", IngestLimits.GLOBAL_PER_MINUTE, IngestLimits.GLOBAL_PER_MINUTE.toDouble()) ||
            !limiter.tryAcquire("ip:$ip", IngestLimits.IP_PER_MINUTE, IngestLimits.IP_PER_MINUTE.toDouble()) ||
            !limiter.tryAcquire("login:$ip", IngestLimits.LOGINS_PER_IP_PER_MINUTE, IngestLimits.LOGINS_PER_IP_PER_MINUTE.toDouble())
        ) return tooMany()
        if (!keyMatches(key)) return reject(HttpStatus.UNAUTHORIZED, "Sleutel ontbreekt of klopt niet")
        val root = readJson(request) ?: return reject(HttpStatus.BAD_REQUEST, "Geen geldig bericht (of te groot)")
        val success = root.get("success")?.takeIf { it.isBoolean }?.booleanValue() ?: return reject(HttpStatus.BAD_REQUEST, "success ontbreekt")
        val method = text(root, "method", 20)?.uppercase()?.takeIf { it in setOf("PASSWORD", "COOKIE") }
            ?: return reject(HttpStatus.BAD_REQUEST, "method moet PASSWORD of COOKIE zijn")
        service.recordLogin(
            WorkflowLoginReport(text(root, "user", 200), success, method, text(root, "detail", 300), text(root, "appVersion", 80), text(root, "computer", 120)),
            RequestLogService.clientAddress(request),
        )
        return ResponseEntity.noContent().build()
    }

    @PutMapping("/sessions/{id}")
    fun session(
        @PathVariable id: String,
        @RequestHeader(INGEST_KEY_HEADER, required = false) key: String?,
        request: HttpServletRequest,
    ): ResponseEntity<Map<String, String>> {
        val ip = rateKey(request, forwardedHops)
        if (!limiter.tryAcquire("global", IngestLimits.GLOBAL_PER_MINUTE, IngestLimits.GLOBAL_PER_MINUTE.toDouble()) ||
            !limiter.tryAcquire("ip:$ip", IngestLimits.IP_PER_MINUTE, IngestLimits.IP_PER_MINUTE.toDouble())
        ) return tooMany()
        if (!keyMatches(key)) return reject(HttpStatus.UNAUTHORIZED, "Sleutel ontbreekt of klopt niet")
        val sessionId = runCatching { UUID.fromString(id) }.getOrNull()?.takeIf { it.toString() == id.lowercase() }
            ?: return reject(HttpStatus.BAD_REQUEST, "De sessie-id moet een uuid zijn")
        if (!limiter.tryAcquire("session:$sessionId", IngestLimits.SESSION_PER_MINUTE, IngestLimits.SESSION_PER_MINUTE.toDouble())) return tooMany()
        if (!service.sessionExists(sessionId)) {
            if (!limiter.tryAcquire("new:$ip", IngestLimits.NEW_SESSIONS_PER_IP_PER_HOUR, IngestLimits.NEW_SESSIONS_PER_IP_PER_HOUR / 60.0) ||
                !limiter.tryAcquire("new:all", IngestLimits.GLOBAL_NEW_SESSIONS_PER_HOUR, IngestLimits.GLOBAL_NEW_SESSIONS_PER_HOUR / 60.0)
            ) return tooMany()
            if (sessionCount() >= IngestLimits.MAX_SESSIONS) return reject(HttpStatus.INSUFFICIENT_STORAGE, "Het logboek zit vol")
        }

        val root = readJson(request) ?: return reject(HttpStatus.BAD_REQUEST, "Geen geldig bericht (of te groot)")
        val kind = WorkflowKind.entries.firstOrNull { it.name == root.path("kind").asString("") } ?: return reject(HttpStatus.BAD_REQUEST, "kind klopt niet")
        val status = WorkflowStatus.entries.firstOrNull { it.name == root.path("status").asString("") } ?: return reject(HttpStatus.BAD_REQUEST, "status klopt niet")
        val secret = text(root, "secret", 100)?.takeIf { it.length >= 16 } ?: return reject(HttpStatus.BAD_REQUEST, "secret ontbreekt of is te kort")
        val report = WorkflowSessionReport(
            id = sessionId, kind = kind, secret = secret,
            user = text(root, "user", 200), collection = text(root, "collection", 80),
            appVersion = text(root, "appVersion", 80), computer = text(root, "computer", 120),
            phase = number(root, "phase", 99), phaseCount = number(root, "phaseCount", 99), phaseLabel = text(root, "phaseLabel", 120),
            status = status, fileCount = number(root, "fileCount", 1_000_000), event = text(root, "event", 500),
            snapshot = null,
        )
        val snapshot = root.get("snapshot")?.takeIf { !it.isNull }?.let(sanitizer::clean)
        return try {
            service.record(report, snapshot, RequestLogService.clientAddress(request))
            ResponseEntity.noContent().build()
        } catch (_: WorkflowSessionForbidden) {
            reject(HttpStatus.FORBIDDEN, "Sessiegeheim klopt niet")
        }
    }

    private fun text(root: JsonNode, name: String, max: Int): String? = root.get(name)?.takeIf { it.isString }?.let { sanitizer.text(it.stringValue(), max) }

    private fun number(root: JsonNode, name: String, max: Int): Int = (root.get(name)?.takeIf { it.isNumber }?.intValue() ?: 0).coerceIn(0, max)

    /** De hele body, of null als hij te groot is of geen JSON. */
    private fun readJson(request: HttpServletRequest): JsonNode? {
        if (request.contentLengthLong > IngestLimits.MAX_BODY_BYTES) return null
        val bytes = request.inputStream.readNBytes(IngestLimits.MAX_BODY_BYTES + 1)
        if (bytes.isEmpty() || bytes.size > IngestLimits.MAX_BODY_BYTES) return null
        return runCatching { objectMapper.readTree(bytes) }.getOrNull()?.takeIf { it.isObject }
    }

    /** Het aantal sessies, hooguit eens per minuut opnieuw geteld. */
    private fun sessionCount(): Long {
        val now = System.currentTimeMillis()
        if (now - countedAtMillis.get() > 60_000) {
            cachedSessionCount.set(service.sessionCount())
            countedAtMillis.set(now)
        }
        return cachedSessionCount.get()
    }

    private fun keyMatches(key: String?): Boolean =
        key != null && MessageDigest.isEqual(key.toByteArray(), INGEST_KEY.toByteArray())

    private fun reject(status: HttpStatus, message: String) = ResponseEntity.status(status).body(mapOf("error" to message))

    private fun tooMany(): ResponseEntity<Map<String, String>> =
        ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).header("Retry-After", "60").body(mapOf("error" to "Te veel meldingen, probeer het over een minuut opnieuw"))

    companion object {
        const val INGEST_KEY_HEADER = "X-HKH-Workflow-Key"

        /** Bewust vast en openbaar in de broncode; zie de uitleg bij de klasse. */
        const val INGEST_KEY = "hkh-workflow-logboek-3f9c2a7e51b84d06"

        /**
         * Sleutel voor de limieten: het adres in X-Forwarded-For dat onze eigen router heeft toegevoegd, geteld vanaf het eind
         * ([hops] adressen zijn daarna door onze eigen proxies toegevoegd). Alles links daarvan kan een afzender zelf verzinnen,
         * net als CF-Connecting-IP, en daarmee zou de limiet te omzeilen zijn. Zonder bruikbare kop geldt het adres van de verbinding.
         */
        fun rateKey(request: HttpServletRequest, hops: Int): String {
            val chain = request.getHeader("X-Forwarded-For")?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }.orEmpty()
            return chain.getOrNull(chain.size - 1 - hops.coerceAtLeast(0)) ?: request.remoteAddr
        }
    }
}
