package nl.vdzon.hkh.previewdata

import java.time.Instant
import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.news.PreviewLatestNewsSeed
import nl.vdzon.hkh.news.PreviewLatestNewsSeedStore
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Component
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

data class PreviewSeedResult(
    val applied: List<String>,
    val alreadyPresent: List<String>,
)

@Service
class PreviewDataSeeder(
    private val jdbcTemplate: JdbcTemplate,
    private val latestNewsSeedStore: PreviewLatestNewsSeedStore,
    private val preview: PreviewRuntimeConfig,
) {
    @Transactional
    fun ensure(): PreviewSeedResult {
        val prNumber = preview.requireSeedingAllowed()
        jdbcTemplate.execute("SELECT pg_advisory_xact_lock(2026080701)")

        val alreadyApplied = jdbcTemplate.queryForObject(
            "SELECT EXISTS(SELECT 1 FROM preview_seed_history WHERE seed_key = ?)",
            Boolean::class.java,
            NEWS_SEED_KEY,
        ) == true
        if (alreadyApplied) return PreviewSeedResult(emptyList(), listOf(NEWS_SEED_KEY))

        latestNewsSeedStore.upsert(latestNews)
        jdbcTemplate.update(
            "INSERT INTO preview_seed_history (seed_key, applied_at, pr_number) VALUES (?, ?, ?)",
            NEWS_SEED_KEY,
            java.sql.Timestamp.from(Instant.now()),
            prNumber,
        )
        return PreviewSeedResult(listOf(NEWS_SEED_KEY), emptyList())
    }

    private companion object {
        const val NEWS_SEED_KEY = "latest-news-v1"
        val latestNews = listOf(
            PreviewLatestNewsSeed(
                id = -1,
                title = "Nieuwe foto's van de Kerkweg beschreven",
                message = "Vrijwilligers hebben een serie foto's uit 1926 voorzien van namen, huisnummers en bronverwijzingen.",
                publishedAt = Instant.parse("2026-07-28T09:00:00Z"),
                createdAt = Instant.parse("2026-07-28T08:30:00Z"),
                createdBy = "preview-data@hkh.invalid",
            ),
            PreviewLatestNewsSeed(
                id = -2,
                title = "Oproep: herinneringen aan de kermis",
                message = "Welke attracties, muziek en ontmoetingen uit de jaren tachtig zijn u bijgebleven? Deel uw herinnering met de historische kring.",
                publishedAt = Instant.parse("2026-07-21T18:30:00Z"),
                createdAt = Instant.parse("2026-07-21T18:00:00Z"),
                createdBy = "preview-data@hkh.invalid",
            ),
            PreviewLatestNewsSeed(
                id = -3,
                title = "Lezing over Slot Assumburg",
                message = "Op donderdagavond vertelt een onderzoeker hoe bewoners, landschap en het kasteel door de eeuwen heen met elkaar verbonden waren.",
                publishedAt = Instant.parse("2026-07-14T17:00:00Z"),
                createdAt = Instant.parse("2026-07-14T16:15:00Z"),
                createdBy = "preview-data@hkh.invalid",
            ),
            PreviewLatestNewsSeed(
                id = -4,
                title = "Vier decennia HKH-magazine doorzoekbaar",
                message = "De eerste proefselectie bevat artikelen met auteurs, onderwerpen en plaatsen, zodat verbanden tussen verhalen zichtbaar worden.",
                publishedAt = Instant.parse("2026-07-07T10:00:00Z"),
                createdAt = Instant.parse("2026-07-07T09:45:00Z"),
                createdBy = "preview-data@hkh.invalid",
            ),
            PreviewLatestNewsSeed(
                id = -5,
                title = "Wandeling langs verdwenen winkels",
                message = "Vergelijk tijdens de wandeling oude gevelbeelden met de huidige straat en ontdek waarom sommige panden ingrijpend veranderden.",
                publishedAt = Instant.parse("2026-06-30T12:00:00Z"),
                createdAt = Instant.parse("2026-06-30T11:30:00Z"),
                createdBy = "preview-data@hkh.invalid",
            ),
        )
    }
}

@Component
@ConditionalOnProperty(prefix = "hkh.preview", name = ["enabled"], havingValue = "true")
class PreviewDataStartup(private val seeder: PreviewDataSeeder) : ApplicationRunner {
    override fun run(args: ApplicationArguments) {
        seeder.ensure()
    }
}
