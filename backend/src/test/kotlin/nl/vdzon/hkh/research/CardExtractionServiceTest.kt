package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test
import tools.jackson.databind.ObjectMapper

class CardExtractionServiceTest {
    private val mapper = ObjectMapper()

    private class InMemoryCards : DocumentCardStore {
        val saved = mutableMapOf<String, DocumentCard>()
        val errors = mutableMapOf<String, String>()
        var pendingRecords = listOf<PendingCardRecord>()
        override fun pending(collection: String, version: String, includeFailed: Boolean, limit: Int) = pendingRecords.take(limit)
        override fun pendingCount(version: String, includeFailed: Boolean, collection: String?) = pendingRecords.size.toLong()
        override fun save(card: DocumentCard) { saved[card.ident] = card; errors.remove(card.ident) }
        override fun saveError(collection: String, ident: String, version: String, model: String?, sourceHash: String, error: String) { errors[ident] = error }
        override fun find(collection: String, ident: String) = saved[ident]
        override fun stats(version: String) = CardStats(saved.size.toLong(), errors.size.toLong(), 0, 0)
    }

    private fun record(ident: String, text: String? = null, fields: Map<String, String> = emptyMap()) = PendingCardRecord(
        collection = "archief", ident = ident, title = "Testament", description = "Notaris Bremmers te Heemskerk",
        year = 1949, fields = fields, documentText = text, hasImage = false, sourceHash = "hash-$ident",
    )

    @Test
    fun `cards from the model are merged with field keywords and stored per record`() {
        val store = InMemoryCards()
        val requests = mutableListOf<StructuredJobRequest>()
        val runner = StructuredJobRunner { request ->
            requests += request
            StructuredJobOutcome("job-1", mapper.readTree("""{"cards":[
                {"ident":"10983","summary":"Antonius Dijkman, veehouder aan de Gerrit van Assendelftstraat 27, verklaart in 1949 bij notaris Bremmers de nalatenschap.",
                 "keywords":[{"type":"PERSON","literal":"ANTONIUS DIJKMAN","normalized":"Antonius Dijkman","yearFrom":0,"yearTo":0},
                             {"type":"ADDRESS","literal":"Gerrit van Assendelftstraat 27","normalized":"Gerrit van Assendelftstraat 27","yearFrom":0,"yearTo":0},
                             {"type":"YEAR","literal":"24 december 1949","normalized":"1949","yearFrom":1949,"yearTo":1949},
                             {"type":"PERSON","literal":"x","normalized":"","yearFrom":0,"yearTo":0}]}
            ]}"""), 1200, 300, "anthropic/claude-haiku-4-5")
        }
        val service = CardExtractionService(store, runner, mapper)
        val batch = listOf(record("10983", "De ondergeteekende ANTONIUS DIJKMAN...", mapOf("Straatnaam?" to "Gerit van Assendelftstraat")), record("11000"))

        val outcome = service.extract(batch, "test-batch")

        assertEquals(1, outcome.cards)
        assertEquals(1, outcome.failed)
        assertEquals("job-1", outcome.jobId)
        assertEquals(AiRole.EXTRACTION, requests.single().role)
        assertTrue(requests.single().instruction.contains("record ident=10983"))
        assertTrue(requests.single().instruction.contains("record ident=11000"))
        val card = assertNotNull(store.saved["10983"])
        assertEquals(CARD_EXTRACTION_VERSION, card.extractionVersion)
        assertEquals("anthropic/claude-haiku-4-5", card.model)
        val normalized = card.keywords.map { it.type to it.normalized }.toSet()
        assertTrue((KeywordType.PERSON to "Antonius Dijkman") in normalized)
        assertTrue((KeywordType.ADDRESS to "Gerrit van Assendelftstraat 27") in normalized)
        assertTrue((KeywordType.STREET to "Gerit van Assendelftstraat") in normalized, "veld-trefwoord ontbreekt")
        assertTrue((KeywordType.YEAR to "1949") in normalized)
        assertTrue(card.keywords.none { it.normalized.isBlank() })
        assertEquals("Geen kaart in het modelresultaat", store.errors["11000"])
    }

    @Test
    fun `a failed job leaves the records pending and reports the failure`() {
        val store = InMemoryCards()
        val runner = StructuredJobRunner { throw StructuredJobFailedException("job-x", "De AI-dienst kon de opdracht niet afronden.") }
        val outcome = CardExtractionService(store, runner, mapper).extract(listOf(record("1"), record("2")), "test")
        assertEquals(0, outcome.cards)
        assertEquals(2, outcome.failed)
        assertEquals("job-x", outcome.jobId)
        assertTrue(outcome.jobFailed)
        assertEquals("De AI-dienst kon de opdracht niet afronden.", outcome.reason)
        // De records zelf zijn niet gemarkeerd: de dienst faalde, niet de invoer.
        assertTrue(store.errors.isEmpty())
    }

    @Test
    fun `a large batch sends the records as files and keeps the instruction short`() {
        val store = InMemoryCards()
        val requests = mutableListOf<StructuredJobRequest>()
        val runner = StructuredJobRunner { request ->
            requests += request
            StructuredJobOutcome("job-2", mapper.readTree("""{"cards":[]}"""), 1, 1, "anthropic/test")
        }
        val batch = (1..30).map { record("$it", (1..1_500).joinToString(" ") { w -> "woord$w" }) }
        CardExtractionService(store, runner, mapper).extract(batch, "big")
        val request = requests.single()
        assertTrue(request.instruction.length < JobPrompts.INLINE_LIMIT)
        assertTrue(request.attachments.isNotEmpty())
        assertTrue(request.instruction.contains("/job/input/objects/records-1/content"))
        assertTrue(request.instruction.contains("Het gaat om 30 records: 1, 2, 3"))
        assertTrue(request.attachments.joinToString { it.text }.contains("=== record ident=30 "))
    }

    @Test
    fun `batches stay within the character budget`() {
        val store = InMemoryCards()
        store.pendingRecords = (1..40).map { record("$it", "x".repeat(7_000)) }
        val batch = CardExtractionService(store, StructuredJobRunner { error("niet verwacht") }, mapper).nextBatch("archief", includeFailed = false)
        assertTrue(batch.size in 20..26, "batch ${batch.size}")
    }
}
