package nl.vdzon.hkh.aisearch

/**
 * Hoeveel zoekrondes de digitale onderzoeker mag doen. Een ronde is: zoektermen bepalen, alle
 * resultaatpagina's ophalen, samenvattingen beoordelen en details van relevante treffers lezen.
 * Ronde 1 komt uit de vraag; elke volgende ronde uit aanknopingspunten van de vorige ronde.
 * De gebruiker kiest de diepte bij het stellen van de vraag; het maximum is een plafond, geen doel.
 */
enum class AiResearchDepth(
    val label: String,
    val maxRounds: Int,
    /** Harde bovengrens voor de runtime-job, ruim boven de verwachte duur zodat de agent zelf stopt. */
    val executionTimeoutSeconds: Int,
    /** Richtlengte van het antwoord in tekens, als tekst voor de prompt. */
    val answerLength: String,
    val guidance: String,
) {
    FAST(
        label = "Snel",
        maxRounds = 1,
        executionTimeoutSeconds = 600,
        answerLength = "3.000 tot 6.000 tekens",
        guidance = "Streef naar een antwoord binnen twee minuten. Volg alleen aanknopingspunten die nodig zijn om de vraag zelf te beantwoorden.",
    ),
    EXTENDED(
        label = "Doorzoeken",
        maxRounds = 5,
        executionTimeoutSeconds = 1200,
        answerLength = "8.000 tot 12.000 tekens",
        guidance = "Volg de belangrijkste aanknopingspunten één niveau diep en beschrijf de gevonden verbanden.",
    ),
    THOROUGH(
        label = "Uitgebreid",
        maxRounds = 15,
        executionTimeoutSeconds = 1800,
        answerLength = "15.000 tot 25.000 tekens",
        guidance = "Volg aanknopingspunten tot twee niveaus diep en werk sporen naar personen, gebouwen, bedrijven en gebeurtenissen uit tot een samenhangend verhaal met alles eromheen: tijdlijn, verbanden en onzekerheden. Als de vraag daarom vraagt, hoort ook de omgeving van de hoofdpersonen erbij: de straat en de buren (straatbeelden door de jaren heen), de gebouwen en instellingen waar zij werkten of kwamen, collega's en verenigingen.",
    );

    companion object {
        val DEFAULT = FAST

        /** Onbekende of ontbrekende waarden vallen terug op [DEFAULT]; een verkeerde keuze mag een vraag nooit blokkeren. */
        fun parse(value: String?): AiResearchDepth =
            entries.firstOrNull { it.name.equals(value?.trim(), ignoreCase = true) } ?: DEFAULT
    }
}
