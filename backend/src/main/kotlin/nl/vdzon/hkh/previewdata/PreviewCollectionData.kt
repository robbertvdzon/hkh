package nl.vdzon.hkh.previewdata

import nl.vdzon.hkh.auth.PreviewRuntimeConfig
import nl.vdzon.hkh.collection.CollectionItemStore
import nl.vdzon.hkh.collection.ScrapedRecord
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(prefix = "hkh.ai-search", name = ["fixture-enabled"], havingValue = "true")
class PreviewCollectionData(private val preview: PreviewRuntimeConfig, private val store: CollectionItemStore) : ApplicationRunner {
    override fun run(args: ApplicationArguments) {
        preview.requireSeedingAllowed()
        if (store.find("beeldbank", "test-pdf-001") != null) return
        store.upsert(ScrapedRecord(
            collection = "beeldbank", ident = "test-pdf-001", title = "Synthetische bron voor PDF-export",
            description = "Alleen testgegevens: dit object beschrijft geen echt archiefstuk.",
            year = 1916, imageUrl = null, pdfUrl = null,
            detailUrl = "https://example.invalid/synthetic-test-pdf-001", fields = mapOf("Soort" to "Testgegevens"),
        ))
    }
}
