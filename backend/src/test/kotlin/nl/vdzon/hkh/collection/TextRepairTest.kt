package nl.vdzon.hkh.collection

import kotlin.test.assertEquals
import org.junit.jupiter.api.Test

class TextRepairTest {
    @Test
    fun `text that was UTF-8 read as ISO-8859-1 is restored`() {
        assertEquals("Notariële akte", TextRepair.fixMojibake("NotariÃ«le akte"))
        assertEquals("Officiële bekendmaking", TextRepair.fixMojibake("OfficiÃ«le bekendmaking"))
        assertEquals("Openbare leven (bioscoop, café, horeca)", TextRepair.fixMojibake("Openbare leven (bioscoop, cafÃ©, horeca)"))
        assertEquals("Ça ïë ü", TextRepair.fixMojibake("Ã\u0087a Ã¯Ã« Ã¼"))
        assertEquals("É", TextRepair.fixMojibake("Ã\u0089"))
    }

    @Test
    fun `correct text and text that cannot be restored stays untouched`() {
        assertEquals("Notariële akte", TextRepair.fixMojibake("Notariële akte"))
        assertEquals("gewone tekst", TextRepair.fixMojibake("gewone tekst"))
        assertEquals("", TextRepair.fixMojibake(""))
        // Een echte Ã die geen UTF-8-reeks vormt, en tekens buiten ISO-8859-1.
        assertEquals("Ãx", TextRepair.fixMojibake("Ãx"))
        assertEquals("NotariÃ«le € akte", TextRepair.fixMojibake("NotariÃ«le € akte"))
    }
}
