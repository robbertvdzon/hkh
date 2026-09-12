package nl.vdzon.hkh.dossier

import kotlin.test.assertEquals
import org.junit.jupiter.api.Test

class ArticleDiffTest {
    @Test
    fun `marks inserted, deleted and unchanged lines in order`() {
        val lines = ArticleDiff.lines("a\nb\nc", "a\nx\nc\nd")

        assertEquals(
            listOf(
                DiffLine(DiffLineType.EQUAL, "a"),
                DiffLine(DiffLineType.DELETE, "b"),
                DiffLine(DiffLineType.INSERT, "x"),
                DiffLine(DiffLineType.EQUAL, "c"),
                DiffLine(DiffLineType.INSERT, "d"),
            ),
            lines,
        )
    }

    @Test
    fun `identical texts produce only equal lines`() {
        val lines = ArticleDiff.lines("een\ntwee", "een\ntwee")
        assertEquals(listOf(DiffLineType.EQUAL, DiffLineType.EQUAL), lines.map { it.type })
    }
}
