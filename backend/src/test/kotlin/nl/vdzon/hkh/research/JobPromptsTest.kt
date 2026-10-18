package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class JobPromptsTest {
    @Test
    fun `small input stays inline`() {
        val (instruction, attachments) = JobPrompts.assemble("Regels", "Records:\n=== record 1 ===\ntekst", "records")
        assertTrue(attachments.isEmpty())
        assertTrue(instruction.startsWith("Regels\n\nRecords:"))
    }

    @Test
    fun `large input becomes numbered files within the runtime limits`() {
        val longLine = (1..2_000).joinToString(" ") { "woord$it" }
        val bulk = (1..40).joinToString("\n") { "=== record ident=$it ===\n$longLine" }
        val (instruction, attachments) = JobPrompts.assemble("Regels voor de kaarten", bulk, "records", "records")

        assertTrue(instruction.length < JobPrompts.INLINE_LIMIT)
        assertTrue(attachments.size >= 2, "verwacht meerdere bestanden, kreeg ${attachments.size}")
        assertEquals("records-1", attachments.first().name)
        assertEquals("/job/input/objects/records-1/content", attachments.first().path)
        assertTrue(instruction.contains("in ${attachments.size} bestand(en): /job/input/objects/records-1/content"))
        assertTrue(instruction.contains("Lees ieder bestand volledig"))
        for (attachment in attachments) {
            assertTrue(attachment.text.length <= JobPrompts.CHUNK_CHARS, "bestand te groot: ${attachment.text.length}")
            assertTrue(attachment.text.lines().all { it.length <= JobPrompts.LINE_CHARS }, "regel te lang")
        }
        // Niets gaat verloren: alle records en alle woorden staan in de bestanden.
        val joined = attachments.joinToString("\n") { it.text }
        for (ident in 1..40) assertTrue(joined.contains("=== record ident=$ident ==="))
        assertEquals(bulk.replace(Regex("\\s+"), " "), joined.replace(Regex("\\s+"), " "))
    }
}
