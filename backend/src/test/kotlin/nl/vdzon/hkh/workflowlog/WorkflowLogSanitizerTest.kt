package nl.vdzon.hkh.workflowlog

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import tools.jackson.databind.json.JsonMapper

class WorkflowLogSanitizerTest {
    private val mapper = JsonMapper.builder().build()
    private val sanitizer = WorkflowLogSanitizer(mapper)

    @Test
    fun `velden die op een geheim lijken worden vervangen, ook diep in de structuur`() {
        val input = mapper.readTree(
            """{"settings":{"ftpHost":"h","ftpPassword":"geheim","adminPassword":"x","ingestKey":"k","sourceFolders":"a=b"},
               "stappen":[{"naam":"x","token":"t"}],"leeg":{"wachtwoord":null}}""",
        )
        val out = sanitizer.clean(input)
        assertEquals("h", out.path("settings").path("ftpHost").asString())
        assertEquals("a=b", out.path("settings").path("sourceFolders").asString())
        assertEquals(WorkflowLogSanitizer.REDACTED, out.path("settings").path("ftpPassword").asString())
        assertEquals(WorkflowLogSanitizer.REDACTED, out.path("settings").path("adminPassword").asString())
        assertEquals(WorkflowLogSanitizer.REDACTED, out.path("settings").path("ingestKey").asString())
        assertEquals(WorkflowLogSanitizer.REDACTED, out.path("stappen").path(0).path("token").asString())
        assertTrue(out.path("leeg").path("wachtwoord").isNull)
        assertFalse(out.toString().contains("geheim"))
    }

    @Test
    fun `NUL-tekens verdwijnen en alleen een object is een geldige momentopname`() {
        assertEquals("ab", sanitizer.clean(mapper.readTree("""{"t":"a\u0000b"}""")).path("t").asString())
        assertEquals("ab", sanitizer.text(" a\u0000b ", 10))
        assertEquals("ab", sanitizer.text("abcdef", 2))
        assertNull(sanitizer.text("   ", 10))
        assertTrue(sanitizer.clean(mapper.readTree("[1,2]")).isEmpty)
        assertTrue(sanitizer.clean(null).isObject)
    }

    @Test
    fun `te diepe structuren worden afgekapt`() {
        var json = "1"
        repeat(40) { json = """{"a":$json}""" }
        assertTrue(sanitizer.clean(mapper.readTree(json)).toString().contains("te diep"))
    }
}
