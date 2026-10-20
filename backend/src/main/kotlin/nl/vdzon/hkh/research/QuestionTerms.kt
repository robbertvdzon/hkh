package nl.vdzon.hkh.research

/**
 * Zoektermen uit de vraag, zonder model: aangehaalde tekst, namen en straten (hoofdletterreeksen
 * met tussenvoegsels), jaartallen en perioden, en de overige betekenisvolle woorden. Signaalwoorden
 * als "oudste" of "laatste" bepalen de sortering op jaar. Het resultaat is de eerste zoekopdracht;
 * het model stuurt daarna bij met de treffers in de hand.
 */
object QuestionTerms {
    const val MAX_TERMS = 8

    fun extract(question: String): ResearchQuery {
        val text = question.replace('\n', ' ').replace(Regex("\\s+"), " ").trim()
        val phrases = LinkedHashSet<String>()
        val words = LinkedHashSet<String>()

        QUOTED.findAll(text).forEach { match ->
            match.groupValues[1].trim().takeIf { it.length in 2..80 }?.let(phrases::add)
        }
        NAME.findAll(text).forEach { match ->
            val parts = match.value.trim().split(' ').toMutableList()
            // Een zin begint met een hoofdletter; losse stop- en werkwoorden vooraan tellen niet als naam.
            while (parts.isNotEmpty() && parts.first().lowercase() in STOPWORDS) parts.removeAt(0)
            while (parts.isNotEmpty() && parts.last().lowercase() in PARTICLES) parts.removeAt(parts.size - 1)
            if (parts.isEmpty()) return@forEach
            val phrase = parts.joinToString(" ")
            if (phrase.length >= 3 && phrase.lowercase() !in STOPWORDS) phrases += phrase
            val last = parts.last()
            if (parts.size > 1 && last.length >= 4 && last.lowercase() !in STOPWORDS) words += last
        }

        var yearFrom: Int? = null
        var yearTo: Int? = null
        RANGE.find(text)?.let { match ->
            yearFrom = match.groupValues[1].toInt()
            yearTo = match.groupValues[2].toInt()
        }
        DECADE.find(text)?.let { match ->
            val start = DECADES[match.groupValues[1].lowercase()] ?: return@let
            yearFrom = start
            yearTo = start + 9
        }
        val rangeText = RANGE.find(text)?.value.orEmpty()
        val years = YEAR.findAll(text).map { it.value }.filter { it !in rangeText }.distinct().toList()

        val covered = phrases.joinToString(" ").lowercase()
        WORD.findAll(text).forEach { match ->
            val word = match.value
            val lower = word.lowercase()
            if (lower.length < 4 || lower in STOPWORDS || lower in words.map { it.lowercase() }) return@forEach
            if (covered.contains(lower)) return@forEach
            words += lower
        }

        val sort = when {
            OLDEST.containsMatchIn(text) -> YearSort.ASC
            NEWEST.containsMatchIn(text) -> YearSort.DESC
            else -> null
        }
        val terms = (phrases.toList() + years + words.toList()).distinctBy { it.lowercase() }.take(MAX_TERMS)
        return ResearchQuery(terms = terms, yearFrom = yearFrom, yearTo = yearTo, sortByYear = sort, reason = "uit de vraag")
    }

    private val QUOTED = Regex("[\"“”„']([^\"“”„']{2,80})[\"“”„']")
    private val NAME = Regex("[A-ZÀ-Ý][\\wÀ-ÿ'-]+(?:\\s+(?:van|de|der|den|te|ten|het|op|in|'t|v\\.)?\\s*[A-ZÀ-Ý][\\wÀ-ÿ'-]+)*")
    private val RANGE = Regex("\\b(1[5-9]\\d\\d|20\\d\\d)\\s*(?:-|–|tot|t/m|en|tot en met)\\s*(1[5-9]\\d\\d|20\\d\\d)\\b")
    private val YEAR = Regex("\\b(?:1[5-9]\\d\\d|20\\d\\d)\\b")
    private val DECADE = Regex("jaren\\s+(twintig|dertig|veertig|vijftig|zestig|zeventig|tachtig|negentig|'?20|'?30|'?40|'?50|'?60|'?70|'?80|'?90)\\b", RegexOption.IGNORE_CASE)
    private val WORD = Regex("[\\p{L}][\\p{L}'-]+")
    private val OLDEST = Regex("\\b(oudste|oudst|eerste|vroegste|vroegst)\\b", RegexOption.IGNORE_CASE)
    private val NEWEST = Regex("\\b(nieuwste|laatste|recentste|jongste|meest recente)\\b", RegexOption.IGNORE_CASE)
    private val DECADES = mapOf(
        "twintig" to 1920, "dertig" to 1930, "veertig" to 1940, "vijftig" to 1950, "zestig" to 1960, "zeventig" to 1970, "tachtig" to 1980, "negentig" to 1990,
        "20" to 1920, "'20" to 1920, "30" to 1930, "'30" to 1930, "40" to 1940, "'40" to 1940, "50" to 1950, "'50" to 1950,
        "60" to 1960, "'60" to 1960, "70" to 1970, "'70" to 1970, "80" to 1980, "'80" to 1980, "90" to 1990, "'90" to 1990,
    )
    private val PARTICLES = setOf("van", "de", "der", "den", "te", "ten", "het", "op", "in", "'t")

