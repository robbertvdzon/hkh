package nl.vdzon.hkh.workflowlog

import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

/** Nachtelijk: app-logregels ouder dan de bewaartermijn verwijderen (de planner staat aan via `RequestLogScheduling`). */
@Component
class WorkflowAppLogRetention(private val service: WorkflowAppLogService) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 45 3 * * *", zone = "Europe/Amsterdam")
    fun cleanUp() {
        val count = runCatching { service.deleteExpired() }.onFailure { logger.warn("Opruimen van het app-log mislukt", it) }.getOrDefault(0)
        if (count > 0) logger.info("{} app-logregels verwijderd (ouder dan de bewaartermijn)", count)
    }
}
