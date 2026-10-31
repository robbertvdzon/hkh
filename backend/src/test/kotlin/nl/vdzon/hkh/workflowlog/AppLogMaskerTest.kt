package nl.vdzon.hkh.workflowlog

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.Test

class AppLogMaskerTest {
    @Test
    fun `waarden van velden die op een geheim lijken worden vervangen`() {
        assertEquals("FTP password=***", AppLogMasker.mask("FTP password=hunter2"))
        assertEquals("""{"ftpPassword":"***","ftpHost":"ftp.example.org"}""", AppLogMasker.mask("""{"ftpPassword":"supergeheim","ftpHost":"ftp.example.org"}"""))
        assertEquals("wachtwoord: ***", AppLogMasker.mask("wachtwoord: abc123"))
        assertEquals("api-key=*** daarna", AppLogMasker.mask("api-key=XYZ-9 daarna"))
        assertEquals("secret = ***", AppLogMasker.mask("secret = 'tussen quotes'").replace("'***'", "***"))
        assertEquals("token=***&x=1", AppLogMasker.mask("token=abc&x=1"))
    }

    @Test
    fun `een authorization-kop en een bearer-token worden vervangen`() {
        val masked = AppLogMasker.mask("Authorization: Bearer abcdef0123456789 en Bearer 9876543210abcdef")
        assertFalse("abcdef0123456789" in masked || "9876543210abcdef" in masked, masked)
        assertTrue("Authorization: ***" in masked, masked)
    }

    @Test
    fun `gebruiker en wachtwoord in een adres worden vervangen`() {
        assertEquals("verbinden met ftp://ZCBS:***@host/pad", AppLogMasker.mask("verbinden met ftp://ZCBS:geheim123@host/pad"))
    }

    @Test
    fun `gewone tekst blijft ongemoeid`() {
        val text = "Wachtwoord klopt niet voor gebruiker carla; map K:\\scans ria niet gevonden\n\tat nl.vdzon.Foo.bar(Foo.kt:12)"
        assertEquals(text, AppLogMasker.mask(text))
    }
}
