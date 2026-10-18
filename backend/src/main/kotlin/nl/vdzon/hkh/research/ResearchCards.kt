package nl.vdzon.hkh.research

import java.time.Instant

/** Soort trefwoord op een kaart. */
enum class KeywordType { PERSON, ADDRESS, STREET, YEAR, ORGANISATION, EVENT, OTHER;
    companion object {
        fun parse(value: String?): KeywordType = entries.firstOrNull { it.name.equals(value?.trim(), ignoreCase = true) } ?: OTHER
    }
}

/** Waar een trefwoord vandaan komt: een metadataveld (zonder model) of de vrije tekst (model). */
enum class KeywordSource { FIELD, MODEL }

data class CardKeyword(
    val type: KeywordType,
    /** Vorm zoals in het document. */
    val literal: String,
    /** Standaardvorm waarop gezocht wordt, bijv. "Grada Oostrum" of "Kerklaan 13a". */
    val normalized: String,
    val yearFrom: Int? = null,
    val yearTo: Int? = null,
    val source: KeywordSource = KeywordSource.MODEL,
)

/** De kaart van één record: samenvatting plus trefwoorden. */
data class DocumentCard(
    val collection: String,
    val ident: String,
    val summary: String,
    val hasImage: Boolean,
    val keywords: List<CardKeyword>,
    val extractionVersion: String,
    val model: String?,
    val sourceHash: String,
    val error: String? = null,
    val createdAt: Instant? = null,
)

/** Record dat (opnieuw) een kaart nodig heeft, met de invoer voor de extractie. */
data class PendingCardRecord(
    val collection: String,
    val ident: String,
    val title: String,
    val description: String,
    val year: Int?,
    val fields: Map<String, String>,
    val documentText: String?,
    val hasImage: Boolean,
    val sourceHash: String,
)

data class CardStats(val cards: Long, val failed: Long, val pending: Long, val keywords: Long)

/** De huidige extractieversie: prompt en schema. Verhogen zet alle kaarten op "opnieuw maken". */
const val CARD_EXTRACTION_VERSION = "card-v1"
