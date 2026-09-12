package nl.vdzon.hkh

import kotlin.test.assertEquals
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.health.actuate.endpoint.HealthEndpoint
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.jdbc.core.JdbcTemplate
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.postgresql.PostgreSQLContainer

@Testcontainers
@SpringBootTest
class DatabaseIntegrationTest(
    @param:Autowired private val jdbcTemplate: JdbcTemplate,
    @param:Autowired private val healthEndpoint: HealthEndpoint,
) {
    @Test
    fun `application starts against PostgreSQL and Flyway applies the baseline`() {
        val metadata = jdbcTemplate.queryForObject(
            "SELECT metadata_value FROM application_metadata WHERE metadata_key = ?",
            String::class.java,
            "schema-purpose",
        )
        val successfulMigrations = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM flyway_schema_history WHERE success",
            Long::class.java,
        )

        assertEquals("HKH technical baseline", metadata)
        assertEquals(9L, successfulMigrations)
        assertEquals(
            0L,
            jdbcTemplate.queryForObject("SELECT COUNT(*) FROM latest_news", Long::class.java),
        )
        assertEquals("UP", healthEndpoint.health().status.code)
    }

    companion object {
        @Container
        @ServiceConnection
        @JvmField
        val postgres = PostgreSQLContainer("postgres:16-alpine")
    }
}
