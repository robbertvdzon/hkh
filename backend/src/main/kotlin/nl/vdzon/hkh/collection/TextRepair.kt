package nl.vdzon.hkh.collection

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * Herstelt tekst die als UTF-8 is verstuurd maar als ISO-8859-1 is gelezen ("NotariÃ«le akte"
 * in plaats van "Notariële akte"). De oude HKH-server levert pagina's met een mix van beide; de
 * client leest ze als ISO-8859-1, dus een UTF-8-waarde komt er als twee of drie losse tekens uit.
 * Elke kapotte reeks wordt afzonderlijk hersteld, zodat ook tekst met zowel kapotte als gewone
 * accenten goed komt. Reeksen die geen geldige UTF-8 vormen blijven ongewijzigd.
 */
object TextRepair {
    /** Een UTF-8-reeks van 2, 3 of 4 bytes zoals die er na lezen als ISO-8859-1 uitziet. */
    private val sequence = Regex("[\\u00C2-\\u00DF][\\u0080-\\u00BF]|[\\u00E0-\\u00EF][\\u0080-\\u00BF]{2}|[\\u00F0-\\u00F4][\\u0080-\\u00BF]{3}")

    fun fixMojibake(text: String): String {
        if (text.none { it.code in 0xC2..0xF4 }) return text
        return sequence.replace(text) { match -> decode(match.value) ?: match.value }
    }

    private fun decode(token: String): String? {
        val bytes = token.toByteArray(StandardCharsets.ISO_8859_1)
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        return runCatching { decoder.decode(ByteBuffer.wrap(bytes)).toString() }.getOrNull()
    }
}
