package nl.vdzon.hkh.research

/**
 * Trefwoorden die rechtstreeks uit de metadatavelden komen, zonder model: betrouwbaarder en
 * goedkoper dan ze door een model uit de tekst laten halen. Het model vult alleen de vrije tekst aan.
 */
object FieldKeywords {
    private val fieldTypes: List<Pair<Regex, KeywordType>> = listOf(
        Regex("^straatnaam\\??$", RegexOption.IGNORE_CASE) to KeywordType.STREET,
        Regex("^wijk in heemskerk$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^thema( object)?$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^rubriek$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^fotograaf$", RegexOption.IGNORE_CASE) to KeywordType.PERSON,
        Regex("^auteur\\(s\\)$", RegexOption.IGNORE_CASE) to KeywordType.PERSON,
        Regex("^uitgever$", RegexOption.IGNORE_CASE) to KeywordType.ORGANISATION,
        Regex("^medium$", RegexOption.IGNORE_CASE) to KeywordType.ORGANISATION,
        Regex("^plaats(/dorp)?$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^geboren te$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^overleden te$", RegexOption.IGNORE_CASE) to KeywordType.OTHER,
        Regex("^achternaam overledene$", RegexOption.IGNORE_CASE) to KeywordType.PERSON,
    )

    /** Velden met meerdere waarden, gescheiden door ; (een komma kan in een naam staan: "Duin, Piet"). */
    private val splitFields = setOf("thema", "thema object", "rubriek", "auteur(s)", "trefwoord", "wijk in heemskerk")

    fun fromRecord(record: PendingCardRecord): List<CardKeyword> {
        val result = mutableListOf<CardKeyword>()
        for ((name, rawValue) in record.fields) {
            val type = fieldTypes.firstOrNull { (pattern, _) -> pattern.matches(name.trim()) }?.second ?: continue
            val values = if (name.trim().lowercase() in splitFields) rawValue.split(';') else listOf(rawValue)
            for (value in values) {
                val cleaned = value.trim().trimEnd(';', ',', ' ')
                if (cleaned.length !in 2..120) continue
                result += CardKeyword(type, cleaned, normalize(type, cleaned), source = KeywordSource.FIELD)
            }
        }
        record.year?.takeIf { it in 1000..2100 }?.let { result += yearKeyword(it.toString(), it, it, KeywordSource.FIELD) }
        for (field in listOf("Datum", "Datum opname", "Datering", "Verschijningsjaar", "Geboren op", "Overleden op")) {
            record.fields[field]?.let { result += yearsFromText(it, KeywordSource.FIELD) }
        }
        return result.distinctBy { it.type to it.normalized }
    }

    /** Jaartallen en periodes in vrije tekst: "1949", "24-12-1949", "ca. 1930", "jaren vijftig", "jaren '50". */
    fun yearsFromText(text: String, source: KeywordSource): List<CardKeyword> {
        val found = mutableListOf<CardKeyword>()
        for (match in Regex("""(?<![0-9])(1[5-9][0-9]{2}|20[0-2][0-9])(?![0-9])""").findAll(text)) {
            val year = match.groupValues[1].toInt()
            val before = text.substring(maxOf(0, match.range.first - 12), match.range.first).lowercase()
            val approximate = before.contains("ca") || before.contains("circa") || before.contains("rond") || before.contains("omstreeks")
            found += if (approximate) yearKeyword("ca. $year", year - 5, year + 5, source) else yearKeyword(year.toString(), year, year, source)
        }
        val decades = mapOf("twintig" to 1920, "dertig" to 1930, "veertig" to 1940, "vijftig" to 1950, "zestig" to 1960, "zeventig" to 1970, "tachtig" to 1980, "negentig" to 1990)
        for (match in Regex("""jaren\s+'?(\d{2}|twintig|dertig|veertig|vijftig|zestig|zeventig|tachtig|negentig)""", RegexOption.IGNORE_CASE).findAll(text)) {
            val token = match.groupValues[1].lowercase()
            val start = decades[token] ?: token.toIntOrNull()?.let { if (it >= 20) 1900 + it else 2000 + it } ?: continue
            found += yearKeyword("jaren $token", start, start + 9, source)
        }
        return found
    }

    fun yearKeyword(literal: String, from: Int, to: Int, source: KeywordSource) =
        CardKeyword(KeywordType.YEAR, literal, if (from == to) from.toString() else "$from-$to", from, to, source)

    fun normalize(type: KeywordType, value: String): String {
        val collapsed = value.replace(Regex("\\s+"), " ").trim()
        return when (type) {
            KeywordType.PERSON -> {
                // "Duin, Piet" -> "Piet Duin"; "Diemeer Azn, Piet" -> "Piet Diemeer Azn"
                val parts = collapsed.split(",").map(String::trim).filter(String::isNotEmpty)
                if (parts.size == 2) "${parts[1]} ${parts[0]}" else collapsed
            }
            else -> collapsed
        }
    }
}
