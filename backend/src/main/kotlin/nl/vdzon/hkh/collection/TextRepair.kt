package nl.vdzon.hkh.collection

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * Herstelt tekst die als UTF-8 is verstuurd maar als ISO-8859-1 is gelezen ("NotariÃ«le akte"
 * in plaats van "Notariële akte"). De oude HKH-server levert pagina's met een mix van beide; de
 * client leest ze als ISO-8859-1, dus een UTF-8-waarde komt er als twee of drie losse tekens uit.
 * Alleen waarden die op die manier kapot zijn en zich volledig laten terugzetten worden aangepast.
 */
object TextRepair {
    /** Het eerste byte van een UTF-8-reeks (Â, Ã, â) gevolgd door een vervolgbyte (0x80 tot 0xBF). */
    private val suspicious = Regex("[ÂÃâ][\\u0080-\\u00BF]")

    fun fixMojibake(text: String): String {
        if (!suspicious.containsMatchIn(text)) return text
        // Alleen echt ISO-8859-1-tekens kunnen uit bytes zijn voortgekomen.
        if (text.any { it.code > 0xFF }) return text
        val bytes = text.toByteArray(StandardCharsets.ISO_8859_1)
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        return runCatching { decoder.decode(ByteBuffer.wrap(bytes)).toString() }.getOrDefault(text)
    }
}
