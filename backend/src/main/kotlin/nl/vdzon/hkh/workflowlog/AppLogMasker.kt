package nl.vdzon.hkh.workflowlog

/**
 * Het meldpunt is open en de logregels zijn ongecontroleerd tekst: wachtwoorden, sleutels en tokens die erin staan worden vervangen
 * voordat de regel wordt bewaard. De app maskeert zelf ook al; dit is de tweede controle.
 */
object AppLogMasker {
    const val MASK = "***"

    private val KEYS = "password|passwd|pwd|wachtwoord|secret|token|api[-_ ]?key|private[-_ ]?key|credential|sleutel"

    /** `naam=waarde`, `naam: waarde` en `"naam":"waarde"` waarbij de naam een geheim noemt (ook `ftpPassword`, `adminWachtwoord`). */
    private val KEY_VALUE = Regex("""(?i)(["']?\w*(?:$KEYS)\w*["']?\s*[:=]\s*)("[^"\r\n]*"|'[^'\r\n]*'|[^\s,;&}"']+)""")

    /** `Authorization: Bearer abc` en `Authorization: Basic abc`. */
    private val AUTHORIZATION = Regex("""(?i)(authorization["']?\s*[:=]\s*)(?:(?:bearer|basic)\s+)?[^\s,;"']+""")

    /** Een losse `Bearer abc`. */
    private val BEARER = Regex("""(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}""")

    /** Gebruiker en wachtwoord in een adres: `ftp://gebruiker:wachtwoord@host`. */
    private val URL_USER_INFO = Regex("""(://[^/\s:@]+:)[^@\s/]+@""")

    fun mask(text: String): String {
        var result = text
        result = AUTHORIZATION.replace(result) { "${it.groupValues[1]}$MASK" }
        result = BEARER.replace(result) { "${it.groupValues[1]} $MASK" }
        result = URL_USER_INFO.replace(result) { "${it.groupValues[1]}$MASK@" }
        result = KEY_VALUE.replace(result) { m ->
            val value = m.groupValues[2]
            val quote = value.firstOrNull()?.takeIf { it == '"' || it == '\'' }
            "${m.groupValues[1]}${if (quote != null) "$quote$MASK$quote" else MASK}"
        }
        return result
    }
}
