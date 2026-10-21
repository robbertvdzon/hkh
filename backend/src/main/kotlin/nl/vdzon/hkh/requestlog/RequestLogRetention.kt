package nl.vdzon.hkh.requestlog

import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Configuration
@EnableScheduling
class RequestLogScheduling

/** Nachtelijk: IP-adressen ouder dan 30 dagen afkappen en de bezoekerssleutel van die regels verwijderen. */
@Component
class RequestLogRetention(private val log: RequestLogService) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 30 3 * * *", zone = "Europe/Amsterdam")
    fun anonymize() {
        val count = runCatching { log.anonymizeOld() }.onFailure { logger.warn("Afkappen van IP-adressen mislukt", it) }.getOrDefault(0)
        if (count > 0) logger.info("{} logboekregels anoniem gemaakt (ouder dan {} dagen)", count, RequestLogService.RETENTION_DAYS)
    }
}