    /** Lidwoorden, voornaamwoorden, hulpwerkwoorden, vraagwoorden en de gebruikelijke onderzoekswoorden. */
    private val STOPWORDS: Set<String> = setOf(
        "de", "het", "een", "en", "of", "maar", "want", "dus", "als", "dan", "dat", "die", "dit", "deze", "zo", "ook", "nog", "al", "wel",
        "niet", "geen", "er", "hier", "daar", "waar", "wat", "wie", "welke", "welk", "wanneer", "hoe", "waarom", "waarmee", "waarover",
        "ik", "je", "jij", "u", "hij", "zij", "ze", "we", "wij", "jullie", "me", "mij", "mijn", "jouw", "uw", "zijn", "haar", "hun", "ons", "onze",
        "ben", "bent", "is", "was", "waren", "wordt", "worden", "werd", "werden", "geweest", "heb", "hebt", "heeft", "hebben", "had", "hadden",
        "kan", "kun", "kunt", "kunnen", "kon", "konden", "wil", "wilt", "willen", "wilde", "zou", "zouden", "moet", "moeten", "mag", "mogen",
        "zal", "zullen", "laat", "laten", "doe", "doet", "doen", "deed", "gaat", "gaan", "ging", "komt", "komen", "kwam",
        "van", "voor", "naar", "met", "bij", "aan", "op", "in", "uit", "om", "te", "tot", "over", "onder", "door", "na", "sinds", "tussen",
        "tegen", "zonder", "binnen", "buiten", "rond", "rondom", "langs", "per", "volgens", "tijdens", "vanaf", "achter", "naast",
        "alle", "alles", "allemaal", "iets", "niets", "veel", "meer", "meest", "minder", "paar", "enkele", "sommige", "andere", "ander", "anders",
        "elk", "elke", "ieder", "iedere", "beide", "zelf", "zelfde", "eigen", "even", "eens", "toch", "heel", "erg", "zeer", "echt", "graag",
        "vertel", "vertellen", "verteld", "weet", "weten", "wist", "zoek", "zoeken", "zoekt", "gezocht", "opzoeken", "opzoekt", "opgezocht",
        "vind", "vinden", "vindt", "gevonden", "geef", "geven", "geeft", "toon", "tonen", "toont", "laat", "zien", "kijk", "kijken", "kijkt",
        "maak", "maken", "maakt", "gemaakt", "schrijf", "schrijven", "schrijft", "beschrijf", "beschrijven", "noem", "noemen", "noemt",
        "informatie", "info", "gegevens", "feiten", "feit", "verhaal", "verhalen", "geschiedenis", "historie", "historisch", "historische",
        "bron", "bronnen", "archief", "collectie", "kring", "heemskerk", "heemskerkse", "heemskerkers", "beeldbank", "foto", "fotos", "foto's",
        "afbeelding", "afbeeldingen", "plaatje", "plaatjes", "beeld", "beelden", "document", "documenten", "artikel", "artikelen",
        "mensen", "mens", "personen", "persoon", "bewoners", "bewoner", "woonde", "woonden", "wonen", "woont", "gewoond", "leefde", "leefden",
        "familie", "families", "relatie", "relaties", "verband", "verbanden", "gebouw", "gebouwen", "plaats", "plaatsen", "plek", "plekken",
        "tijd", "tijden", "jaar", "jaren", "periode", "eeuw", "vroeger", "later", "toen", "nu", "ooit", "altijd", "nooit", "vaak", "soms",
        "oudste", "oudst", "oude", "oud", "eerste", "vroegste", "vroegst", "nieuwste", "nieuwe", "nieuw", "laatste", "recentste", "recente", "jongste",
        "interessant", "interessante", "intressante", "mooi", "mooie", "leuk", "leuke", "bekend", "bekende", "belangrijk", "belangrijke",
        "verder", "daarna", "daarbij", "daarvan", "daarover", "hierover", "erover", "ervan", "waarvan", "hieruit", "daaruit",
        "zoals", "bijvoorbeeld", "bv", "evt", "eventueel", "liefst", "vooral", "alleen", "ongeveer", "diep", "dieper", "niveau",
        "voetnoot", "voetnoten", "footnoot", "footnoten", "onderin", "onderaan", "onderdeel", "onderdelen", "toepassing", "weergeven", "weergave",
        "kunt", "zodat", "omdat", "terwijl", "hoewel", "indien", "wel", "niet", "ja", "nee", "geldt", "geld", "gelden",
        "twintig", "dertig", "veertig", "vijftig", "zestig", "zeventig", "tachtig", "negentig", "honderd", "begin", "eind", "einde", "midden",
    )
}

/** Sortering op jaar voor vragen naar het oudste of nieuwste. */
enum class YearSort { ASC, DESC;
    companion object {
        fun parse(value: String?): YearSort? = when (value?.trim()?.lowercase()) {
            "asc", "oplopend", "oudste" -> ASC
            "desc", "aflopend", "nieuwste" -> DESC
            else -> null
        }
    }
}
