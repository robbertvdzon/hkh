package nl.vdzon.hkh.system.api

import kotlin.test.assertEquals
import org.junit.jupiter.api.Test

class VersionControllerTest {
    @Test
    fun `returns application version and commit`() {
        val response = VersionController("hkh", "1.2.3", "abc123").version()

        assertEquals(VersionResponse("hkh", "1.2.3", "abc123"), response)
    }
}
