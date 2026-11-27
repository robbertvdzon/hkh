package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import org.junit.jupiter.api.Test

class JobActivityReaderTest {
    private fun block(type: String, extra: String = "") = """{"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"$type"$extra}},"session_id":"s"}""" + "\n"

    @Test
    fun `thinking, a search and writing the result are told apart`() {
        val reader = JobActivityReader()
        assertEquals(JobActivity.THINKING, reader.read(block("thinking", ""","thinking":"","signature":""""")))
        assertEquals(null, reader.read("""{"type":"system","subtype":"thinking_tokens","estimated_tokens":300}""" + "\n"), "geen nieuw blok, geen verandering")
        assertEquals(JobActivity.USING_TOOL, reader.read(block("tool_use", ""","id":"toolu_01","name":"Bash","input":{}""")))
        assertEquals(JobActivity.THINKING, reader.read(block("thinking")))
        assertEquals(JobActivity.WRITING, reader.read(block("tool_use", ""","id":"toolu_02","name":"StructuredOutput","input":{}""")))
    }

    @Test
    fun `a block split over two pieces of log text is still recognised, and only the last change in a piece counts`() {
        val reader = JobActivityReader()
        val line = block("tool_use", ""","id":"toolu_02","name":"StructuredOutput","input":{}""")
        val cut = line.indexOf("\"content_block\"") + 20
        assertEquals(null, reader.read(line.substring(0, cut)))
        assertEquals(JobActivity.WRITING, reader.read(line.substring(cut)))

        val other = JobActivityReader()
        assertEquals(JobActivity.WRITING, other.read(block("thinking") + block("tool_use", ""","id":"t","name":"Bash"""") + block("text")))
    }
}
