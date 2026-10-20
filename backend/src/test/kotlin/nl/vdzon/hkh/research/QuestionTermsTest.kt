package nl.vdzon.hkh.research

import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.jupiter.api.Test

class QuestionTermsTest {
    @Test
    fun `names, streets and lower-case subject words become terms, question words do not`() {
        assertEquals(listOf("Kapper Bekker", "Bekker"), QuestionTerms.extract("Wat kun je vertellen over Kapper Bekker?").terms)
        assertEquals(listOf("burgemeester", "nielen"), QuestionTerms.extract("wie was burgemeester nielen?").terms)
        assertEquals(listOf("zeelaan"), QuestionTerms.extract("zeelaan").terms)
        assertEquals(listOf("touwslagerij", "oosten"), QuestionTerms.extract("wat kun je vertellen over touwslagerij van oosten.").terms)
        assertEquals(listOf("bachstraat"), QuestionTerms.extract("kun je wat vertellen over de bachstraat en de mensen die daar woonden").terms)
        assertEquals(listOf("Los Tamaros", "Tamaros"), QuestionTerms.extract("wat weet je van Los Tamaros").terms)
        assertEquals(listOf("Maerten van Heemskerckstraat", "Heemskerckstraat"), QuestionTerms.extract("Zoek foto's van de Maerten van Heemskerckstraat").terms)
    }

    @Test
    fun `a long question keeps the names first and at most eight terms`() {
        val query = QuestionTerms.extract(
            "Ik wil dat je alles opzoekt dat je kunt vinden over Toos Oostrum en Ciska Oostrum. Maar niet alleen van hun, ook van hun familie of andere relaties. " +
                "Dat geldt ook voor de gebouwen en plaatsen die van toepassing zijn. Maak er daarna een mooi verhaal van met plaatjes er tussen.",
        )
        assertEquals(listOf("Toos Oostrum", "Ciska Oostrum", "Oostrum"), query.terms.take(3))
        assert(query.terms.size <= QuestionTerms.MAX_TERMS)
        assertNull(query.sortByYear)
    }

    @Test
    fun `oldest and newest set the year sort, years and decades become terms or a period`() {
        val oldest = QuestionTerms.extract("Zoek de oudste luchtfoto van Heemskerk")
        assertEquals(listOf("luchtfoto"), oldest.terms)
        assertEquals(YearSort.ASC, oldest.sortByYear)
        assertEquals(YearSort.DESC, QuestionTerms.extract("wat is de nieuwste foto van de Kerklaan").sortByYear)

        val year = QuestionTerms.extract("de brand aan de Zeelaan in 1972")
        assertEquals(listOf("Zeelaan", "1972", "brand"), year.terms)
        assertNull(year.yearFrom)

        val range = QuestionTerms.extract("straatbeelden van de Kerkweg tussen 1950 en 1960")
        assertEquals(listOf("Kerkweg", "straatbeelden"), range.terms)
        val decade = QuestionTerms.extract("winkels in de jaren vijftig")
        assertEquals(1950, decade.yearFrom)
        assertEquals(1959, decade.yearTo)
        assertEquals(listOf("winkels"), decade.terms)
        val quoted = QuestionTerms.extract("wat weet je over \"het Hoge Werfje\"?")
        assertEquals("het Hoge Werfje", quoted.terms.first())
    }

    @Test
    fun `a question without usable words gives an empty query`() {
        assert(QuestionTerms.extract("en hij?").isEmpty)
        assert(QuestionTerms.extract("Kun je dat nog eens doen?").isEmpty)
    }
}
